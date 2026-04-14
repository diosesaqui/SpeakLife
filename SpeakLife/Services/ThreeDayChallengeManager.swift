//
//  ThreeDayChallengeManager.swift
//  SpeakLife
//
//  Manages the 3-day onboarding challenge state.
//  Responsible for:
//    - Starting the challenge (sets start date, schedules push notifications)
//    - Tracking day completion
//    - Providing current day / progress state to the UI
//    - Scheduling personalized Day 2 and Day 3 push reminders
//

import Foundation
import UserNotifications

final class ThreeDayChallengeManager: ObservableObject {

    static let shared = ThreeDayChallengeManager()
    private init() {}

    // MARK: - Stored State (UserDefaults)

    @Published var day1Complete: Bool = UserDefaults.standard.bool(forKey: "challengeDay1Complete") {
        didSet { UserDefaults.standard.set(day1Complete, forKey: "challengeDay1Complete") }
    }
    @Published var day2Complete: Bool = UserDefaults.standard.bool(forKey: "challengeDay2Complete") {
        didSet { UserDefaults.standard.set(day2Complete, forKey: "challengeDay2Complete") }
    }
    @Published var day3Complete: Bool = UserDefaults.standard.bool(forKey: "challengeDay3Complete") {
        didSet { UserDefaults.standard.set(day3Complete, forKey: "challengeDay3Complete") }
    }
    @Published var challengeCompleted: Bool = UserDefaults.standard.bool(forKey: "challengeFullyCompleted") {
        didSet { UserDefaults.standard.set(challengeCompleted, forKey: "challengeFullyCompleted") }
    }

    private var startDateTimestamp: Double {
        get { UserDefaults.standard.double(forKey: "challengeStartDate") }
        set { UserDefaults.standard.set(newValue, forKey: "challengeStartDate") }
    }

    // MARK: - Computed State

    var hasStarted: Bool { startDateTimestamp > 0 }

    var startDate: Date? {
        guard startDateTimestamp > 0 else { return nil }
        return Date(timeIntervalSince1970: startDateTimestamp)
    }

    /// Current calendar day number (1, 2, 3). Returns nil if not started or past day 3.
    var currentDayNumber: Int? {
        guard let start = startDate else { return nil }
        let elapsed = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: start), to: Calendar.current.startOfDay(for: Date())).day ?? 0
        let day = elapsed + 1
        return day >= 1 && day <= 3 ? day : nil
    }

    /// True while the challenge is running (days 1–3, not yet completed)
    var isActive: Bool {
        guard !challengeCompleted else { return false }
        return currentDayNumber != nil
    }

    /// True if the current day is already marked complete
    func isDayComplete(_ day: Int) -> Bool {
        switch day {
        case 1: return day1Complete
        case 2: return day2Complete
        case 3: return day3Complete
        default: return false
        }
    }

    // MARK: - Actions

    /// Call once when onboarding finishes. Idempotent — safe to call multiple times.
    func startChallenge(goalWordRaw: String) {
        guard !hasStarted else { return }
        startDateTimestamp = Date().timeIntervalSince1970
        scheduleChallengePushNotifications(goalWordRaw: goalWordRaw)
    }

    /// Mark the given day (1, 2, or 3) as complete.
    func completeDay(_ day: Int) {
        switch day {
        case 1: day1Complete = true
        case 2: day2Complete = true
        case 3:
            day3Complete = true
            challengeCompleted = true
        default: break
        }
    }

    // MARK: - Push Notifications

    private func scheduleChallengePushNotifications(goalWordRaw: String) {
        let engine = SurveyPersonalizationEngine(goalWordRaw: goalWordRaw)
        let challengeName = engine.paywallCopy.challengeName

        guard let start = startDate else { return }
        let calendar = Calendar.current

        // Day 2 notification — fires 24h after challenge start, at 9am
        if let day2 = calendar.date(byAdding: .day, value: 1, to: start) {
            var components = calendar.dateComponents([.year, .month, .day], from: day2)
            components.hour = 9
            components.minute = 0
            if let fireDate = calendar.date(from: components) {
                scheduleNotification(
                    id: "challenge_day2",
                    title: "Day 2 of your \(challengeName) is ready",
                    body: "You showed up yesterday. Show up again today — this is how breakthroughs happen. 🙌",
                    date: fireDate
                )
            }
        }

        // Day 3 notification — fires 48h after start, at 9am
        if let day3 = calendar.date(byAdding: .day, value: 2, to: start) {
            var components = calendar.dateComponents([.year, .month, .day], from: day3)
            components.hour = 9
            components.minute = 0
            if let fireDate = calendar.date(from: components) {
                scheduleNotification(
                    id: "challenge_day3",
                    title: "Final day — complete your \(challengeName) today",
                    body: "Two days done. One left. Finish what you started. You won't regret it. 🔥",
                    date: fireDate
                )
            }
        }
    }

    private func scheduleNotification(id: String, title: String, body: String, date: Date) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    func cancelChallengeNotifications() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [
            "challenge_day2", "challenge_day3"
        ])
    }
}
