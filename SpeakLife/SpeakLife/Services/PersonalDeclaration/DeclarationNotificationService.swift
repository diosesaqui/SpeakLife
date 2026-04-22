//
//  DeclarationNotificationService.swift
//  SpeakLife
//

import UserNotifications

final class DeclarationNotificationService: DeclarationNotificationServiceProtocol {
    private let center = UNUserNotificationCenter.current()
    private let notificationId = "personal_declaration_reminder"

    func schedule(for declaration: PersonalDeclaration, startTimeIndex: Int) {
        center.removePendingNotificationRequests(withIdentifiers: [notificationId])

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
        center.add(request, withCompletionHandler: nil)
    }

    func cancel() {
        center.removePendingNotificationRequests(withIdentifiers: [notificationId])
    }
}
