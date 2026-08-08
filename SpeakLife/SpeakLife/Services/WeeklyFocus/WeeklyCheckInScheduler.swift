//
//  WeeklyCheckInScheduler.swift
//  SpeakLife
//
//  Sunday 7:00 PM local. Mirrors DeclarationNotificationService exactly — one
//  stable identifier, `UNCalendarNotificationTrigger`, `repeats: true`, and the
//  same `userInfo["deepLink"]` mechanism SpeakLifeApp already routes on.
//
//  Local, not remote, on purpose: a repeating calendar trigger fires in device
//  local time, so a Sunday-evening prompt needs no cron and no timezone
//  fan-out, and it keeps working for a user who flies across eight of them.
//
//  Push tap-through is low single digits. This is the invitation, not the
//  capture mechanism — WeeklyFocusCard is where most answers actually come
//  from. Which is exactly why the decay below matters: training users to
//  ignore a weekly notification costs more than the notification is worth.
//

import Foundation
import UserNotifications

final class WeeklyCheckInScheduler: WeeklyCheckInSchedulerProtocol {

    static let notificationId = "weekly_focus_checkin"

    /// Consecutive weeks that closed without an answer.
    private static let ignoredStreakKey = "weekly_focus_ignored_streak"
    /// `weekStart` of the last week counted as ignored, so a repeated call for
    /// the same week doesn't inflate the streak.
    private static let lastIgnoredWeekKey = "weekly_focus_last_ignored_week"

    /// Four ignored weeks in a row and the Sunday push drops to monthly. Weeks
    /// keep being built silently and the in-app card stays — only the
    /// notification backs off.
    private static let decayThreshold = 4

    private let center: UNUserNotificationCenter
    private let defaults: UserDefaults

    init(center: UNUserNotificationCenter = .current(),
         defaults: UserDefaults = .standard) {
        self.center = center
        self.defaults = defaults
    }

    // MARK: - WeeklyCheckInSchedulerProtocol

    func schedule() {
        let content = UNMutableNotificationContent()
        content.title = "One question before the week starts."
        content.body = "What do you need God's help with this week?"
        content.sound = .default
        content.userInfo = ["deepLink": "weeklyFocus"]

        let isDecayed = ignoredStreak >= Self.decayThreshold

        var components = DateComponents()
        components.weekday = 1     // Sunday
        components.hour = 19
        components.minute = 0
        if isDecayed {
            // First Sunday of the month. Still a Sunday evening — the ask is
            // about planning the week, so moving it off Sunday would break the
            // premise even at a monthly cadence.
            components.weekOfMonth = 1
        }

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(
            identifier: Self.notificationId,
            content: content,
            trigger: trigger
        )
        // Stable identifier — iOS replaces the pending request atomically on
        // add. Same reasoning as DeclarationNotificationService: remove+add
        // opens a window where the notification doesn't exist, which is a known
        // source of "I got it for a few weeks then it stopped".
        center.add(request) { error in
            if let error = error {
                print("❌ weekly_focus_checkin schedule failed: \(error.localizedDescription)")
            } else {
                print("✅ weekly_focus_checkin scheduled (\(isDecayed ? "monthly" : "weekly"), Sun 7:00 PM)")
                AnalyticsService.shared.track("weekly_checkin_push_sent", parameters: [
                    "cadence": isDecayed ? "monthly" : "weekly"
                ])
            }
        }
    }

    func cancel() {
        print("🚫 weekly_focus_checkin cancelled")
        center.removePendingNotificationRequests(withIdentifiers: [Self.notificationId])
    }

    func noteAnswered() {
        guard ignoredStreak != 0 else { return }
        defaults.set(0, forKey: Self.ignoredStreakKey)
        defaults.removeObject(forKey: Self.lastIgnoredWeekKey)
        // Restore the weekly cadence immediately rather than waiting for the
        // next launch to notice.
        schedule()
    }

    func noteIgnoredWeek(weekStart: Date) {
        let stamp = weekStart.timeIntervalSince1970
        // Idempotent per week: the build path runs on every launch and would
        // otherwise decay a user to monthly in a single afternoon.
        if let last = defaults.object(forKey: Self.lastIgnoredWeekKey) as? Double,
           last >= stamp {
            return
        }
        let previous = ignoredStreak
        defaults.set(stamp, forKey: Self.lastIgnoredWeekKey)
        defaults.set(previous + 1, forKey: Self.ignoredStreakKey)

        // Only re-schedule on the crossing, not on every increment past it.
        if previous + 1 == Self.decayThreshold {
            schedule()
        }
    }

    // MARK: - Private

    private var ignoredStreak: Int {
        defaults.integer(forKey: Self.ignoredStreakKey)
    }
}
