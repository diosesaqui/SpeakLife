//
//  AINotificationService.swift
//  SpeakLife
//
//  Historically this scheduled "AI-personalized" pushes on top of everything
//  else the app sends. All of that has been removed:
//
//    • schedulePersonalizedNotifications / generatePersonalizedNotifications —
//      no callers, and would have installed three REPEATING daily generic
//      pushes ("Midday Boost", "Evening Peace", "Your Spiritual Moment") while
//      wiping every other pending request in the process.
//    • scheduleImmediateSupport — "Strength for Right Now", +1 minute. Only
//      entry point was AICrisisSupportView, which was never instantiated.
//    • scheduleCelebration — "Celebrating Your Victory! 🎉", +5 minutes.
//      Duplicated the streak-milestone push users actually receive.
//
//  User-facing pushes now live in exactly three places:
//    LifecycleNotificationService  — lifecycle, streak, lapsed
//    DailyDeclarationReminderService — the 7:30am Daily Burst
//    NotificationManager           — the user's own reminder batch
//
//  What remains here is a one-way healer for devices still carrying the
//  malformed repeating requests an older build scheduled. Keep it until the
//  install base has turned over.
//

import Foundation
import UserNotifications

final class AINotificationService {

    static let shared = AINotificationService()

    private let notificationCenter = UNUserNotificationCenter.current()

    private init() {}

    /// Removes legacy AI notifications that an earlier build scheduled as
    /// *repeating* daily alarms when they were meant to fire once — most
    /// visibly the re-engagement "We've Missed You" push, which a near-midnight
    /// schedule pinned to ~1 AM every night. Matches by the stable declarationId
    /// prefixes those one-shots used and removes any that repeat.
    ///
    /// Also clears any still-pending one-shot from the retired paths above, so
    /// an upgrading device doesn't receive a push whose code no longer exists.
    /// Safe and cheap to call on every launch.
    func cleanupLegacyRepeatingOneShots() {
        notificationCenter.getPendingNotificationRequests { requests in
            // Every `ai_notification_*` request is orphaned now, repeating or
            // not — the code that would have delivered on it is gone. Drop the
            // lot rather than pattern-matching individual retired prefixes.
            let staleIds = requests
                .map(\.identifier)
                .filter { $0.hasPrefix("ai_notification_") }
            guard !staleIds.isEmpty else { return }
            self.notificationCenter.removePendingNotificationRequests(withIdentifiers: staleIds)
            print("🩹 Removed \(staleIds.count) retired AI notification(s)")
        }
    }
}
