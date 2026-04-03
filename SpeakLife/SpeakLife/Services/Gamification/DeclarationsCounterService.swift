//
//  DeclarationsCounterService.swift
//  SpeakLife
//
//  Tracks lifetime and daily declarations spoken.
//  Persists locally in UserDefaults and syncs to Firestore so counts
//  survive both app restarts AND fresh installs (restored from cloud).
//

import Foundation
import FirebaseFirestore
import UserNotifications

// MARK: - DeclarationsCounterService

/// Singleton service that records how many declarations a user has spoken.
/// Call `recordDeclarations(count:)` after every burst/session completion.
final class DeclarationsCounterService: ObservableObject {

    static let shared = DeclarationsCounterService()

    // MARK: - Published State

    @Published private(set) var lifetimeCount: Int = 0
    @Published private(set) var todayCount: Int = 0

    // MARK: - UserDefaults Keys

    private enum Keys {
        static let lifetimeCount  = "declarations_lifetime_count"
        static let todayCount     = "declarations_today_count"
        static let lastCountDate  = "declarations_last_count_date"
        static let notifiedMilestones = "declarations_notified_milestones"
    }

    // MARK: - Milestones (push notifications sent once each)

    private let milestones: [Int] = [100, 500, 1000, 5000, 10_000]

    // MARK: - Firestore

    private let db = Firestore.firestore()
    private var _userId: String?

    // MARK: - Init

    private init() {
        loadFromLocal()
        resetTodayCountIfNeeded()
    }

    // MARK: - Public API

    /// Call once the user is authenticated so we can sync with Firestore.
    func configure(userId: String) {
        _userId = userId
        syncFromFirestore()
    }

    /// Record `count` declarations spoken (called after each burst completion).
    func recordDeclarations(count: Int) {
        guard count > 0 else { return }

        let previousLifetime = lifetimeCount
        lifetimeCount += count
        todayCount    += count

        saveToLocal()
        syncToFirestore()
        checkMilestones(previous: previousLifetime, current: lifetimeCount)
    }

    // MARK: - Formatted Helpers

    var formattedLifetime: String { lifetimeCount.declarationFormatted }
    var formattedToday: String    { todayCount.declarationFormatted }

    // MARK: - Private: Persistence

    private func loadFromLocal() {
        lifetimeCount = UserDefaults.standard.integer(forKey: Keys.lifetimeCount)
        todayCount    = UserDefaults.standard.integer(forKey: Keys.todayCount)
    }

    private func saveToLocal() {
        UserDefaults.standard.set(lifetimeCount, forKey: Keys.lifetimeCount)
        UserDefaults.standard.set(todayCount,    forKey: Keys.todayCount)
        UserDefaults.standard.set(Date(),         forKey: Keys.lastCountDate)
    }

    private func resetTodayCountIfNeeded() {
        guard let last = UserDefaults.standard.object(forKey: Keys.lastCountDate) as? Date else { return }
        if !Calendar.current.isDateInToday(last) {
            todayCount = 0
            UserDefaults.standard.set(0, forKey: Keys.todayCount)
        }
    }

    // MARK: - Private: Firestore Sync

    private func syncToFirestore() {
        guard let uid = _userId else { return }
        let data: [String: Any] = [
            "lifetimeDeclarations": lifetimeCount,
            "todayDeclarations":    todayCount,
            "declarationsLastSync": Timestamp(date: Date())
        ]
        db.collection("users").document(uid).setData(data, merge: true) { error in
            if let error = error {
                print("DeclarationsCounterService ▶ Firestore write error: \(error.localizedDescription)")
            }
        }
    }

    private func syncFromFirestore() {
        guard let uid = _userId else { return }
        db.collection("users").document(uid).getDocument { [weak self] snapshot, error in
            guard let self = self, error == nil,
                  let data = snapshot?.data() else { return }

            let remote = data["lifetimeDeclarations"] as? Int ?? 0
            DispatchQueue.main.async {
                // Use whichever value is higher — handles reinstall / new device
                if remote > self.lifetimeCount {
                    self.lifetimeCount = remote
                    self.saveToLocal()
                }
            }
        }
    }

    // MARK: - Private: Milestones

    private func checkMilestones(previous: Int, current: Int) {
        var notified = Set(UserDefaults.standard.array(forKey: Keys.notifiedMilestones) as? [Int] ?? [])
        for milestone in milestones where previous < milestone && current >= milestone && !notified.contains(milestone) {
            scheduleMilestoneNotification(milestone: milestone)
            notified.insert(milestone)
        }
        UserDefaults.standard.set(Array(notified), forKey: Keys.notifiedMilestones)
    }

    private func scheduleMilestoneNotification(milestone: Int) {
        let content = UNMutableNotificationContent()
        content.title = "🎉 Milestone Unlocked!"
        content.body  = milestoneMessage(for: milestone)
        content.sound = .default
        content.userInfo = ["type": "declarations_milestone", "milestone": milestone]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "declarations_milestone_\(milestone)",
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }

    private func milestoneMessage(for milestone: Int) -> String {
        switch milestone {
        case 100:    return "You've spoken 100 declarations! Your faith is growing strong 🌱"
        case 500:    return "500 declarations spoken! You're building an unshakeable foundation 💪"
        case 1_000:  return "1,000 declarations! A true warrior of faith 🛡️"
        case 5_000:  return "5,000 declarations! Your words are moving mountains ⛰️"
        case 10_000: return "10,000 declarations! You are a legend of faith 👑"
        default:     return "You've spoken \(milestone.declarationFormatted) declarations! Keep going! 🔥"
        }
    }
}

// MARK: - Int Formatting Helper

extension Int {
    /// Formats with thousands separators: 1247 → "1,247"
    var declarationFormatted: String {
        let fmt = NumberFormatter()
        fmt.numberStyle = .decimal
        return fmt.string(from: NSNumber(value: self)) ?? "\(self)"
    }
}
