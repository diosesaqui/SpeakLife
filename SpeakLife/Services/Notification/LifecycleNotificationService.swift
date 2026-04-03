//
//  LifecycleNotificationService.swift
//  SpeakLife
//
//  Lifecycle push sequence — D1, D3, D7, D14, D30 + lapsed user re-engagement.
//  Call LifecycleNotificationService.shared.scheduleLifecycleNotifications() on first launch.
//  Call .onAppOpen() every session_start to reset lapsed timer.
//

import Foundation
import UserNotifications
import FirebaseAnalytics

final class LifecycleNotificationService {
    static let shared = LifecycleNotificationService()
    private init() {}

    private let center = UNUserNotificationCenter.current()

    // UserDefaults keys
    private let kInstallDate       = "lifecycle_install_date"
    private let kLastOpenDate      = "lifecycle_last_open_date"
    private let kLifecycleScheduled = "lifecycle_notifications_scheduled"
    private let kStreakKey         = "currentStreak"

    // MARK: - Entry Points

    /// Call once after onboarding completes
    func scheduleLifecycleNotifications() {
        guard !UserDefaults.standard.bool(forKey: kLifecycleScheduled) else { return }

        let installDate = Date()
        UserDefaults.standard.set(installDate, forKey: kInstallDate)
        UserDefaults.standard.set(true, forKey: kLifecycleScheduled)

        center.getNotificationSettings { [weak self] settings in
            guard settings.authorizationStatus == .authorized else { return }
            self?.scheduleAll(from: installDate)
        }

        Analytics.logEvent("lifecycle_notifications_scheduled", parameters: [:])
    }

    /// Call on every app open (session_start)
    func onAppOpen() {
        UserDefaults.standard.set(Date(), forKey: kLastOpenDate)
        // Cancel any pending lapsed re-engagement since user came back
        center.removePendingNotificationRequests(withIdentifiers: ["lapsed_d5", "lapsed_d10"])
        // Re-schedule lapsed detection
        scheduleLapsedDetection()
    }

    // MARK: - Schedule All Lifecycle Notifications

    private func scheduleAll(from installDate: Date) {
        let messages: [(id: String, days: Int, hour: Int, title: String, body: String)] = [
            (
                id: "lifecycle_d1",
                days: 1,
                hour: 8,
                title: "Your mind is being renewed ✨",
                body: "One day in. Keep declaring — repetition is how truth sticks. Open SpeakLife and speak 3 declarations right now."
            ),
            (
                id: "lifecycle_d3",
                days: 3,
                hour: 9,
                title: "3 days of speaking life 🔥",
                body: "Research says it takes 21 days to build a habit. You're 14% there. Don't stop now — your breakthrough is ahead."
            ),
            (
                id: "lifecycle_d7",
                days: 7,
                hour: 8,
                title: "One week strong 💪",
                body: "7 days of declaring God's Word. You're rewiring your mind. Open today's declarations and keep the momentum going."
            ),
            (
                id: "lifecycle_d14",
                days: 14,
                hour: 8,
                title: "Two weeks of transformation 👑",
                body: "Your mind thinks differently than it did 2 weeks ago — even if you can't see it yet. Trust the process. Declare today."
            ),
            (
                id: "lifecycle_d30",
                days: 30,
                hour: 9,
                title: "30 days. That's a new you. 🙌",
                body: "A month of speaking life. This is where real transformation lives. You've built something — don't walk away from it."
            ),
        ]

        for msg in messages {
            schedule(
                id: msg.id,
                title: msg.title,
                body: msg.body,
                daysFromNow: msg.days,
                hour: msg.hour,
                from: installDate
            )
        }
    }

    // MARK: - Streak At-Risk Notification (Fix 2)

    /// Schedule a daily 9pm notification that fires when tasks aren't done yet.
    func scheduleStreakAtRiskNotification(currentStreak: Int) {
        // Cancel first to avoid duplicates
        center.removePendingNotificationRequests(withIdentifiers: ["streak_at_risk"])

        guard currentStreak >= 1 else { return }

        center.getNotificationSettings { [weak self] settings in
            guard settings.authorizationStatus == .authorized else { return }

            let content = UNMutableNotificationContent()
            content.title = "Your \(currentStreak)-day streak ends tonight 🔥"
            content.body = "Don't let it slip. 60 seconds is all it takes — open SpeakLife before midnight."
            content.sound = .default
            content.userInfo = ["notificationType": "streakAtRisk"]

            var components = DateComponents()
            components.hour = 21  // 9pm
            components.minute = 0
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            let request = UNNotificationRequest(identifier: "streak_at_risk", content: content, trigger: trigger)
            self?.center.add(request, withCompletionHandler: nil)
        }
    }

    func cancelStreakAtRiskNotification() {
        center.removePendingNotificationRequests(withIdentifiers: ["streak_at_risk"])
    }

    // MARK: - Streak Break Notification

    /// Call when a streak is broken (streak resets to 0)
    func scheduleStreakBreakNotification(previousStreak: Int) {
        guard previousStreak >= 3 else { return } // Only notify if streak was meaningful
        center.getNotificationSettings { [weak self] settings in
            guard settings.authorizationStatus == .authorized else { return }
            self?.scheduleImmediate(
                id: "streak_break",
                title: "Your \(previousStreak)-day streak ended 😔",
                body: "You were on fire. Come back today and restart — every champion has a comeback story.",
                delayHours: 2
            )
        }
        Analytics.logEvent("streak_break_notification_scheduled", parameters: ["previous_streak": previousStreak])
    }

    // MARK: - Lapsed Re-engagement

    private func scheduleLapsedDetection() {
        center.getNotificationSettings { [weak self] settings in
            guard settings.authorizationStatus == .authorized else { return }
            self?.scheduleImmediate(
                id: "lapsed_d5",
                title: "Your mind is waiting for you 🙏",
                body: "You haven't declared in a few days. The enemy loves silence. Come back and speak life over yourself today.",
                delayHours: 5 * 24
            )
            self?.scheduleImmediate(
                id: "lapsed_d10",
                title: "Still thinking about you ❤️",
                body: "SpeakLife works when you show up. 60 seconds of declarations is all it takes. Your breakthrough is one open away.",
                delayHours: 10 * 24
            )
        }
    }

    // MARK: - Helpers

    private func schedule(id: String, title: String, body: String, daysFromNow: Int, hour: Int, from date: Date) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.userInfo = ["lifecycle_id": id, "deepLink": "declarations"]

        var triggerDate = Calendar.current.date(byAdding: .day, value: daysFromNow, to: date) ?? date
        triggerDate = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: triggerDate) ?? triggerDate
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        center.add(request) { error in
            if let error = error {
                Analytics.logEvent("lifecycle_notification_error", parameters: ["id": id, "error": error.localizedDescription])
            }
        }
    }

    private func scheduleImmediate(id: String, title: String, body: String, delayHours: Double) {
        center.removePendingNotificationRequests(withIdentifiers: [id])

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.userInfo = ["lifecycle_id": id, "deepLink": "declarations"]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delayHours * 3600, repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        center.add(request, withCompletionHandler: nil)
    }
}
