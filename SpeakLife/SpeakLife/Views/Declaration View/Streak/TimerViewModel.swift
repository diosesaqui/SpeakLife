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
        } else if let savedTimeRemaining = UserDefaults.standard.value(forKey: "timeRemaining") as? Int, savedTimeRemaining > 0 {
            // Restore the saved remaining time - don't require lastStartedStreak to be today
            timeRemaining = savedTimeRemaining
            isComplete = false
            hasLoadedInitialTime = true
            startTimer()
        } else {
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
        // Existing 16 from previous message...
        "What you speak today shapes your tomorrow. 🗣️💭 Speak life now.",
        "Seeds of life planted today become harvests of breakthrough. 🌱✨ Start now.",
        "Your words are weapons. The more you speak truth, the more you win. ⚔️🔥",
        "Every time you show up, heaven moves. 📖🕊️ Let’s go again.",
        "God’s promises work when you work them. 🔁📜 Speak life today.",
        "The more time in His Word, the more power in your life. 📖⚡ Speak life now.",
        "You grow when you speak. You win when you declare. 🔥🌿 Tap in.",
        "Don’t wait for change—declare it into existence. 🎯🗣️ Speak life.",
        "This is how mountains move. Start speaking. 🏔️🔊",
        "You’re one declaration away from a shift. 🔁 Speak life boldly.",
        "Every spoken promise waters your future. 💦🌻 Keep going.",
        "Heaven responds to your voice. 🎙️🕊️ Declare His Word today.",
        "Power, peace, and purpose await your voice. 🗣️☁️ Step in.",
        "Breakthrough belongs to the bold. 📣💥 Speak like it’s already done.",
        "Your future self will thank you for today’s declarations. 🧭🛡️",
        "If you want more out of life, put more Word into your day. 🔥📖 Start now.",
        
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
        content.title = "Keep your streak alive 🔥"
        content.body = speakLifeArray.shuffled().first ?? "It’s a new day to speak life. Let’s go!"
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


