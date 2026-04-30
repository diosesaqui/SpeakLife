//
//  AppState.swift
//  Dios Es Aqui
//
//  Created by Riccardo Washington on 1/25/22.
//

import SwiftUI

final class AppState: ObservableObject {
    @Published var rootViewId = UUID()
    @Published var showIntentBar = true
    @Published var onBoardingTest = true
    @Published var showScreenshotLabel = false {
        didSet {
            // Automatically reset after 5 seconds as a safety measure
            if showScreenshotLabel {
                DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
                    if self?.showScreenshotLabel == true {
                        // Auto-resetting stuck showScreenshotLabel
                        self?.showScreenshotLabel = false
                    }
                }
            }
        }
    }
    @AppStorage("onboarded") var isOnboarded = false
    @AppStorage("newPrayersAdded") var newPrayersAdded = true
    @AppStorage("newCategoriesAddedv4") var newCategoriesAddedv4 = true
    @AppStorage("newThemesAdded") var newThemesAdded = true
    @AppStorage("newSettingsAdded") var newSettingsAdded = true
    @AppStorage("abbasLoveAdded") var abbasLoveAdded = true
    @AppStorage("newTrackerAdded") var newTrackerAdded = true
    @AppStorage("lastNotificationSetDate") var lastNotificationSetDate = Date()
    @AppStorage("lastSharedAttemptDate") var lastSharedAttemptDate = Date()
    @AppStorage("notificationEnabled") var notificationEnabled = false
    @AppStorage("notificationCount") var notificationCount = 10
    @AppStorage("startTimeNotification") var startTimeNotification = ""
    @AppStorage("endTimeNotification") var endTimeNotification = ""
    @AppStorage("startTimeIndex") var startTimeIndex = 0
    @AppStorage("endTimeIndex") var endTimeIndex = 47
    @AppStorage("selectedNotificationCategories") var selectedNotificationCategories: String = ""
    @AppStorage("abbasLoveLetterIndex") var loveLetterIndex = 0
    @AppStorage("resetNotifications") var resetNotifications = true
    // Migration flag: set false in 4.10 so existing users get reset to all-day window + 10 reminders.
    // Default value here is "true" so brand-new installs (no key in defaults) skip the reset since
    // they already start with the new defaults above. The migration code below explicitly checks
    // for the key being absent vs. false to know whether this is a fresh install or a pre-4.10 user.
    @AppStorage("notificationDefaultsMigratedV2") var notificationDefaultsMigratedV2 = true
    @AppStorage("lastReviewRequestSetDatev1") var lastReviewRequestSetDate: Date?
    @AppStorage("offerDiscount") var offerDiscount = false
    @AppStorage("offerDiscountTry") var offerDiscountTry = 0
    @AppStorage("shareDiscountTry") var shareDiscountTry = 0
    @AppStorage("discountEndTime") var discountEndTime: Date?
    @AppStorage("lastRequestedRatingVersion") var lastRequestedRatingVersion: String?
    @AppStorage("helpUs") var helpUsGrowCount = 0
    @Published var timeRemainingForDiscount = 0
    @AppStorage("userName") var userName = ""
    @AppStorage("firstSelection") var firstSelection = ""
    @AppStorage("discountSelection") var discountSelection = ""
    @AppStorage("discountPercentage") var discountPercentage = ""
    @AppStorage("subscriptionTest") var subscriptionTestnineteen = false
    @AppStorage("firstOpen") var firstOpen = true
    @AppStorage("showGiftViewCount") var showGiftViewCount = 0
    @AppStorage("email") var email = ""
    @AppStorage("hasEmailv2") var needEmail = true
    @AppStorage("showQuizButton") var showQuizButton = true
    
    @AppStorage("hasCompletedDemo") var hasCompletedDemo = false
    @AppStorage("hasCompletedEnhancedOnboarding") var hasCompletedEnhancedOnboarding = false

    // Survey personalization — set by SurveyOnboardingView, read by NotificationScene, paywalls, ThreeDayChallengeView
    @AppStorage("surveyGoalWord") var surveyGoalWord: String = ""

    var selectedDeclarationStyles: [String] {
        get {
            let raw = UserDefaults.standard.string(forKey: "selectedDeclarationStyles") ?? ""
            return raw.isEmpty ? [] : raw.components(separatedBy: ",")
        }
        set {
            UserDefaults.standard.set(newValue.joined(separator: ","), forKey: "selectedDeclarationStyles")
        }
    }

    // Personal Declaration
    @AppStorage("hasPersonalDeclaration") var hasPersonalDeclaration = false
    @AppStorage("scrollToPersonalDeclaration") var scrollToPersonalDeclaration = false
    
    // Track when app was last backgrounded to prevent stale audio from restarting
    @AppStorage("lastBackgroundDate") var lastBackgroundDate: Date?
    @AppStorage("backgroundMusicWasPlaying") var backgroundMusicWasPlaying = false
    
    // Checklist notification settings
    @AppStorage("checklistNotificationsEnabled") var checklistNotificationsEnabled = true
    @AppStorage("morningReminderEnabled") var morningReminderEnabled = true
    @AppStorage("eveningCheckInEnabled") var eveningCheckInEnabled = true
    @AppStorage("morningReminderHour") var morningReminderHour = 8
    @AppStorage("morningReminderMinute") var morningReminderMinute = 0
    @AppStorage("eveningCheckInHour") var eveningCheckInHour = 19
    @AppStorage("eveningCheckInMinute") var eveningCheckInMinute = 0
    
    init() {
        let defaults = UserDefaults.standard

        // Detect a pre-4.10 user: they have notification keys saved from a prior version
        // but no migration flag yet. Brand-new installs have neither, so they skip the reset.
        let hasExistingNotificationPrefs = defaults.object(forKey: "notificationCount") != nil
            || defaults.object(forKey: "startTimeIndex") != nil
            || defaults.object(forKey: "endTimeIndex") != nil
        let migrationFlagPresent = defaults.object(forKey: "notificationDefaultsMigratedV2") != nil
        let needsV2Migration = hasExistingNotificationPrefs && !migrationFlagPresent

        // Force initialization of @AppStorage properties with defaults
        if defaults.object(forKey: "notificationCount") == nil {
            defaults.set(10, forKey: "notificationCount")
        }
        if defaults.object(forKey: "startTimeIndex") == nil {
            defaults.set(0, forKey: "startTimeIndex")
        }
        if defaults.object(forKey: "endTimeIndex") == nil {
            defaults.set(47, forKey: "endTimeIndex")
        }

        // 4.10 reset: existing users get the new all-day window with max 10 reminders.
        // Their preferences are overwritten once, then the flag is set so this never repeats.
        if needsV2Migration {
            defaults.set(10, forKey: "notificationCount")
            defaults.set(0, forKey: "startTimeIndex")
            defaults.set(47, forKey: "endTimeIndex")
            // Force the next foreground tick in SpeakLifeApp to reschedule notifications
            // with the new window instead of waiting for the existing batch to expire.
            defaults.removeObject(forKey: "lastScheduledNotificationDate")
            defaults.removeObject(forKey: "nextRescheduleDate")
        }
        defaults.set(true, forKey: "notificationDefaultsMigratedV2")

        // Validate and fix any invalid existing values
        validateAndFixNotificationSettings()
    }
    
    private func validateAndFixNotificationSettings() {
        // Fix notification count
        if notificationCount <= 0 {
            notificationCount = 10
        }

        // Fix time indices — default window is the full day (00:00 to 23:30).
        if startTimeIndex < 0 || startTimeIndex >= 48 {
            startTimeIndex = 0
        }

        if endTimeIndex <= startTimeIndex || endTimeIndex >= 48 {
            endTimeIndex = 47
        }

        // Ensure minimum window of 2 hours
        if (endTimeIndex - startTimeIndex) < 4 { // 4 = 2 hours (30min intervals)
            endTimeIndex = min(startTimeIndex + 4, 47)
        }
    }

    // Call this method when user changes start/end times to ensure validity
    func validateTimeRange() {
        if endTimeIndex <= startTimeIndex {
            endTimeIndex = min(startTimeIndex + 4, 47) // Minimum 2 hour window
        }
    }

    // Call this method to ensure notification count is valid
    func validateNotificationCount() {
        if notificationCount <= 0 {
            notificationCount = 10
        }
    }
    
}

@propertyWrapper
struct AppStorageCodable<T: Codable> {
    let key: String
    let defaultValue: T
    var container: UserDefaults = .standard

    var wrappedValue: T {
        get {
            guard let data = container.data(forKey: key) else {
                return defaultValue
            }
            let decodedValue = try? JSONDecoder().decode(T.self, from: data)
            return decodedValue ?? defaultValue
        }
        set {
            let encodedData = try? JSONEncoder().encode(newValue)
            container.set(encodedData, forKey: key)
        }
    }
}

extension Date: @retroactive RawRepresentable {
    private static let formatter = ISO8601DateFormatter()
    
    public var rawValue: String {
        Date.formatter.string(from: self)
    }
    
    public init?(rawValue: String) {
        self = Date.formatter.date(from: rawValue) ?? Date()
    }
    
    func toPrettyString() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale.current
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short
        return dateFormatter.string(from: self)
    }
    
    func toSimpleDate() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale.current
        dateFormatter.dateFormat = "MMMM d"
        return dateFormatter.string(from: self)
    }
    
    var isDateToday: Bool {
        let calendar = Calendar.current
        return calendar.isDateInToday(self)
    }
}
