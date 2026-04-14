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
    @AppStorage("notificationCount") var notificationCount = 5
    @AppStorage("startTimeNotification") var startTimeNotification = ""
    @AppStorage("endTimeNotification") var endTimeNotification = ""
    @AppStorage("startTimeIndex") var startTimeIndex = 12
    @AppStorage("endTimeIndex") var endTimeIndex = 40
    @AppStorage("selectedNotificationCategories") var selectedNotificationCategories: String = ""
    @AppStorage("abbasLoveLetterIndex") var loveLetterIndex = 0
    @AppStorage("resetNotifications") var resetNotifications = true
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

    // Survey onboarding — goal word selected during survey ("PEACE", "IDENTITY", etc.)
    @AppStorage("surveyGoalWord") var surveyGoalWord = ""

    // 3-day challenge — show card on home screen
    var showChallengeCard: Bool {
        ThreeDayChallengeManager.shared.isActive
    }
    
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
        // Force initialization of @AppStorage properties with defaults
        if UserDefaults.standard.object(forKey: "notificationCount") == nil {
            UserDefaults.standard.set(5, forKey: "notificationCount")
        }
        if UserDefaults.standard.object(forKey: "startTimeIndex") == nil {
            UserDefaults.standard.set(12, forKey: "startTimeIndex")
        }
        if UserDefaults.standard.object(forKey: "endTimeIndex") == nil {
            UserDefaults.standard.set(40, forKey: "endTimeIndex")
        }
//        if UserDefaults.standard.object(forKey: "notificationEnabled") == nil {
//            UserDefaults.standard.set(false, forKey: "notificationEnabled")
//        }
        
        // Validate and fix any invalid existing values
        validateAndFixNotificationSettings()
    }
    
    private func validateAndFixNotificationSettings() {
        var fixed = false
        
        // Fix notification count
        if notificationCount <= 0 {
            // Fixed notification count to 5
            notificationCount = 5
            fixed = true
        }
        
        // Fix time indices
        if startTimeIndex < 0 || startTimeIndex >= 48 {
            // Fixed invalid start time index to 12
            startTimeIndex = 12 // 6 AM
            fixed = true
        }
        
        if endTimeIndex <= startTimeIndex || endTimeIndex >= 48 {
            let newEndIndex = min(startTimeIndex + 16, 47)
            // Fixed invalid end time index
            endTimeIndex = newEndIndex
            fixed = true
        }
        
        // Ensure minimum window of 2 hours
        if (endTimeIndex - startTimeIndex) < 4 { // 4 = 2 hours (30min intervals)
            let newEndIndex = min(startTimeIndex + 4, 47)
            // Fixed insufficient time window
            endTimeIndex = newEndIndex
            fixed = true
        }
        
        if !fixed {
            // Notification settings validated
        }
        
        // Final notification settings configured
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
            notificationCount = 5
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
