//
//  FirstRunFocus.swift
//  SpeakLifeCore
//
//  Decides when a brand-new user sees the focused Today screen: one card,
//  "Speak today's 7 declarations", and nothing else to tap.
//
//  WHY
//
//  Over 30 days only about 1 in 5 new users ever spoke a declaration, played
//  audio, sent a chat message or finished a task. The Today tab handed them
//  around 21 things to tap on first landing, so the one thing the app is for
//  got lost. Until they finish a first Burst, the focused screen shows only it.
//
//  WHO GETS IT
//
//  Only installs that finished onboarding on a build with this switch on.
//  `startedAt` is stamped at that moment and never for anyone else, so every
//  existing user keeps the full Today screen. Focus ends at the first Burst or
//  after `maxDuration`, whichever comes first, so nobody is stuck in it.
//

import Foundation

public enum FirstRunFocusRule {

    /// Remote Config key. Turning it off restores the full Today screen at once.
    public static let flagKey = "focusedFirstRunEnabled"

    /// The longest focus can last even if the user never finishes a Burst.
    public static let maxDuration: TimeInterval = 3 * 24 * 60 * 60

    /// True while the focused Today screen should show.
    ///
    /// - Parameters:
    ///   - flagEnabled: the Remote Config switch.
    ///   - startedAt: when onboarding finished, or nil for an install that never
    ///     went through onboarding with the switch on.
    ///   - firstBurstDone: whether the user has finished a Burst since then.
    ///   - now: the current time.
    public static func isActive(
        flagEnabled: Bool,
        startedAt: Date?,
        firstBurstDone: Bool,
        now: Date
    ) -> Bool {
        guard flagEnabled, !firstBurstDone, let startedAt else { return false }
        let elapsed = now.timeIntervalSince(startedAt)
        // A clock set backwards reads as negative: still focus, it just started.
        return elapsed < maxDuration
    }
}
