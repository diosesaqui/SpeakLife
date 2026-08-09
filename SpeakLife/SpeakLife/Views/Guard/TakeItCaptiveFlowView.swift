//
//  TakeItCaptiveFlowView.swift
//  SpeakLife
//
//  Guarding — the fifth pillar. The container that runs the four screens.
//
//  INCOMING → JUDGE → REPLACE → GROUND TAKEN, target under 60 seconds.
//
//  The loop always terminates in speaking. Every branch in this file — the
//  escape hatch, the "I'm not sure" swipe, the no-mic fallback — converges on
//  the REPLACE screen. There is no path through this flow that ends at reading,
//  reflecting, or feeling calmer. If a future branch would let someone finish
//  without a declaration in their mouth, it is the wrong branch.
//
//  The one exception is `reachOut`, which does not continue at all. A drill is
//  not what that moment is.
//

import SwiftUI

struct TakeItCaptiveFlowView: View {

    @EnvironmentObject var subscriptionStore: SubscriptionStore
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var service: TakeItCaptiveService

    /// True when Siri / Shortcuts / the lock screen opened this.
    ///
    /// It does NOT hard-code the source to `.interrupt`. If the user hasn't done
    /// today's rep yet, a Siri launch IS today's rep and must tick the checklist
    /// row — anything else means asking them to do it twice. Only a second
    /// launch on a day already banked is a true interrupt. `begin()` resolves it.
    var launchedFromIntent: Bool = false

    /// Called when a rep is banked, so the checklist can tick its row.
    var onCompleted: (() -> Void)?
    /// The flow needs the paywall but does not own it — the host presents it.
    var onNeedsPremium: (() -> Void)?

    private enum Stage: Equatable {
        case incoming
        case answer          // right-swipe: here's what God says
        case replace
        case ground(Int)
        case escapeHatch
    }

    @State private var stage: Stage = .incoming
    @State private var thought: IncomingThought?
    /// Where the THOUGHT came from — the bank, the user's own words, or an
    /// interrupt. Recorded in the log. Distinct from `completesDailyRep`.
    @State private var activeSource: CapturedThought.Source = .daily
    /// Whether finishing this run banks the day's rep and ticks the checklist
    /// row. Fixed at `begin()` from the entry point, and NOT changed by the
    /// escape hatch: someone who opened the daily drill and typed their own
    /// thought has still done today's rep.
    @State private var completesDailyRep = true
    @State private var startedAt = Date()
    /// Set once `begin()` has run and come back empty.
    ///
    /// Separate from `thought == nil` on purpose: `onAppear` fires AFTER the
    /// first body evaluation, so keying the failure state off a nil thought
    /// would flash "Couldn't load today's drill" on every single open before
    /// the real thought arrived a frame later.
    @State private var loadFailed = false

    var body: some View {
        Group {
            if let thought {
                content(for: thought)
            } else if loadFailed {
                // The bank failed to load. Nothing to drill with, and a spinner
                // that never resolves is worse than an honest exit.
                emptyState
            } else {
                // One frame at most, before onAppear serves the thought.
                Color(hex: "#101216").ignoresSafeArea()
            }
        }
        .preferredColorScheme(.dark)
        .onAppear(perform: begin)
        .onDisappear {
            // Abandonment is measured by which screen they left on. It is a
            // product metric and nothing more — it is never surfaced back to
            // the user, and there is no "you didn't finish" anywhere in this
            // feature.
            if case .ground = stage { return }
            AnalyticsService.shared.track("guard_task_abandoned", parameters: [
                "screen_index": screenIndex
            ])
        }
    }

    // MARK: - Stages

    @ViewBuilder
    private func content(for thought: IncomingThought) -> some View {
        switch stage {
        case .incoming:
            IncomingThoughtView(
                thought: thought,
                onReject: { elapsed in
                    AnalyticsService.shared.track("guard_thought_rejected", parameters: [
                        "time_to_swipe_ms": Int(elapsed * 1000),
                        "category": thought.category.rawValue
                    ])
                    withAnimation(DS.Motion.smooth) { stage = .replace }
                },
                onUnsure: {
                    // Never an affirmation of the lie. It routes to what God
                    // says and then straight on to speaking it.
                    AnalyticsService.shared.track("guard_thought_unsure", parameters: [
                        "category": thought.category.rawValue
                    ])
                    withAnimation(DS.Motion.smooth) { stage = .answer }
                },
                onEscapeHatch: { withAnimation(DS.Motion.smooth) { stage = .escapeHatch } },
                onClose: { dismiss() }
            )
            .transition(.opacity)

        case .answer:
            ThoughtAnswerView(
                thought: thought,
                onContinue: { withAnimation(DS.Motion.smooth) { stage = .replace } },
                onClose: { dismiss() }
            )
            .transition(.opacity)

        case .replace:
            ReplaceDeclarationView(
                thought: thought,
                onSpoken: { spoken, method, duration in
                    AnalyticsService.shared.track("guard_declaration_spoken", parameters: [
                        "method": method,
                        "duration_ms": Int(duration * 1000),
                        "category": thought.category.rawValue
                    ])
                    // `method` is threaded through rather than stashed in @State
                    // first: a State write is not guaranteed to be readable back
                    // in the same pass, and this value has to reach the
                    // completion event intact.
                    complete(thought: thought, spoken: spoken, method: method)
                },
                onClose: { dismiss() }
            )
            .transition(.opacity)

        case .ground(let total):
            GroundTakenView(total: total) { dismiss() }
                .transition(.opacity)

        case .escapeHatch:
            EscapeHatchView(
                // The matched thought already carries the classified category,
                // so the flow reads it off `matched` rather than threading it
                // separately and risking the two disagreeing.
                onMatched: { _, matched, _ in
                    service.recordEscapeHatchUse(isPremium: subscriptionStore.isPremium)
                    // Only the THOUGHT's origin changes. `completesDailyRep`
                    // stays as `begin()` set it, so someone who opened the daily
                    // drill and typed their own thought still banks the day and
                    // still gets the checklist tick they came for.
                    activeSource = .escapeHatch
                    self.thought = matched
                    withAnimation(DS.Motion.smooth) { stage = .replace }
                },
                onBack: { withAnimation(DS.Motion.smooth) { stage = .incoming } },
                onNeedsPremium: {
                    AnalyticsService.shared.trackPaywallImpression(paywallId: "guard_escape_hatch")
                    onNeedsPremium?()
                    dismiss()
                },
                remaining: service.escapeHatchesRemaining(isPremium: subscriptionStore.isPremium),
                classifier: ThoughtClassifier(bank: service.bank)
            )
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    private var emptyState: some View {
        ZStack {
            Color(hex: "#101216").ignoresSafeArea()
            VStack(spacing: DS.Spacing.md) {
                Text("Couldn't load today's drill.")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                Button("Close") { dismiss() }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(DS.Palette.gold)
            }
        }
    }

    // MARK: - Lifecycle

    private func begin() {
        guard thought == nil else { return }
        // A Siri launch is today's rep unless today's rep is already banked;
        // only then is it a genuine interrupt. See `launchedFromIntent`.
        let dayAlreadyBanked = service.isCompletedToday
        completesDailyRep = !dayAlreadyBanked
        activeSource = (launchedFromIntent && dayAlreadyBanked) ? .interrupt : .daily
        startedAt = Date()
        let served = service.thought(isPremium: subscriptionStore.isPremium)
        thought = served
        guard let served else {
            loadFailed = true
            return
        }
        AnalyticsService.shared.track("guard_task_started", parameters: [
            "source": activeSource.rawValue,
            "entry": launchedFromIntent ? "app_intent" : "checklist",
            "category": served.category.rawValue,
            "intensity": served.intensity
        ])
    }

    private func complete(thought: IncomingThought, spoken: Bool, method: String) {
        let total = service.takeGround(
            category: thought.category,
            thoughtId: activeSource == .escapeHatch
                ? CapturedThought.escapeHatchDeclarationId
                : thought.id,
            source: activeSource,
            spoken: spoken,
            completesDailyRep: completesDailyRep
        )
        AnalyticsService.shared.track("guard_task_completed", parameters: [
            "total_duration_ms": Int(Date().timeIntervalSince(startedAt) * 1000),
            "ground_total": total,
            "source": activeSource.rawValue,
            "method": method
        ])
        onCompleted?()
        withAnimation(DS.Motion.smooth) { stage = .ground(total) }
    }

    private var screenIndex: Int {
        switch stage {
        case .incoming:     return 0
        case .answer:       return 1
        case .replace:      return 2
        case .ground:       return 3
        case .escapeHatch:  return 4
        }
    }
}
