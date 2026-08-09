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
        TakeItCaptiveService.requestPendingLaunch()
        // Also poke the live service, for the warm case — see `launchRequestedAt`.
        TakeItCaptiveService.shared.launchRequestedAt = Date()
        AnalyticsService.shared.track("guard_intent_invoked", parameters: ["surface": "app_intent"])
        return .result()
    }
}

// MARK: - Pending launch

extension TakeItCaptiveService {

    /// Set by the App Intent, read by the Today tab.
    ///
    /// TWO mechanisms, because the intent has two very different arrival cases
    /// and neither one covers the other:
    ///
    /// - **Cold launch.** `perform()` runs before any view exists, so an
    ///   in-memory flag would be set and never observed — the user would watch
    ///   the app open to the home screen having just asked Siri for the drill.
    ///   The persisted stamp survives that gap and is consumed on first appear.
    /// - **Warm app, wrong tab.** `onAppear` does not fire for a tab that is
    ///   already on screen or already built, so the persisted stamp alone left
    ///   the intent doing nothing at all. The published `launchRequestedAt`
    ///   drives a tab switch and the presentation.
    ///
    /// The persisted stamp is consumed exactly once, so the two cannot both fire
    /// and double-present.
    private static let pendingLaunchKey = "guardPendingIntentLaunch"

    static func requestPendingLaunch(defaults: UserDefaults = .standard) {
        defaults.set(Date().timeIntervalSince1970, forKey: pendingLaunchKey)
    }

    /// Returns true once per request, then clears it.
    ///
    /// Stale requests are dropped: a flag written more than a couple of minutes
    /// ago belongs to a launch that already happened (or one the user abandoned
    /// at the lock screen), and firing the drill off it would ambush someone who
    /// opened the app for something else entirely.
    static func consumePendingLaunch(defaults: UserDefaults = .standard,
                                     now: Date = Date()) -> Bool {
        let stamp = defaults.double(forKey: pendingLaunchKey)
        guard stamp > 0 else { return false }
        defaults.removeObject(forKey: pendingLaunchKey)
        return now.timeIntervalSince1970 - stamp < 120
    }
}
