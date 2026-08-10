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

    /// Latest a staggered reminder may land (9:30 PM). Past this the stagger
    /// runs backwards from the user's chosen time instead of forwards: someone
    /// who picked 10 PM wants their declarations at night, not at 1 AM.
    private static let latestReminderMinute = 21 * 60 + 30

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

    /// Minute-of-day for one declaration's reminder.
    ///
    /// `startTimeIndex` is a 30-minute slot from midnight (12 = 6:00 AM,
    /// 16 = 8:00 AM, 24 = 12:00 PM). Reminders fan out from there, forwards
    /// where the day has room and backwards where it doesn't, so the whole set
    /// stays inside the waking hours the user actually chose.
    static func minuteOfDay(slot: Int, total: Int, startTimeIndex: Int) -> Int {
        let start = (startTimeIndex * 30) % (24 * 60)
        let span = max(0, total - 1) * staggerMinutes
        // Running backwards, the last declaration takes the chosen time and the
        // first sits earliest, so the reminders still arrive in list order.
        let minute = start + span <= latestReminderMinute
            ? start + slot * staggerMinutes
            : start - (max(0, total - 1) - slot) * staggerMinutes
        // Backwards only runs when the start is late enough that it can't reach
        // midnight, but clamp anyway rather than schedule a negative hour.
        return min(max(minute, 0), 24 * 60 - 1)
    }

    /// The daily repeat, or a one-off for tomorrow when today is already done.
    ///
    /// A repeating `UNCalendarNotificationTrigger` cannot skip an occurrence, so
    /// someone who spoke their declaration at 8am still got reminded to do it at
    /// 10am — being nagged about work they had already finished, which is the
    /// fastest way to teach someone to ignore the app's notifications.
    ///
    /// The swap is net-zero on the notification budget, and that matters: the
    /// app deliberately runs at roughly 61 of iOS's 64 pending slots (see the
    /// budget note in `NotificationManager`), so anything that ADDS requests
    /// makes iOS silently drop sends elsewhere. Same identifier, one request
    /// either way — the repeat is simply replaced for a day.
    ///
    /// The repeat comes back on the next app open: `scheduleAll` runs from
    /// `rescheduleActivePersonalDeclarationIfNeeded` on every launch, and by
    /// then `spokenToday` is false again.
    static func trigger(atMinuteOfDay minute: Int,
                        skippingToday: Bool,
                        now: Date = Date(),
                        calendar: Calendar = .current) -> UNCalendarNotificationTrigger {
        var components = DateComponents()
        components.hour = minute / 60
        components.minute = minute % 60

        // Only worth skipping while today's reminder is still ahead of us. Once
        // it has passed, the repeating trigger's next fire is already tomorrow.
        guard skippingToday else {
            return UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        }
        let todayAtMinute = calendar.date(bySettingHour: minute / 60,
                                          minute: minute % 60,
                                          second: 0,
                                          of: now)
        guard let todayAtMinute, todayAtMinute > now,
              let tomorrow = calendar.date(byAdding: .day, value: 1, to: todayAtMinute) else {
            return UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        }

        let dated = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: tomorrow)
        return UNCalendarNotificationTrigger(dateMatching: dated, repeats: false)
    }

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

        let totalMinutes = Self.minuteOfDay(slot: slot, total: total, startTimeIndex: startTimeIndex)

        let trigger = Self.trigger(atMinuteOfDay: totalMinutes, skippingToday: declaration.spokenToday)
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
                let hour = totalMinutes / 60, minute = totalMinutes % 60
                let when = declaration.spokenToday ? "tomorrow only" : "daily"
                print("✅ personal declaration reminder scheduled for \(hour):\(String(format: "%02d", minute)) \(when) (id=\(declaration.id))")
            }
        }
    }
}
