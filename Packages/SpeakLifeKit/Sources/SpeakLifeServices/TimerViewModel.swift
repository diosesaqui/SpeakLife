//
//  TimerViewModel.swift
//  SpeakLifeServices
//
//  Created by Riccardo Washington on 3/17/24.
//
//  Moved to Foundation + Combine. `@AppStorage` (SwiftUI) was replaced
//  with plain `UserDefaults` reads/writes to keep the file out of SwiftUI's
//  graph — the properties are still `@Published` so views observe them.
//  The dead `setupMidnightObserver()` code that referenced
//  `UIApplication.didBecomeActiveNotification` was removed; it was only
//  called from a commented-out line and its two `@objc` observer methods
//  have no other callers.
//

import Foundation
import Combine

public final class TimerViewModel: ObservableObject {
    public static let totalDuration = 10 * 60

    @Published public var currentStreak: Int {
        didSet { UserDefaults.standard.set(currentStreak, forKey: "currentStreak") }
    }
    @Published public var longestStreak: Int {
        didSet { UserDefaults.standard.set(longestStreak, forKey: "longestStreak") }
    }
    @Published public var totalDaysCompleted: Int {
        didSet { UserDefaults.standard.set(totalDaysCompleted, forKey: "totalDaysCompleted") }
    }
    @Published public var lastCompletedStreak: Date? {
        didSet {
            if let value = lastCompletedStreak {
                UserDefaults.standard.set(value, forKey: "lastCompletedStreak")
            } else {
                UserDefaults.standard.removeObject(forKey: "lastCompletedStreak")
            }
        }
    }
    @Published public var lastStartedStreak: Date? {
        didSet {
            if let value = lastStartedStreak {
                UserDefaults.standard.set(value, forKey: "lastStartedStreak")
            } else {
                UserDefaults.standard.removeObject(forKey: "lastStartedStreak")
            }
        }
    }

    @Published public var newStreakNotification: Bool {
        didSet { UserDefaults.standard.set(newStreakNotification, forKey: "newStreakNotification") }
    }

    @Published public private(set) var isComplete = false
    @Published public private(set) var timeRemaining: Int = 0
    @Published public private(set) var isActive = false
    @Published public var timer: Timer? = nil

    private var hasLoadedInitialTime = false
    private var cachedCompletionResult: Bool?
    private var cachedCompletionDate: Date?


    public init() {
        let defaults = UserDefaults.standard
        self.currentStreak = defaults.integer(forKey: "currentStreak")
        self.longestStreak = defaults.integer(forKey: "longestStreak")
        self.totalDaysCompleted = defaults.integer(forKey: "totalDaysCompleted")
        self.lastCompletedStreak = defaults.object(forKey: "lastCompletedStreak") as? Date
        self.lastStartedStreak = defaults.object(forKey: "lastStartedStreak") as? Date
        self.newStreakNotification = defaults.bool(forKey: "newStreakNotification")

        // Only start timer if onboarding is completed
        if defaults.bool(forKey: "isOnboarded") {
            /// checkAndUpdateCompletionDate()
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        timer?.invalidate()
    }

    public func runCountdownTimer() {
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
               // completeMeditation()
            }
        }
    }

    public func completeMeditation() {
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
    public func debugFixStreak() {
        if checkIfCompletedToday() && currentStreak == 0 {
            currentStreak = 1
        }
    }

    public func saveCompletionDate() {
        lastCompletedStreak = Date()
        // Invalidate cache since completion status changed
        cachedCompletionResult = nil
        cachedCompletionDate = nil
    }

    public lazy var calendar: Calendar = {
        var calendar = Calendar.current
        calendar.timeZone = .autoupdatingCurrent
        calendar.locale = .autoupdatingCurrent
        return calendar
    }()

    public func checkIfCompletedToday() -> Bool {
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

    public func midnightOfTomorrow(after date: Date) -> Date? {
        if let nextDay = calendar.date(byAdding: .day, value: 2, to: date) {
            return calendar.startOfDay(for: nextDay)
        }
        return nil
    }

    public func checkIfMidnightOfTomorrowHasPassedSinceLastCompletedStreak() -> Bool {
        guard let lastCompletionDate = lastCompletedStreak,
              let midnightAfterCompletion = midnightOfTomorrow(after: lastCompletionDate) else {
            return false
        }
        return Date() > midnightAfterCompletion
    }

    public func checkAndUpdateCompletionDate() {
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

    public func saveRemainingTime() {
        UserDefaults.standard.set(timeRemaining, forKey: "timeRemaining")
        stopTimer()

    }

    public func stopTimer() {
        isActive = false
        timer?.invalidate()
        timer = nil
    }

    public func startTimerAfterOnboarding() {
        // Called when onboarding completes to start the daily timer
        checkAndUpdateCompletionDate()
    }


    public func progress(for timeRemaining: Int) -> CGFloat {
        let totalTime = TimerViewModel.totalDuration
        let float = CGFloat(timeRemaining) / CGFloat(totalTime)
        return float
    }

    public func timeString(time: Int) -> String {
        let minutes = time / 60
        let seconds = time % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    public lazy var speakLifeArray: [String] = [
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
}
