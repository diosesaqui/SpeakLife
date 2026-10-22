//
//  StreakNotifying.swift
//  SpeakLifeServices
//
//  The streak-related notification side effects, behind a seam.
//
//  Every method here ends in UNUserNotificationCenter (in the app's real
//  implementation), which a unit test can neither authorize nor inspect —
//  and the streak-break bug was never about a notification's contents, it
//  was about WHICH calls happen and in what order relative to the iCloud
//  heal. That is only assertable against a double.
//
//  Kept as a protocol so `EnhancedStreakViewModel` can build in the
//  Foundation-only Services target without importing UserNotifications.
//  The app installs `LifecycleNotificationService.shared` as the default
//  implementation via `EnhancedStreakViewModel.notifications` at startup.
//

import Foundation

public protocol StreakNotifying: AnyObject {
    /// One-off push at `fireDate` (today, at the user's evening check-in time).
    func scheduleStreakAtRiskNotification(currentStreak: Int, at fireDate: Date)
    func cancelStreakAtRiskNotification()
    /// One-off evening push naming the next unfinished task, once the burst is done.
    func scheduleEveningTaskNudge(_ nudge: EveningTaskNudge, at fireDate: Date)
    func cancelEveningTaskNudge()
    /// One-off comeback push at `fireDate`, three days after the last burst.
    func scheduleLapsedStreakNudge(at fireDate: Date)
    func cancelLapsedStreakNudge()
    func scheduleStreakBreakNotification(previousStreak: Int)
    func cancelStreakBreakNotification()
    @discardableResult
    func scheduleStreakMilestoneIfNeeded(currentStreak: Int, previousStreak: Int) -> Bool
}

/// A no-op default so the package builds and runs its tests without the
/// app's LifecycleNotificationService. The tests that care about ordering
/// swap in their own spy (see StreakBreakNotificationTests.StreakNotificationSpy).
public final class NoOpStreakNotifier: StreakNotifying {
    public static let shared = NoOpStreakNotifier()
    private init() {}
    public func scheduleStreakAtRiskNotification(currentStreak: Int, at fireDate: Date) {}
    public func cancelStreakAtRiskNotification() {}
    public func scheduleEveningTaskNudge(_ nudge: EveningTaskNudge, at fireDate: Date) {}
    public func cancelEveningTaskNudge() {}
    public func scheduleLapsedStreakNudge(at fireDate: Date) {}
    public func cancelLapsedStreakNudge() {}
    public func scheduleStreakBreakNotification(previousStreak: Int) {}
    public func cancelStreakBreakNotification() {}
    @discardableResult
    public func scheduleStreakMilestoneIfNeeded(currentStreak: Int, previousStreak: Int) -> Bool { false }
}
