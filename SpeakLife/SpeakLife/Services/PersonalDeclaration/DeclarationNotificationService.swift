//
//  DeclarationNotificationService.swift
//  SpeakLife
//

import UserNotifications

final class DeclarationNotificationService: DeclarationNotificationServiceProtocol {
    private let center = UNUserNotificationCenter.current()
    private let notificationId = "personal_declaration_reminder"

    func schedule(for declaration: PersonalDeclaration, startTimeIndex: Int) {
        let content = UNMutableNotificationContent()
        content.title = "Don't forget what you're believing for \u{1F64F}"
        content.body = String(declaration.declarationText.prefix(120)) + "..."
        content.sound = .default
        content.userInfo = ["deepLink": "personalDeclaration"]

        // startTimeIndex = 30-min slots from midnight
        // e.g. index 12 = 6:00 AM, index 16 = 8:00 AM, index 24 = 12:00 PM
        let totalMinutes = startTimeIndex * 30
        var components = DateComponents()
        components.hour = (totalMinutes / 60) % 24
        components.minute = totalMinutes % 60

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(
            identifier: notificationId,
            content: content,
            trigger: trigger
        )
        // Stable identifier — iOS replaces the existing request atomically on add.
        // The previous code did remove+add, which opened a brief window where the
        // notification didn't exist and is a known source of "got it for a few days
        // then it stopped" reports under iOS schedule churn. add() alone is correct.
        center.add(request) { error in
            if let error = error {
                print("❌ personal_declaration_reminder schedule failed: \(error.localizedDescription)")
            } else {
                print("✅ personal_declaration_reminder scheduled for \(components.hour ?? -1):\(String(format: "%02d", components.minute ?? 0)) daily (id=\(declaration.id))")
            }
        }
    }

    func cancel() {
        print("🚫 personal_declaration_reminder cancelled")
        center.removePendingNotificationRequests(withIdentifiers: [notificationId])
    }
}
