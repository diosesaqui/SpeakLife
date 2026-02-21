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
        #if DEBUG
        print("📅 Scheduling daily declaration reminders...")
        #endif
        
        // Morning reminder - 8:00 AM
        scheduleMorningReminder()
        
        // Evening reminder - 8:00 PM (only if burst not completed)
        scheduleEveningReminder()
    }
    
    private func scheduleMorningReminder() {
        let content = UNMutableNotificationContent()
        content.title = "Your Daily Burst is ready! ⚡"
        content.body = "7 powerful declarations to ignite your morning. Tap to start your victory burst."
        content.sound = UNNotificationSound.default
        content.categoryIdentifier = "DAILY_DECLARATION"
        content.userInfo = ["action": "daily_declaration_burst"]
        
        // Schedule for 8:00 AM every day
        var dateComponents = DateComponents()
        dateComponents.hour = 8
        dateComponents.minute = 0
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(
            identifier: reminderIdentifier,
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Error scheduling morning reminder: \(error.localizedDescription)")
            } else {
                print("✅ Morning reminder scheduled for 8:00 AM")
            }
        }
    }
    
    private func scheduleEveningReminder() {
        // This will be a smart reminder that checks if burst was completed
        scheduleConditionalEveningReminder()
    }
    
    private func scheduleConditionalEveningReminder() {
        // Schedule for 8:00 PM every day
        var dateComponents = DateComponents()
        dateComponents.hour = 20  // 8:00 PM
        dateComponents.minute = 0
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        
        // We'll schedule this daily and check if burst was completed before showing
        let content = createEveningReminderContent()
        
        let request = UNNotificationRequest(
            identifier: eveningReminderIdentifier,
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Error scheduling evening reminder: \(error.localizedDescription)")
            } else {
                print("✅ Evening reminder scheduled for 8:00 PM")
            }
        }
    }
    
    private func createEveningReminderContent() -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        
        let messages = [
            ("Don't break your streak! 🔥", "Your daily burst is waiting. Takes just 2 minutes to declare victory."),
            ("End strong, warrior! 💪", "Complete your daily burst before bed and keep your streak alive."),
            ("Quick reminder ⚡", "You haven't completed today's burst. Don't let the day end without declaring truth!"),
            ("Keep the momentum! 🚀", "Your \(BurstCompletionTracker.shared.currentStreak + 1) day streak is calling. Complete your burst now."),
            ("Finish what you started! 🎯", "Just 7 declarations between you and today's victory.")
        ]
        
        let randomMessage = messages.randomElement() ?? messages[0]
        content.title = randomMessage.0
        content.body = randomMessage.1
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