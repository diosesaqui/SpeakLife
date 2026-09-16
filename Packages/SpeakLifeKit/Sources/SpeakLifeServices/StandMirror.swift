//
//  StandMirror.swift
//  SpeakLifeServices
//
//  The seam between a completed day and the shared room.
//
//  `EnhancedStreakViewModel` already owns the moment a burst completes and an
//  Enforcement advances (`completeTask`). Mirroring that day into a Stand needs
//  Firestore, and this module has no Firebase dependency and must not gain one:
//  the package is being extracted precisely so the domain compiles without the
//  app's SDKs. So the same shape `shareImageRenderer` uses applies here — a
//  Foundation-typed hook the app installs at startup with the real
//  implementation (`StandService`), nil everywhere else.
//
//  THE CONTRACT, which is what makes this safe (spec §2):
//
//      The room is a MIRROR of local truth. It is never the source of it.
//
//  `recordDay` is therefore fire-and-forget and cannot throw. A failed mirror
//  write costs a dot on somebody else's week strip. It must never be able to
//  fail a burst, block the UI, or touch EnforcementProgress.
//

import Foundation

/// What the app's Firestore-aware `StandService` conforms to.
public protocol StandMirroring: AnyObject {

    /// Mirror a completed Enforcement day into every stand this user is in.
    ///
    /// Non-throwing and non-blocking by contract. Implementations return
    /// immediately and do their work on a background queue; failures are
    /// logged and dropped, never surfaced and never retried in a way that
    /// could block the caller.
    ///
    /// - Parameter dayNumber: the day just banked, 1...`Enforcement.length`.
    func recordDay(_ dayNumber: Int)
}

/// Late-bound holder, mirroring `DefaultFeatureFlags`.
///
/// The forwarding indirection matters for the same reason it does there:
/// `EnhancedStreakViewModel` is reached through singletons that may be built
/// before the app has wired up Firebase, so the app must be able to install the
/// real mirror at any point before the first burst completes.
public enum StandMirror {

    /// Installed at startup by the app target. Nil in tests and in the package,
    /// where a mirror write is simply not attempted.
    public static weak var shared: StandMirroring?

    /// Called from `EnhancedStreakViewModel.completeTask`. A no-op when no
    /// mirror is installed, which is the correct behavior for a user who is in
    /// no stands, a build with the feature flag off, and every unit test.
    public static func recordDay(_ dayNumber: Int) {
        shared?.recordDay(dayNumber)
    }
}
