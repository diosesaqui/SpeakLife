//
//  TimerViewModel.swift
//  SpeakLife
//
//  Created by Riccardo Washington on 3/17/24.
//

import SwiftUI
import UserNotifications
import Combine

final class TimerViewModel: ObservableObject {
    static let totalDuration = 10 * 60
    
    @AppStorage("currentStreak") var currentStreak = 0
    @AppStorage("longestStreak") var longestStreak = 0
    @AppStorage("totalDaysCompleted") var totalDaysCompleted = 0
    @AppStorage("lastCompletedStreak") var lastCompletedStreak: Date?
    @AppStorage("lastStartedStreak") var lastStartedStreak: Date?
    
    @AppStorage("newStreakNotification") var newStreakNotification = false
    
    @Published private(set) var isComplete = false
    @Published private(set) var timeRemaining: Int = 0
    @Published private(set) var isActive = false
    @Published var timer: Timer? = nil
    
    private var hasLoadedInitialTime = false
    private var cachedCompletionResult: Bool?
    private var cachedCompletionDate: Date?

    
    init() {
        // Only start timer if onboarding is completed
        if UserDefaults.standard.bool(forKey: "isOnboarded") {
            checkAndUpdateCompletionDate()
        }
//        if !newStreakNotification {
//            registerStreakNotification()
//            newStreakNotification = true
//        }
        
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
                let hasDailyReminder = requests.contains { $0.identifier == "daily_speak_life_reminder" }
                if !hasDailyReminder {
                    self.scheduleDailyStreakReminder()
                }
            }
        
        // Listen for midnight to reset timer
        setupMidnightObserver()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        timer?.invalidate()
    }
    
    func runCountdownTimer() {
        // Check completion status once when starting timer, not every second
        if checkIfCompletedToday() {
            isActive = false
            return
        }
        
        // Cancel any existing timer before creating a new one
        timer?.invalidate()
        timer = nil
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self = self else { return }
            if self.timeRemaining > 0 {
                self.timeRemaining -= 1
                if self.timeRemaining <= 10 {
                }
                // Save time periodically to prevent data loss
                if self.timeRemaining % 10 == 0 {
                    UserDefaults.standard.set(self.timeRemaining, forKey: "timeRemaining")
                }
            } else {
                timer.invalidate()
                self.timer = nil
                completeMeditation()
            }
        }
    }
    
    func completeMeditation() {
        UserDefaults.standard.removeObject(forKey: "timeRemaining")
        timeRemaining = 0
        isComplete = true
        hasLoadedInitialTime = false // Reset for next day
        
        
        saveCompletionDate()
        currentStreak += 1
        totalDaysCompleted += 1
        if currentStreak > longestStreak {
            longestStreak = currentStreak  // Set to current streak, not increment
        }
        
        
        // Post notification to trigger global celebration
        NotificationCenter.default.post(name: Notification.Name("StreakCompleted"), object: nil)
        self.isActive = false
    }
    
    // Debug method to manually fix streak if needed
    func debugFixStreak() {
        if checkIfCompletedToday() && currentStreak == 0 {
            currentStreak = 1
        }
    }
    
    func saveCompletionDate() {
        lastCompletedStreak = Date()
        // Invalidate cache since completion status changed
        cachedCompletionResult = nil
        cachedCompletionDate = nil
    }
    
    private func setupMidnightObserver() {
        // Listen for significant time changes (includes midnight)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(significantTimeChange),
            name: UIApplication.significantTimeChangeNotification,
            object: nil
        )
        
        // Also listen for app becoming active to check for day changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appBecameActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }
    
    @objc private func significantTimeChange() {
        // Check if we've crossed midnight
        handlePotentialDayChange()
    }
    
    @objc private func appBecameActive() {
        // Check if day changed while app was in background
        handlePotentialDayChange()
    }
    
    private func handlePotentialDayChange() {
        // Reset cached completion check
        cachedCompletionResult = nil
        cachedCompletionDate = nil
        
        // Check if we're on a new day and need to reset
        if let lastStarted = lastStartedStreak,
           !Calendar.current.isDateInToday(lastStarted),
           !checkIfCompletedToday() {
            // It's a new day and timer hasn't been completed - reset
            stopTimer()
            UserDefaults.standard.removeObject(forKey: "timeRemaining")
            timeRemaining = TimerViewModel.totalDuration
            lastStartedStreak = Date()
            isComplete = false
            hasLoadedInitialTime = false
            
            // Restart timer for new day
            loadRemainingTime()
        }
        
        // Update streak if needed
        checkAndUpdateCompletionDate()
    }
    
    lazy var calendar: Calendar = {
        var calendar = Calendar.current
        calendar.timeZone = .autoupdatingCurrent
        calendar.locale = .autoupdatingCurrent
        return calendar
    }()
    
    func checkIfCompletedToday() -> Bool {
        // Use cached result if we already calculated it today for the same completion date
        if let cached = cachedCompletionResult,
           let cachedDate = cachedCompletionDate,
           cachedDate == lastCompletedStreak {
            return cached
        }
        
        guard let completionDate = lastCompletedStreak else { 
            cachedCompletionResult = false
            cachedCompletionDate = nil
            return false 
        }
        
        let currentDate = Date()
        let calendar = Calendar.current

        // Start of the current day
        let startOfToday = calendar.startOfDay(for: currentDate)

        // Start of the next day
        guard let startOfTomorrow = calendar.date(byAdding: .day, value: 1, to: startOfToday) else { return false }

        // Check if the completion date is within today's range
        let completed = completionDate >= startOfToday && completionDate < startOfTomorrow
        
        // Cache the result
        cachedCompletionResult = completed
        cachedCompletionDate = completionDate
        
        return completed
    }
    
    func midnightOfTomorrow(after date: Date) -> Date? {
        if let nextDay = calendar.date(byAdding: .day, value: 2, to: date) {
            return calendar.startOfDay(for: nextDay)
        }
        return nil
    }
    
    func checkIfMidnightOfTomorrowHasPassedSinceLastCompletedStreak() -> Bool {
        guard let lastCompletionDate = lastCompletedStreak,
              let midnightAfterCompletion = midnightOfTomorrow(after: lastCompletionDate) else {
            return false
        }
        return Date() > midnightAfterCompletion
    }
    
    func checkAndUpdateCompletionDate() {
        // Invalidate cache at the start of a new day check
        if let cachedDate = cachedCompletionDate,
           !Calendar.current.isDateInToday(cachedDate) {
            cachedCompletionResult = nil
            cachedCompletionDate = nil
        }
        
        // Only reset streak if we missed a day AND haven't completed today
        if checkIfMidnightOfTomorrowHasPassedSinceLastCompletedStreak() && !checkIfCompletedToday() {
               // scheduleNotificationForMidnightTomorrow()
            currentStreak = 0
            hasLoadedInitialTime = false // Allow fresh timer load for new day
        } else if checkIfCompletedToday() {
        }
    }
    
    func saveRemainingTime() {
        UserDefaults.standard.set(timeRemaining, forKey: "timeRemaining")
        stopTimer()
       
    }
    
    func loadRemainingTime() {
        // Prevent multiple loads from resetting the timer
        if hasLoadedInitialTime && isActive && timeRemaining > 0 {
            return
        }
        
        checkAndUpdateCompletionDate()
        
        if checkIfCompletedToday() {
            hasLoadedInitialTime = true
            return
        } 
        
        // Check if we have a saved timer from today
        let isTimerFromToday: Bool
        if let lastStarted = lastStartedStreak {
            isTimerFromToday = Calendar.current.isDateInToday(lastStarted)
        } else {
            isTimerFromToday = false
        }
        
        if let savedTimeRemaining = UserDefaults.standard.value(forKey: "timeRemaining") as? Int, 
           savedTimeRemaining > 0,
           isTimerFromToday {
            // Restore the saved remaining time only if it's from today
            timeRemaining = savedTimeRemaining
            isComplete = false
            hasLoadedInitialTime = true
            startTimer()
        } else {
            // New day or no saved time - reset to full duration
            UserDefaults.standard.removeObject(forKey: "timeRemaining")
            timeRemaining = TimerViewModel.totalDuration
            lastStartedStreak = Date()
            isComplete = false
            hasLoadedInitialTime = true
            startTimer()
        }
    }
    
    private func startTimer() {
        if checkIfCompletedToday() {
            return
        }
        if !isActive {
            isActive = true
            runCountdownTimer()
        } else {
        }
    }
    
    func stopTimer() {
        isActive = false
        timer?.invalidate()
        timer = nil
    }
    
    func startTimerAfterOnboarding() {
        // Called when onboarding completes to start the daily timer
        checkAndUpdateCompletionDate()
    }
    
    
    func progress(for timeRemaining: Int) -> CGFloat {
        let totalTime = TimerViewModel.totalDuration
        let float = CGFloat(timeRemaining) / CGFloat(totalTime)
        return float
    }
    
    func timeString(time: Int) -> String {
        let minutes = time / 60
        let seconds = time % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    lazy var speakLifeArray: [String] = [
        // Daily Burst specific messages
        "⚡ Your Daily Burst is ready! 7 declarations to ignite your morning.",
        "🌅 Morning victory awaits! Your Daily Burst is prepared.",
        "🔥 Start strong! Your personalized Daily Burst is waiting.",
        "⚡ Power up your day! Tap for your 7-declaration burst.",
        "💪 Your spiritual armor is ready. Begin your Daily Burst now.",
        "🎯 Target victory! Your morning burst declarations are loaded.",
        "🌟 Rise and declare! Your Daily Burst will transform today.",
        "⚔️ Arm yourself! 7 powerful declarations ready to deploy.",
        "🚀 Launch your day right! Daily Burst ready for takeoff.",
        "🔥 Fuel your faith! Your burst of declarations awaits.",
        
        // Original messages
        "What you speak today shapes your tomorrow. 🗣️💭 Daily Burst ready!",
        "Seeds of life planted today become harvests. 🌱✨ Start your burst.",
        "Your words are weapons. Daily Burst loaded. ⚔️🔥",
        "Every time you show up, heaven moves. 📖🕊️ Burst ready.",
        "God's promises work when you work them. 🔁📜 Daily Burst awaits.",
        "More Word, more power. 📖⚡ Your Daily Burst is prepared.",
        
        // 🔥 10 NEW streak-based gamified nudges:
        "🔥 Day \(currentStreak + 1) is here. Let’s keep the fire going—don’t break the streak!",
        "🏆 Momentum is your superpower. Keep your streak strong—declare today.",
        "🎯 Consistency builds champions. One more day. One more victory. Speak life.",
        "📆 You've come too far to stop now. Day \(currentStreak + 1)—lock it in!",
        "🚀 Every day you speak, your spirit levels up. Keep the streak alive!",
        "🧠 Train your spirit daily. Your streak is your strength—stay sharp.",
        "📲 Heaven’s watching your streak. Let’s make today count!",
        "💡 Each declaration stacks eternal rewards. Keep it going!",
        "⏳ Don’t let today slip away. Your streak is your legacy—protect it.",
        "🌟 Greatness is built in small, daily declarations. Keep your streak glowing!"
    ]
    
//    func scheduleNotificationForMidnightTomorrow() {
//        let content = UNMutableNotificationContent()
//        content.title = "Speaking life is a weapon"
//        content.body = speakLifeArray.shuffled().first ??  "We missed you.🛡️⚒️ Gear up and Speak life."
//        content.sound = UNNotificationSound.default
//
//        var dateComponents = DateComponents()
//        dateComponents.hour = 7  
//        dateComponents.minute = 0
//
//        // Increment day by 1 to schedule for tomorrow
//        if let tomorrow = Calendar.current.date(byAdding: .hour, value: 7, to: Date()) {
//            dateComponents.day = Calendar.current.component(.day, from: tomorrow)
//            dateComponents.month = Calendar.current.component(.month, from: tomorrow)
//            dateComponents.year = Calendar.current.component(.year, from: tomorrow)
//        }
//
//        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
//
//        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
//
//        UNUserNotificationCenter.current().add(request) { error in
//            if let error = error {
//                print("Error scheduling notification: \(error.localizedDescription)")
//            }
//        }
//    }
//
    func scheduleDailyStreakReminder() {
        let content = UNMutableNotificationContent()
        content.title = "Daily Burst Ready! ⚡"
        content.body = speakLifeArray.shuffled().first ?? "Your 7 morning declarations are ready. Tap to start your Daily Burst!"
        content.sound = UNNotificationSound.default

        var dateComponents = DateComponents()
        dateComponents.hour = 8
        dateComponents.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)

        let request = UNNotificationRequest(identifier: "daily_speak_life_reminder", content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling daily streak reminder: \(error.localizedDescription)")
            } else {
                print("Daily streak reminder scheduled ✅")
            }
        }
    }
}


