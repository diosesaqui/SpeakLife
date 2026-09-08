//
//  MagnifyFlowView.swift
//  SpeakLife
//
//  Magnifying the Lord — the fifth pillar. The container that runs the rep.
//
//  LIFT → BEHOLD → SPEAK → HIGHER GROUND, target under 60 seconds.
//
//  This replaces `TakeItCaptiveFlowView`, and the shape is deliberately the same
//  four beats pointed the other way. That flow shrank a lie until it was gone;
//  this one enlarges God until the thing is in proportion. The beat count, the
//  time budget, the single-route discipline and the "always terminates in
//  speaking" rule all carry over unchanged, because all of them were right.
//
//  What changed is the front door, and it is the whole reason for the rewrite.
//  The old one asked "What are you up against right now?" and waited on a typed
//  sentence. That question had already been through one painful revision — it
//  replaced an INCOMING screen whose every control was a way of saying no, a
//  question with one permitted answer, which users hit and could not get past.
//  Asking for the sentence fixed that and introduced a subtler version of it: at
//  7am nothing is queued, and at 2am naming the worst thing in your head is the
//  hardest act there is, and either way a text field stood between someone and
//  the line they came to speak.
//
//  Magnifying needs no input at all. So:
//
//    · The default cost of entry is ONE TAP on a domain, and even that is
//      optional — "Surprise me" runs the rotation.
//    · Storm mode asks nothing whatsoever, is never metered, and never shows a
//      paywall. It is the answer to "even when life's storms are crazy", and it
//      is on the first screen rather than behind a menu.
//    · The written route survives as an OPTIONAL secondary door, because naming
//      a specific thing genuinely does produce a better-matched declaration for
//      it. It is now fully on device and instant — see `LiftView`.
//
//  Every branch converges on SPEAK. There is no path through this file that ends
//  at reading, reflecting, or feeling calmer. If a future branch would let
//  someone finish without a word in their mouth, it is the wrong branch.
//

import SwiftUI

struct MagnifyFlowView: View {

    @EnvironmentObject var subscriptionStore: SubscriptionStore
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var service: MagnifyService

    /// Every reviewed declaration the app has in memory, passed in from the
    /// checklist that presents this flow.
    ///
    /// This is what lets a written entry be answered out of the whole library
    /// rather than the bundled bank — twenty-five fertility lines, eighty-four
    /// rest lines, twenty-five debt lines, all reachable by someone who names
    /// what they are carrying. Empty is a supported state: the classifier falls
    /// back to the bank.
    var library: [Declaration] = []

    /// True when Siri / Shortcuts / the lock screen opened this.
    ///
    /// It does NOT hard-code the rep to an extra. If the user hasn't done today's
    /// yet, a Siri launch IS today's rep and must tick the checklist row —
    /// anything else means asking them to do it twice. Only a second launch on a
    /// day already banked is an extra. `begin()` resolves it.
    var launchedFromIntent: Bool = false

    /// Opened straight into storm mode, from the Siri phrase or the lock screen.
    /// Skips LIFT entirely — someone using that shortcut has already answered the
    /// only question LIFT asks.
    var launchedAsStorm: Bool = false

    /// Called when a rep is banked, so the checklist can tick its row.
    var onCompleted: (() -> Void)?
    /// The flow needs the paywall but does not own it — the host presents it.
    var onNeedsPremium: (() -> Void)?

    private enum Stage: Equatable {
        case why                 // first run only
        case lift                // where do you need Him lifted high?
        case behold
        case speak
        case done(Int)
    }

    @State private var stage: Stage = .lift
    @State private var entry: MagnifyEntry?
    /// Where this rep came from. Recorded in the log. Distinct from
    /// `completesDailyRep`.
    @State private var source: MagnifiedMoment.Source = .daily
    /// Whether finishing this run banks the day's rep and ticks the checklist
    /// row. Fixed at `begin()` from the entry point, and NOT changed by the
    /// written route or by storm mode: someone who opened the daily task and
    /// named something specific has still done today's rep, and so has someone
    /// who reached for storm mode before they got to the checklist.
    @State private var completesDailyRep = true
    @State private var isStorm = false
    @State private var startedAt = Date()
    /// Set once a serve has come back empty.
    ///
    /// Separate from `entry == nil` on purpose: `onAppear` fires AFTER the first
    /// body evaluation, so keying the failure state off a nil entry would flash
    /// "Couldn't load" on every open before the real entry arrived a frame later.
    @State private var loadFailed = false

    var body: some View {
        Group {
            switch stage {
            case .why:
                WhyMagnifyView(
                    onBegin: {
                        service.markWhySeen()
                        AnalyticsService.shared.track("magnify_why_completed")
                        withAnimation(DS.Motion.smooth) { stage = .lift }
                    },
                    onClose: {
                        // Skipping still marks it seen. Someone who declined the
                        // teaching once should not be shown it again tomorrow —
                        // that is a nag, and the rotating line on BEHOLD carries
                        // the same content anyway, a sentence at a time.
                        service.markWhySeen()
                        AnalyticsService.shared.track("magnify_why_skipped")
                        withAnimation(DS.Motion.smooth) { stage = .lift }
                    }
                )
            case .lift:
                liftScreen
            default:
                if let entry {
                    content(for: entry)
                } else if loadFailed {
                    // The bank failed to load. Nothing to serve, and a spinner
                    // that never resolves is worse than an honest exit.
                    emptyState
                } else {
                    // One frame at most, before the entry arrives.
                    Color(hex: "#0F1730").ignoresSafeArea()
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear(perform: begin)
        .onDisappear {
            // Abandonment is measured by which screen they left on. It is a
            // product metric and nothing more — it is never surfaced back to the
            // user, and there is no "you didn't finish" anywhere in this feature.
            if case .done = stage { return }
            AnalyticsService.shared.track("magnify_abandoned", parameters: [
                "screen_index": screenIndex,
                "storm": isStorm
            ])
        }
    }

    // MARK: - Stages

    @ViewBuilder
    private func content(for entry: MagnifyEntry) -> some View {
        switch stage {
        case .behold:
            BeholdView(
                entry: entry,
                whyLine: service.whyLine(),
                isStorm: isStorm,
                onFinished: {
                    AnalyticsService.shared.track("magnify_beheld", parameters: [
                        "domain": entry.domain.rawValue,
                        "intensity": entry.intensity,
                        "source": source.rawValue
                    ])
                    withAnimation(DS.Motion.smooth) { stage = .speak }
                },
                onClose: { dismiss() }
            )
            .transition(.opacity)

        case .speak:
            ExaltAndDeclareView(
                entry: entry,
                onSpoken: { spoken, method, duration in
                    AnalyticsService.shared.track("magnify_spoken", parameters: [
                        "method": method,
                        "duration_ms": Int(duration * 1000),
                        "domain": entry.domain.rawValue
                    ])
                    // `method` is threaded through rather than stashed in @State
                    // first: a State write is not guaranteed to be readable back
                    // in the same pass, and this value has to reach the
                    // completion event intact.
                    complete(entry: entry, spoken: spoken, method: method)
                },
                onClose: { dismiss() }
            )
            .transition(.opacity)

        case .done(let total):
            HigherGroundView(total: total, isStorm: isStorm) { dismiss() }
                .transition(.opacity)

        case .why, .lift:
            // Handled ahead of `content(for:)` — there is no entry yet.
            EmptyView()
        }
    }

    /// The front door.
    private var liftScreen: some View {
        LiftView(
            remaining: quotaRemaining,
            classifier: ThoughtClassifier(bank: [], library: library),
            onDomain: { domain in
                serve(domain: domain, source: .daily)
            },
            onNamed: { domain, matched in
                spendQuotaIfNeeded()
                // The bank still supplies the name of God, the exaltation and the
                // verse framing; only the DECLARATION comes from what they named.
                // The answer to "here is what I'm carrying" is not a rewritten
                // God — it is this God, over that thing.
                guard let base = service.entry(isPremium: subscriptionStore.isPremium,
                                               domain: domain) else {
                    loadFailed = true
                    return
                }
                source = .written
                entry = base.answering((declaration: matched.declaration,
                                        verseText: matched.verseText,
                                        book: matched.book,
                                        category: matched.category))
                withAnimation(DS.Motion.smooth) { stage = .behold }
            },
            onStorm: { enterStorm() },
            onNeedsPremium: {
                AnalyticsService.shared.trackPaywallImpression(paywallId: "magnify_extra_rep")
                onNeedsPremium?()
                dismiss()
            },
            onClose: { dismiss() }
        )
        .transition(.opacity)
    }

    /// Naming your own thing is free once a day — magnifying IS the daily task,
    /// so metering it would put the whole pillar behind the paywall for free
    /// users. The quota only bites on extra reps beyond the day's.
    private var quotaRemaining: Int? {
        guard !completesDailyRep else { return nil }
        return service.writtenEntriesRemaining(isPremium: subscriptionStore.isPremium)
    }

    private func spendQuotaIfNeeded() {
        guard !completesDailyRep else { return }
        service.recordWrittenEntryUse(isPremium: subscriptionStore.isPremium)
    }

    private var emptyState: some View {
        ZStack {
            Color(hex: "#0F1730").ignoresSafeArea()
            VStack(spacing: DS.Spacing.md) {
                Text("Couldn't load today's word.")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                Button("Close") { dismiss() }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(DS.Palette.gold)
            }
        }
    }

    // MARK: - Serving

    private func serve(domain: MagnifyDomain?, source newSource: MagnifiedMoment.Source) {
        guard let served = service.entry(isPremium: subscriptionStore.isPremium,
                                         domain: domain) else {
            loadFailed = true
            return
        }
        source = newSource
        entry = served
        withAnimation(DS.Motion.smooth) { stage = .behold }
    }

    /// Storm mode. Nothing is asked, nothing is metered, and the day's rotation
    /// is not spent — see `MagnifyService.stormEntry`.
    ///
    /// It still banks the day's rep when the day is open, because it genuinely is
    /// one: someone who magnified God at 2am should not be asked to do it again
    /// at 8am to tick a row.
    private func enterStorm() {
        guard let served = service.stormEntry() else {
            loadFailed = true
            return
        }
        isStorm = true
        source = .storm
        entry = served
        withAnimation(DS.Motion.smooth) { stage = .behold }
    }

    // MARK: - Lifecycle

    private func begin() {
        guard entry == nil, stage == .lift else { return }
        // A Siri launch is today's rep unless today's is already banked; only
        // then is it an extra. See `launchedFromIntent`.
        let dayAlreadyBanked = service.isCompletedToday
        completesDailyRep = !dayAlreadyBanked
        source = dayAlreadyBanked ? .extra : .daily
        startedAt = Date()

        AnalyticsService.shared.track("magnify_started", parameters: [
            "entry": launchedFromIntent ? "app_intent" : "checklist",
            "storm": launchedAsStorm,
            "first_run": !service.hasSeenWhy
        ])

        // Storm wins over everything, including the first-run teaching. Someone
        // who reached for that shortcut is not in a position to read three cards
        // about telescopes, and making them is the exact failure this feature was
        // built to remove.
        if launchedAsStorm {
            enterStorm()
            return
        }

        if !service.hasSeenWhy {
            stage = .why
        }
    }

    private func complete(entry: MagnifyEntry, spoken: Bool, method: String) {
        let total = service.magnify(
            domain: entry.domain,
            entryId: entry.id,
            source: source,
            spoken: spoken,
            completesDailyRep: completesDailyRep
        )
        AnalyticsService.shared.track("magnify_completed", parameters: [
            "total_duration_ms": Int(Date().timeIntervalSince(startedAt) * 1000),
            "times_magnified": total,
            "source": source.rawValue,
            "domain": entry.domain.rawValue,
            "method": method,
            "storm": isStorm
        ])
        onCompleted?()
        withAnimation(DS.Motion.smooth) { stage = .done(total) }
    }

    private var screenIndex: Int {
        switch stage {
        case .why:    return 0
        case .lift:   return 1
        case .behold: return 2
        case .speak:  return 3
        case .done:   return 4
        }
    }
}
