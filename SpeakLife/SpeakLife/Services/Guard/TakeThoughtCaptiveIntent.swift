//
//  TakeThoughtCaptiveIntent.swift
//  SpeakLife
//
//  Siri / Shortcuts / lock-screen entry into the Guard drill.
//
//  Shipped in v1 even though the interrupt push is Phase 2, because the entire
//  value of interception is SPEED. The gap between a thought landing and the
//  declaration leaving someone's mouth is the feature; every second of "unlock,
//  find the app, find the tab" is value lost. A voice command from a locked
//  phone closes that gap now.
//
//  The intent deliberately opens the app rather than answering inline. A
//  snippet the user reads is the absorb loop; this feature only ever terminates
//  in speaking, and speaking needs the mic and the REPLACE screen.
//

import AppIntents
import Foundation

@available(iOS 16.0, *)
struct TakeThoughtCaptiveIntent: AppIntent {
    static var title: LocalizedStringResource = "Take a Thought Captive"
    static var description = IntentDescription(
        "Open SpeakLife and take the loudest thought captive — reject it and speak the truth out loud."
    )

    /// Must open the app: the drill ends in the user's own voice, which a
    /// snippet cannot do.
    static var openAppWhenRun: Bool = true

    static var parameterSummary: some ParameterSummary {
        Summary("Take a thought captive")
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        // Honour the kill switch here, not only where the request is consumed.
        //
        // The Today tab already refuses to present the drill when `guardEnabled`
        // is off, but this intent ran regardless: Siri would report success,
        // open the app, and land the user on a screen where nothing happened.
        // A dead end is a worse look than the feature simply being absent.
        //
        // It also stopped `guard_intent_invoked` from firing for a feature that
        // is dark, which would otherwise report usage of something nobody can
        // reach.
        //
        // The phrases stay registered with Siri either way — `appShortcuts` is
        // a static the system reads, and Remote Config cannot reach it. Failing
        // quietly here is the most the app can do.
        guard TakeItCaptiveService.shared.isEnabled else { return .result() }

        TakeItCaptiveService.requestPendingLaunch()
        // Also poke the live service, for the warm case — see `launchRequestedAt`.
        TakeItCaptiveService.shared.launchRequestedAt = Date()
        AnalyticsService.shared.track("guard_intent_invoked", parameters: ["surface": "app_intent"])
        return .result()
    }
}

// The `requestPendingLaunch` / `consumePendingLaunch` extension moved into
// SpeakLifeServices alongside `TakeItCaptiveService` itself, so the moved
// tests can call them without the app target being in the graph.
