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
        // IDs from before the weekday-rotated rewrite.
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [
            reminderIdentifier,
            eveningReminderIdentifier
        ])
        center.removePendingNotificationRequests(withIdentifiers: Self.allMorningReminderIDs)
        center.removePendingNotificationRequests(withIdentifiers: Self.allEveningReminderIDs)
        scheduleMorningReminders()
        scheduleEveningReminders()
    }

    /// Schedule one repeating weekly trigger per weekday so the morning copy rotates
    /// instead of every day reading "Your Daily Burst is ready!" until the user starts
    /// banner-blinding past it.
    private func scheduleMorningReminders() {
        for (weekday, copy) in Self.morningCopyByWeekday.enumerated() {
            let content = UNMutableNotificationContent()
            content.title = copy.title
            content.body = copy.body
            content.sound = UNNotificationSound.default
            content.categoryIdentifier = "DAILY_DECLARATION"
            content.userInfo = ["action": "daily_declaration_burst"]

            var dateComponents = DateComponents()
            dateComponents.hour = 7
            dateComponents.minute = 30
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

    private func scheduleEveningReminders() {
        for (weekday, copy) in Self.eveningCopyByWeekday.enumerated() {
            let content = UNMutableNotificationContent()
            content.title = copy.title
            content.body = copy.body
            content.sound = UNNotificationSound.default
            content.categoryIdentifier = "DAILY_DECLARATION"
            content.userInfo = ["action": "daily_declaration_burst", "type": "evening_reminder"]

            var dateComponents = DateComponents()
            dateComponents.hour = 20  // 8:00 PM
            dateComponents.minute = 0
            dateComponents.weekday = weekday + 1

            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
            let request = UNNotificationRequest(
                identifier: Self.eveningReminderID(weekday: weekday + 1),
                content: content,
                trigger: trigger
            )
            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("❌ Error scheduling evening burst (weekday \(weekday + 1)): \(error.localizedDescription)")
                }
            }
        }
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

    /// 7 evening variants — one per weekday. Tone: Sunday reflective, Monday "you
    /// did it", mid-week consistency, Friday week-cap, Saturday closing the loop.
    private static let eveningCopyByWeekday: [(title: String, body: String)] = [
        // Sunday
        (
            title: "Close the week declaring 🕊",
            body: "Don't end Sunday in noise. Take 2 minutes to speak truth and step into the new week clean."
        ),
        // Monday
        (
            title: "End Monday strong 💪",
            body: "You set the tone this morning — finish the way you started. Today's burst is still waiting."
        ),
        // Tuesday
        (
            title: "Don't break the chain 🔗",
            body: "You showed up yesterday. Show up tonight. Two minutes between you and a kept promise to yourself."
        ),
        // Wednesday
        (
            title: "Half the week down — finish today 🔥",
            body: "Mid-week win available. Open SpeakLife and speak before bed."
        ),
        // Thursday
        (
            title: "One more declaration before bed ✨",
            body: "Tomorrow's Friday — you already feel it. Anchor tonight in truth, not vibes."
        ),
        // Friday
        (
            title: "Don't drop the rope on Friday 🏁",
            body: "The streak isn't worth nothing — it's worth more than you think. Two minutes saves it."
        ),
        // Saturday
        (
            title: "Saturday isn't a day off ⚡",
            body: "Habits die on weekends because nobody says it out loud: you can rest and still show up. Open SpeakLife."
        )
    ]
    
    /// Call this when the user completes the daily burst so the evening reminder is cancelled.
    func cancelEveningReminderAfterBurstCompletion() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [eveningReminderIdentifier])
        #if DEBUG
        print("🔔 Evening burst reminder cancelled — burst already completed today")
        #endif
    }
    
    /// Used by the immediate-fire smart-evening-reminder path
    /// (`scheduleImmediateEveningReminder` -> when the app is foregrounded in the
    /// 7-8 PM window and the user hasn't completed today's burst). Pulls from the
    /// same weekday-rotated copy pool the scheduled evening triggers use, so we
    /// never drift back into a single hardcoded line.
    private func createEveningReminderContent() -> UNMutableNotificationContent {
        let rawWeekday = Calendar.current.component(.weekday, from: Date()) - 1
        let weekdayIndex = max(0, min(rawWeekday, Self.eveningCopyByWeekday.count - 1))
        let copy = Self.eveningCopyByWeekday[weekdayIndex]
        let content = UNMutableNotificationContent()
        content.title = copy.title
        content.body = copy.body
        content.sound = UNNotificationSound.default
        content.categoryIdentifier = "DAILY_DECLARATION"
        content.userInfo = ["action": "daily_declaration_burst", "type": "evening_reminder"]
        return content
    }
    
    private func cancelDailyDeclarationReminder() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [reminderIdentifier, eveningReminderIdentifier])
        print("Daily declaration reminders cancelled")
    }
    
    func handleNotificationTap() {
        // This will be called when user taps the daily declaration notification
        NotificationCenter.default.post(
            name: Notification.Name("ShowDailyDeclarationBurst"),
            object: nil
        )
    }
    
    // MARK: - Smart Evening Reminder
    
    func checkAndScheduleEveningReminder() {
        // This method should be called periodically to check if evening reminder should be sent
        let calendar = Calendar.current
        let now = Date()
        let hour = calendar.component(.hour, from: now)
        
        // Check if it's around 8 PM (between 7:45 PM and 8:15 PM for flexibility)
        if hour == 19 || hour == 20 {
            // Check if burst was completed today
            if !BurstCompletionTracker.shared.hasTodaysCompletion() {
                // Schedule immediate notification if not completed
                scheduleImmediateEveningReminder()
            } else {
                // Cancel any pending evening reminder if already completed
                UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [eveningReminderIdentifier])
            }
        }
    }
    
    private func scheduleImmediateEveningReminder() {
        // Check if we've already sent an evening reminder today
        let reminderKey = "lastEveningReminderDate"
        let lastReminderDate = UserDefaults.standard.object(forKey: reminderKey) as? Date
        let calendar = Calendar.current
        
        if let lastDate = lastReminderDate,
           calendar.isDateInToday(lastDate) {
            // Already sent today, don't spam
            return
        }
        
        let content = createEveningReminderContent()
        
        // Schedule for 5 seconds from now (gives time for app to background)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: eveningReminderIdentifier + "_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if error == nil {
                // Mark that we've sent the reminder today
                UserDefaults.standard.set(Date(), forKey: reminderKey)
                print("✅ Evening reminder scheduled for user who hasn't completed burst")
            }
        }
    }
    
    // This should be called when app becomes active
    func refreshEveningReminderIfNeeded() {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: Date())
        
        // If it's after 7 PM and before midnight
        if hour >= 19 && hour < 24 {
            checkAndScheduleEveningReminder()
        }
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