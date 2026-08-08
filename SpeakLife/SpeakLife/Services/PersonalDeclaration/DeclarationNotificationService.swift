//
//  DeclarationNotificationService.swift
//  SpeakLife
//

import UserNotifications

final class DeclarationNotificationService: DeclarationNotificationServiceProtocol {
    private let center = UNUserNotificationCenter.current()

    /// Pre-multi-declaration identifier. Still removed on every reschedule so
    /// upgrading users don't keep receiving the orphaned original push.
    private static let legacyNotificationId = "personal_declaration_reminder"
    private static let identifierPrefix = "personal_declaration_reminder_"

    /// Minutes between consecutive declaration reminders. Carrying several
    /// burdens shouldn't mean several buzzes in the same minute — each one gets
    /// its own moment in the day.
    private static let staggerMinutes = 45

    private static func identifier(for id: UUID) -> String {
        identifierPrefix + id.uuidString
    }

    // MARK: - Scheduling

    func scheduleAll(_ declarations: [PersonalDeclaration], startTimeIndex: Int) {
        let active = declarations.filter { !$0.isReceived }

        // Drop the legacy single-declaration request and any reminder whose
        // declaration no longer exists, then (re)add the current set.
        center.getPendingNotificationRequests { [weak self] requests in
            guard let self else { return }
            let keep = Set(active.map { Self.identifier(for: $0.id) })
            let stale = requests
                .map(\.identifier)
                .filter { $0 == Self.legacyNotificationId || ($0.hasPrefix(Self.identifierPrefix) && !keep.contains($0)) }
            if !stale.isEmpty {
                self.center.removePendingNotificationRequests(withIdentifiers: stale)
            }
        }

        for (index, declaration) in active.enumerated() {
            schedule(declaration, slot: index, of: active.count, startTimeIndex: startTimeIndex)
        }
    }

    func cancel(id: UUID) {
        print("🚫 personal declaration reminder cancelled for \(id)")
        center.removePendingNotificationRequests(withIdentifiers: [Self.identifier(for: id)])
    }

    func cancelAll() {
        print("🚫 all personal declaration reminders cancelled")
        center.removePendingNotificationRequests(withIdentifiers: [Self.legacyNotificationId])
        center.getPendingNotificationRequests { [weak self] requests in
            guard let self else { return }
            let ids = requests.map(\.identifier).filter { $0.hasPrefix(Self.identifierPrefix) }
            guard !ids.isEmpty else { return }
            self.center.removePendingNotificationRequests(withIdentifiers: ids)
        }
    }

    // MARK: - Private

    private func schedule(_ declaration: PersonalDeclaration,
                          slot: Int,
                          of total: Int,
                          startTimeIndex: Int) {
        let content = UNMutableNotificationContent()
        content.title = total > 1
            ? "What you're believing for \u{1F64F} (\(slot + 1) of \(total))"
            : "Don't forget what you're believing for \u{1F64F}"
        content.body = String(declaration.declarationText.prefix(120)) + "..."
        content.sound = .default
        content.threadIdentifier = "personal_declaration"
        // `declarationId` lets the app open the exact declaration that fired
        // rather than defaulting to the first one in the list.
        content.userInfo = [
            "deepLink": "personalDeclaration",
            "declarationId": declaration.id.uuidString
        ]

        // startTimeIndex = 30-min slots from midnight
        // e.g. index 12 = 6:00 AM, index 16 = 8:00 AM, index 24 = 12:00 PM
        let totalMinutes = (startTimeIndex * 30 + slot * Self.staggerMinutes) % (24 * 60)
        var components = DateComponents()
        components.hour = totalMinutes / 60
        components.minute = totalMinutes % 60

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(
            identifier: Self.identifier(for: declaration.id),
            content: content,
            trigger: trigger
        )
        // Stable identifier — iOS replaces the existing request atomically on add.
        // The previous code did remove+add, which opened a brief window where the
        // notification didn't exist and is a known source of "got it for a few days
        // then it stopped" reports under iOS schedule churn. add() alone is correct.
        center.add(request) { error in
            if let error = error {
                print("❌ personal declaration reminder schedule failed: \(error.localizedDescription)")
            } else {
                print("✅ personal declaration reminder scheduled for \(components.hour ?? -1):\(String(format: "%02d", components.minute ?? 0)) daily (id=\(declaration.id))")
            }
        }
    }
}
