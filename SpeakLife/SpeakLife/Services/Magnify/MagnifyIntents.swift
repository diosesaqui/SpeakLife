//
//  MagnifyIntents.swift
//  SpeakLife
//
//  Siri / Shortcuts / lock-screen entry into Magnifying the Lord.
//
//  Two intents, because there are two genuinely different moments:
//
//  - `MagnifyTheLordIntent` is the daily rep, reached by voice instead of by
//    tapping the checklist row.
//  - `MagnifyInAStormIntent` is the one that matters at 2am. It opens straight
//    into storm mode: no domain picker, no first-run teaching, no quota, no
//    paywall — a name of God and a line to say, in under thirty seconds. Someone
//    saying "everything is falling apart" to their phone has already answered
//    the only question the picker asks.
//
//  Both open the app rather than answering inline. A snippet the user reads is
//  the absorb loop; this pillar only ever terminates in SPEAKING, and speaking
//  needs the mic and the SPEAK screen.
//
//  **These replace `TakeThoughtCaptiveIntent`, and the rename is deliberate
//  despite its cost.** An App Intent's identity is its type name, so any custom
//  Shortcut a user built on the old one stops resolving and has to be re-added.
//  That is the lesser evil: leaving the old type in place would keep a shortcut
//  called "Take a Thought Captive" that now opens a worship flow, which is a
//  worse outcome than a shortcut that is honestly gone. The phrases registered
//  in `SiriIntents` cover the same moments and more.
//

import AppIntents
import Foundation

// MARK: - The daily rep

@available(iOS 16.0, *)
struct MagnifyTheLordIntent: AppIntent {
    static var title: LocalizedStringResource = "Magnify the Lord"
    static var description = IntentDescription(
        "Open SpeakLife, see who God is today, and say it out loud."
    )

    /// Must open the app: the rep ends in the user's own voice, which a snippet
    /// cannot do.
    static var openAppWhenRun: Bool = true

    static var parameterSummary: some ParameterSummary {
        Summary("Magnify the Lord")
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        MagnifyIntentRunner.stamp(storm: false)
        return .result()
    }
}

// MARK: - Storm mode

@available(iOS 16.0, *)
struct MagnifyInAStormIntent: AppIntent {
    static var title: LocalizedStringResource = "He's Bigger Than This"
    static var description = IntentDescription(
        "Open SpeakLife straight to a name of God and a word to speak. No questions asked."
    )

    static var openAppWhenRun: Bool = true

    static var parameterSummary: some ParameterSummary {
        Summary("Magnify the Lord in a storm")
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        MagnifyIntentRunner.stamp(storm: true)
        return .result()
    }
}

// MARK: - Shared body

/// The work both intents do. Deliberately returns `Void` rather than an
/// `IntentResult`: each `perform()` builds its own `.result()`, which is the
/// shape the AppIntents overloads are written for. Returning an opaque
/// `some IntentResult` out of a shared helper and through two different
/// `perform()` signatures is the kind of inference the framework does not
/// promise to resolve.
enum MagnifyIntentRunner {

    /// Honours the kill switch here, not only where the request is consumed.
    ///
    /// The Today tab already refuses to present the flow when `guardEnabled` is
    /// off, but the intent this replaced ran regardless: Siri would report
    /// success, open the app, and land the user on a screen where nothing
    /// happened. A dead end is a worse look than the feature simply being absent.
    ///
    /// It also stops `magnify_intent_invoked` from firing for a feature that is
    /// dark, which would otherwise report usage of something nobody can reach.
    ///
    /// The phrases stay registered with Siri either way — `appShortcuts` is a
    /// static the system reads, and Remote Config cannot reach it. Failing
    /// quietly here is the most the app can do, and a silent no-op is why
    /// `perform()` still returns a successful `.result()` above: Siri has no
    /// useful way to say "that feature is switched off right now".
    @MainActor
    static func stamp(storm: Bool) {
        guard MagnifyService.shared.isEnabled else { return }

        MagnifyService.requestPendingLaunch(storm: storm)
        // Also poke the live service, for the warm case — see `launchRequestedAt`.
        MagnifyService.shared.launchRequestedAt = Date()
        AnalyticsService.shared.track("magnify_intent_invoked", parameters: [
            "surface": "app_intent",
            "storm": storm
        ])
    }
}

// The `requestPendingLaunch` / `consumePendingLaunch` extension lives in
// SpeakLifeServices alongside `MagnifyService` itself, so the moved tests can
// call them without the app target being in the graph.
