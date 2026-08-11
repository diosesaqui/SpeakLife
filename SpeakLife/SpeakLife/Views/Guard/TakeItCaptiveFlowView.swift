//
//  TakeItCaptiveFlowView.swift
//  SpeakLife
//
//  Guarding — the fifth pillar. The container that runs the drill.
//
//  There are two routes through it, and which one runs depends on where the
//  thought came from. Both target under 60 seconds.
//
//    they typed it   ASK → TAKEN CAPTIVE → REPLACE → GROUND TAKEN
//    the bank served it   ASK → INCOMING/JUDGE → REPLACE → GROUND TAKEN
//
//  The difference is one screen and it is not cosmetic. INCOMING asks "does
//  this line up with who you are?" and makes the user throw the thought off the
//  display. That question earns its place against a thought the app supplied —
//  they are meeting it for the first time and rejecting it is the training.
//  Asked about a sentence they typed ten seconds ago in order to be rid of, it
//  is a gate: they already answered by writing it down, and the answer costs
//  them a swipe they have to discover before they can reach the word they came
//  for. So the typed route does not ask. It takes the thought, shows that
//  happening, and hands over the declaration.
//
//  It opens by ASKING what thought they have been carrying, rather than serving
//  one from the bank.
//
//  The original spec argued the opposite — that at 7am nobody has an intrusive
//  thought queued up, so "what are you thinking?" produces a blank field and a
//  bounce, and the app should supply the thought as reps at the range. That
//  reasoning was sound in the abstract and wrong in the hand: being handed
//  someone else's guess at your struggle is a weaker moment than naming your
//  own, and a thought you did not recognise is one you cannot reject with any
//  conviction.
//
//  The blank-field risk is real, so it is answered with a fallback rather than
//  by taking the question away: "Nothing specific right now" serves from the
//  bank and the drill runs exactly as it did. The ask leads; the bank catches.
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
        case ask             // what thought have you been carrying?
        case incoming        // served from the bank: judge it, then throw it
        case taken           // they typed it: the app takes it, no input asked
        case replace
        case ground(Int)
    }

    @State private var stage: Stage = .ask
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
            if case .ask = stage {
                askScreen
            } else if let thought {
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
                // The way back to the ask, for someone who took the bank's
                // thought and then realised a different one is the live one.
                onEscapeHatch: { withAnimation(DS.Motion.smooth) { stage = .ask } },
                onClose: { dismiss() }
            )
            .transition(.opacity)

        case .taken:
            // No question, no gesture. They named the thought on the screen
            // before; this one takes it and hands them the word.
            TakenCaptiveView(
                thought: thought,
                onFinished: {
                    AnalyticsService.shared.track("guard_thought_rejected", parameters: [
                        // Not a swipe, so there is no reaction time to record.
                        // The event still fires: it is what "a thought was taken"
                        // means downstream, and dropping it here would make every
                        // typed thought look abandoned in the funnel.
                        "method": "typed",
                        "category": thought.category.rawValue
                    ])
                    withAnimation(DS.Motion.smooth) { stage = .replace }
                },
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

        case .ask:
            // Handled ahead of `content(for:)` — there is no thought yet.
            EmptyView()
        }
    }

    /// The opening question, and the whole point of the change: they name the
    /// thought, the app doesn't guess it.
    private var askScreen: some View {
        AskForThoughtView(
            remaining: quotaRemaining,
            classifier: ThoughtClassifier(bank: service.bank),
            onNamed: { typed, matched in
                // Their words go on the card; the bank entry only supplies the
                // counter-declaration and the terrain.
                //
                // Straight to `.taken`, NOT to `.incoming`. The INCOMING screen
                // exists to ask "does this line up with who you are?" and have
                // them throw it off — which is the right question for a thought
                // the app served and they are meeting for the first time. Asked
                // about a sentence they typed ten seconds ago to be rid of, it
                // is a gate in front of the thing they came for: they already
                // answered it by writing it down.
                spendQuotaIfNeeded()
                activeSource = .escapeHatch
                thought = matched.wearing(typed)
                withAnimation(DS.Motion.smooth) { stage = .taken }
            },
            onNothingSpecific: {
                // The blank-field case the original spec was worried about.
                // Serve from the bank and run the drill exactly as before.
                activeSource = launchedFromIntent && !completesDailyRep ? .interrupt : .daily
                guard let served = service.thought(isPremium: subscriptionStore.isPremium) else {
                    loadFailed = true
                    return
                }
                thought = served
                AnalyticsService.shared.track("guard_bank_fallback_used", parameters: [
                    "category": served.category.rawValue,
                    "intensity": served.intensity
                ])
                withAnimation(DS.Motion.smooth) { stage = .incoming }
            },
            onNeedsPremium: {
                AnalyticsService.shared.trackPaywallImpression(paywallId: "guard_extra_rep")
                onNeedsPremium?()
                dismiss()
            },
            onClose: { dismiss() }
        )
        .transition(.opacity)
    }

    /// Naming your own thought is free once a day — it IS the daily task now, so
    /// metering it would put the whole feature behind the paywall for free
    /// users. The quota only bites on extra reps beyond the day's.
    private var quotaRemaining: Int? {
        guard !completesDailyRep else { return nil }
        return service.escapeHatchesRemaining(isPremium: subscriptionStore.isPremium)
    }

    private func spendQuotaIfNeeded() {
        guard !completesDailyRep else { return }
        service.recordEscapeHatchUse(isPremium: subscriptionStore.isPremium)
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
        guard stage == .ask, thought == nil else { return }
        // A Siri launch is today's rep unless today's rep is already banked;
        // only then is it a genuine interrupt. See `launchedFromIntent`.
        let dayAlreadyBanked = service.isCompletedToday
        completesDailyRep = !dayAlreadyBanked
        activeSource = (launchedFromIntent && dayAlreadyBanked) ? .interrupt : .daily
        startedAt = Date()
        AnalyticsService.shared.track("guard_task_started", parameters: [
            "source": activeSource.rawValue,
            "entry": launchedFromIntent ? "app_intent" : "checklist"
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
        case .ask:      return 0
        // `.taken` and `.incoming` are the same step of the drill by two routes,
        // so they share an index. Splitting them would put a step-2 abandon on
        // one route next to a step-3 abandon on the other for the same moment.
        case .incoming, .taken: return 1
        case .replace:  return 2
        case .ground:   return 3
        }
    }
}
