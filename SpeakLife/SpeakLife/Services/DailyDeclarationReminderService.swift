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
        print("📅 Scheduling daily declaration reminder...")
        #endif
        
        let content = UNMutableNotificationContent()
        content.title = "Start your day with victory 🌅"
        content.body = "Speak life over your morning with God's promises"
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
                print("❌ Error scheduling daily declaration reminder: \(error.localizedDescription)")
            } else {
                print("✅ Daily declaration reminder scheduled for 8:00 AM")
                #if DEBUG
                // Check what was actually scheduled
                UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
                    if requests.contains(where: { $0.identifier == self.reminderIdentifier }) {
                        print("✅ Verified: Daily reminder is in pending notifications")
                    }
                }
                #endif
            }
        }
    }
    
    private func cancelDailyDeclarationReminder() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [reminderIdentifier])
        print("Daily declaration reminder cancelled")
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