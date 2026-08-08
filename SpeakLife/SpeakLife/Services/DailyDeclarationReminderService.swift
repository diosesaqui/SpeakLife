//
//  DailyDeclarationReminderService.swift
//  SpeakLife
//
//  Daily morning reminder system for declaration practice
//

import Foundation
import UserNotifications
import UIKit

class DailyDeclarationReminderService: ObservableObject {
    static let shared = DailyDeclarationReminderService()
    
    @Published var isEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: "dailyDeclarationRemindersEnabled")
            if isEnabled {
                scheduleDailyDeclarationReminder()
            } else {
                cancelDailyDeclarationReminder()
            }
        }
    }
    
    private let reminderIdentifier = "daily_declaration_reminder"
    private let eveningReminderIdentifier = "daily_declaration_evening_reminder"

    /// One repeating trigger per weekday for both morning and evening so the copy
    /// rotates day-of-week instead of the user seeing the same line every morning.
    /// Sunday=1 ... Saturday=7 per UNCalendarNotificationTrigger's weekday convention.
    private static func morningReminderID(weekday: Int) -> String { "daily_burst_morning_w\(weekday)" }
    private static func eveningReminderID(weekday: Int) -> String { "daily_burst_evening_w\(weekday)" }
    private static var allMorningReminderIDs: [String] { (1...7).map { morningReminderID(weekday: $0) } }
    private static var allEveningReminderIDs: [String] { (1...7).map { eveningReminderID(weekday: $0) } }
    
    private init() {
        // Check if this is the first time - if key doesn't exist, default to true
        if UserDefaults.standard.object(forKey: "dailyDeclarationRemindersEnabled") == nil {
            // First time user - enable by default
            self.isEnabled = true
            UserDefaults.standard.set(true, forKey: "dailyDeclarationRemindersEnabled")
            #if DEBUG
            print("🔔 Daily reminders enabled by default for new user")
            #endif
        } else {
            self.isEnabled = UserDefaults.standard.bool(forKey: "dailyDeclarationRemindersEnabled")
            #if DEBUG
            print("🔔 Daily reminders loaded from settings: \(self.isEnabled)")
            #endif
        }
    }
    
    func setupDailyReminders() {
        // Check if user has enabled notifications and wants daily reminders
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                if settings.authorizationStatus == .authorized && self.isEnabled {
                    self.scheduleDailyDeclarationReminder()
                }
            }
        }
    }
    
    private func scheduleDailyDeclarationReminder() {
        // Cancel any stale instances first so we don't double-schedule when the
        // user toggles the reminder off and on. Includes the legacy single-trigger
        // IDs from before the weekday-rotated rewrite, and the retired evening
        // reminders (removed to cut daily notification volume — the streak
        // at-risk push already covers the evening nudge).
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [
            reminderIdentifier,
            eveningReminderIdentifier
        ])
        center.removePendingNotificationRequests(withIdentifiers: Self.allMorningReminderIDs)
        center.removePendingNotificationRequests(withIdentifiers: Self.allEveningReminderIDs)
        scheduleMorningReminders()
    }

    /// Schedule one repeating weekly trigger per weekday so the morning copy rotates
    /// instead of every day reading "Your Daily Burst is ready!" until the user starts
    /// banner-blinding past it.
    private func scheduleMorningReminders() {
        let burstTime = Self.burstTimeAvoidingUserReminders()

        for (weekday, copy) in Self.morningCopyByWeekday.enumerated() {
            let content = UNMutableNotificationContent()
            content.title = copy.title
            content.body = copy.body
            content.sound = UNNotificationSound.default
            content.categoryIdentifier = "DAILY_DECLARATION"
            content.userInfo = ["action": "daily_declaration_burst"]

            var dateComponents = DateComponents()
            dateComponents.hour = burstTime.hour
            dateComponents.minute = burstTime.minute
            dateComponents.weekday = weekday + 1 // Sunday=1 in DateComponents

            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
            let request = UNNotificationRequest(
                identifier: Self.morningReminderID(weekday: weekday + 1),
                content: content,
                trigger: trigger
            )
            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("❌ Error scheduling morning burst (weekday \(weekday + 1)): \(error.localizedDescription)")
                }
            }
        }
    }

    // MARK: - Burst Timing

    /// Minimum gap, in minutes, we allow between the Daily Burst and the
    /// nearest notification from the user's own reminder batch.
    private static let minGapMinutes = 60

    /// Candidate morning slots for the burst, in preference order. 7:30 is the
    /// long-standing default; the rest are fallbacks when the user's own
    /// reminders sit on top of it.
    private static let burstCandidates: [(hour: Int, minute: Int)] = [
        (7, 30), (8, 30), (9, 0), (9, 30), (10, 0), (6, 30)
    ]

    /// The Daily Burst used to be pinned to 7:30am while the default reminder
    /// window starts at 7:00am (`startTimeIndex` 14) — so out of the box, most
    /// users caught two SpeakLife pushes thirty minutes apart every morning,
    /// which is the fastest way to train someone to swipe us away.
    ///
    /// Pick the first candidate slot that sits at least `minGapMinutes` from
    /// every notification in the user's own batch. We shift the burst rather
    /// than drop it: the burst is the habit anchor, and skipping it whenever a
    /// content reminder happens to be nearby would silently delete it for
    /// anyone on the default settings. If every candidate collides (a very
    /// dense reminder schedule), fall back to 7:30 and accept the overlap.
    private static func burstTimeAvoidingUserReminders() -> (hour: Int, minute: Int) {
        let defaults = UserDefaults.standard
        let fallback = burstCandidates[0]

        // No reminder batch scheduled → nothing to collide with.
        guard defaults.bool(forKey: "notificationEnabled") else { return fallback }

        let count = defaults.integer(forKey: "notificationCount")
        let start = defaults.integer(forKey: "startTimeIndex")
        let end = defaults.integer(forKey: "endTimeIndex")
        guard count > 0, end > start else { return fallback }

        let userSlots = NotificationManager.shared.distributeTimes(
            startTime: start,
            endTime: end,
            count: count
        )
        guard !userSlots.isEmpty else { return fallback }

        let userMinutes = userSlots.map { $0.hour * 60 + $0.minute }

        for candidate in burstCandidates {
            let candidateMinutes = candidate.hour * 60 + candidate.minute
            let clearOfAll = userMinutes.allSatisfy {
                abs($0 - candidateMinutes) >= minGapMinutes
            }
            if clearOfAll { return candidate }
        }
        return fallback
    }

    // MARK: - Rotated Copy

    /// 7 morning variants — one per weekday (Sunday-indexed at 0 to match our
    /// `weekday + 1` math when scheduling). Designed to vary tone across the week:
    /// Sunday is reflective, Monday is reset, mid-week is momentum, Friday is
    /// finish-strong, Saturday is celebratory.
    private static let morningCopyByWeekday: [(title: String, body: String)] = [
        // Sunday
        (
            title: "Sunday reset 🕊",
            body: "Set the tone for your week. 60 seconds of declarations now shapes the next 7 days."
        ),
        // Monday
        (
            title: "Monday — set the tone ⚡",
            body: "How you start Monday is how the week goes. Speak life over yours before the noise arrives."
        ),
        // Tuesday
        (
            title: "Tuesday: small reps, big results 💪",
            body: "Day two of the week. Open SpeakLife and put the words in your mouth before the day owns you."
        ),
        // Wednesday
        (
            title: "Halfway there — keep declaring 🔥",
            body: "Mid-week is where most people coast. You don't coast. Speak life over today."
        ),
        // Thursday
        (
            title: "Thursday momentum 🚀",
            body: "Two days from the weekend. Two minutes from a decree. Open SpeakLife now."
        ),
        // Friday
        (
            title: "Finish strong, friend 🏁",
            body: "Don't let Friday slip into autopilot. Declare what you want before the day owns you."
        ),
        // Saturday
        (
            title: "Saturday — own it ✨",
            body: "Weekends are where habits die. Yours doesn't. 60 seconds of speaking life. Tap in."
        )
    ]

    private func cancelDailyDeclarationReminder() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [reminderIdentifier, eveningReminderIdentifier])
        center.removePendingNotificationRequests(withIdentifiers: Self.allMorningReminderIDs)
        center.removePendingNotificationRequests(withIdentifiers: Self.allEveningReminderIDs)
        print("Daily declaration reminders cancelled")
    }

    func handleNotificationTap() {
        // This will be called when user taps the daily declaration notification
        NotificationCenter.default.post(
            name: Notification.Name("ShowDailyDeclarationBurst"),
            object: nil
        )
    }
}

// Notification action setup
extension DailyDeclarationReminderService {
    static func setupNotificationActions() {
        let declareAction = UNNotificationAction(
            identifier: "DECLARE_NOW",
            title: "Speak Life Now",
            options: [.foreground]
        )
        
        let laterAction = UNNotificationAction(
            identifier: "REMIND_LATER",
            title: "Remind Me Later",
            options: []
        )
        
        let category = UNNotificationCategory(
            identifier: "DAILY_DECLARATION",
            actions: [declareAction, laterAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }
}