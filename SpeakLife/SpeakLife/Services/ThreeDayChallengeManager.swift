//
//  ThreeDayChallengeManager.swift
//  SpeakLife
//

import Foundation
import UserNotifications

final class ThreeDayChallengeManager: ObservableObject {
    static let shared = ThreeDayChallengeManager()
    private init() {}

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

    var hasStarted: Bool { startDateTimestamp > 0 }

    var startDate: Date? {
        guard startDateTimestamp > 0 else { return nil }
        return Date(timeIntervalSince1970: startDateTimestamp)
    }

    var currentDayNumber: Int? {
        guard let start = startDate else { return nil }
        let elapsed = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: start), to: Calendar.current.startOfDay(for: Date())).day ?? 0
        let day = elapsed + 1
        return day >= 1 && day <= 3 ? day : nil
    }

    var isActive: Bool {
        guard !challengeCompleted else { return false }
        return currentDayNumber != nil
    }

    func isDayComplete(_ day: Int) -> Bool {
        switch day {
        case 1: return day1Complete
        case 2: return day2Complete
        case 3: return day3Complete
        default: return false
        }
    }

    func startChallenge(goalWordRaw: String) {
        guard !hasStarted else { return }
        startDateTimestamp = Date().timeIntervalSince1970
        scheduleChallengePushNotifications(goalWordRaw: goalWordRaw)
    }

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

    private func scheduleChallengePushNotifications(goalWordRaw: String) {
        let engine = SurveyPersonalizationEngine(goalWordRaw: goalWordRaw)
        let challengeName = engine.paywallCopy.challengeName
        guard let start = startDate else { return }
        let calendar = Calendar.current

        if let day2 = calendar.date(byAdding: .day, value: 1, to: start) {
            var components = calendar.dateComponents([.year, .month, .day], from: day2)
            components.hour = 9; components.minute = 0
            if let fireDate = calendar.date(from: components) {
                scheduleNotification(id: "challenge_day2",
                    title: "Day 2 of your \(challengeName) is ready",
                    body: "You showed up yesterday. Show up again today. This is how breakthroughs happen.",
                    date: fireDate)
            }
        }

        if let day3 = calendar.date(byAdding: .day, value: 2, to: start) {
            var components = calendar.dateComponents([.year, .month, .day], from: day3)
            components.hour = 9; components.minute = 0
            if let fireDate = calendar.date(from: components) {
                scheduleNotification(id: "challenge_day3",
                    title: "Final day — complete your \(challengeName) today",
                    body: "Two days done. One left. Finish what you started.",
                    date: fireDate)
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
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }
}
