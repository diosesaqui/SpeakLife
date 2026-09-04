//
//  DailyDeclarationReminderService.swift
//  SpeakLife
//
//  Schedules the Daily Burst invitations — the pushes that call the user in to
//  speak their seven declarations.
//
//  This used to be a single morning alarm. It is now a rhythm: three
//  invitations a day out of the box (morning, midday, evening), adjustable
//  between one and four in Reminders. The burst is seven declarations spoken
//  out loud, and the more you speak the more you reap, so the invitation is
//  worth more than once.
//
//  All the policy — where the slots sit, how they dodge the user's own
//  reminder batch, what each one says — lives in `BurstReminderPlanner`, which
//  is pure and tested. This file is the part that talks to iOS.
//

import Foundation
import UserNotifications
import UIKit

class DailyDeclarationReminderService: ObservableObject {
    static let shared = DailyDeclarationReminderService()

    @Published var isEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: Self.enabledKey)
            if isEnabled {
                scheduleBurstReminders()
            } else {
                cancelDailyDeclarationReminder()
            }
        }
    }

    /// How many times a day the user is invited into a burst. 1...4, default 3.
    ///
    /// Separate from `isEnabled` on purpose: turning the rhythm down to one a
    /// day is a volume choice, and switching the invitations off entirely is a
    /// different decision that belongs to the toggle.
    @Published var burstsPerDay: Int {
        didSet {
            let clamped = BurstReminderPlanner.clampBurstsPerDay(burstsPerDay)
            // Assigning inside a property's own `didSet` does not re-enter it,
            // so this cannot recurse — and everything below runs on `clamped`
            // regardless of which branch we came in on.
            if clamped != burstsPerDay { burstsPerDay = clamped }
            UserDefaults.standard.set(clamped, forKey: Self.burstsPerDayKey)
            if isEnabled {
                scheduleBurstReminders()
            }
        }
    }

    static let enabledKey = "dailyDeclarationRemindersEnabled"
    static let burstsPerDayKey = "burstRemindersPerDay"

    private init() {
        // Check if this is the first time - if key doesn't exist, default to true
        if UserDefaults.standard.object(forKey: Self.enabledKey) == nil {
            // First time user - enable by default
            self.isEnabled = true
            UserDefaults.standard.set(true, forKey: Self.enabledKey)
            #if DEBUG
            print("🔔 Daily reminders enabled by default for new user")
            #endif
        } else {
            self.isEnabled = UserDefaults.standard.bool(forKey: Self.enabledKey)
            #if DEBUG
            print("🔔 Daily reminders loaded from settings: \(self.isEnabled)")
            #endif
        }

        // An absent key reads back as 0, which the planner resolves to the
        // default — so existing users are moved onto the three-a-day rhythm
        // without a migration flag, and anyone who picks a number keeps it.
        self.burstsPerDay = BurstReminderPlanner.clampBurstsPerDay(
            UserDefaults.standard.integer(forKey: Self.burstsPerDayKey)
        )
    }

    func setupDailyReminders() {
        // Check if user has enabled notifications and wants daily reminders
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                if settings.authorizationStatus == .authorized && self.isEnabled {
                    self.scheduleBurstReminders()
                }
            }
        }
    }

    /// Re-runs the plan. Cheap and idempotent — every request carries a stable
    /// per-slot identifier, so iOS replaces in place and nothing is ever
    /// double-queued.
    ///
    /// Called on every foreground, for two reasons. The copy rotates on the day
    /// of the year, so a user who opens the app is never read the same line two
    /// mornings running; and the slots dodge the user's own reminder batch,
    /// which they can move at any time in Reminders.
    func refreshBurstReminders() {
        // Adopt a count chosen on another device. `burstRemindersPerDay` is
        // whitelisted in SyncedSettingsStore, which writes straight into
        // UserDefaults — it cannot reach this @Published property, so without
        // this the phone would keep scheduling its own number until the next
        // cold launch. The assignment is guarded so it does not re-schedule on
        // every foreground for the common case where nothing changed.
        let stored = BurstReminderPlanner.clampBurstsPerDay(
            UserDefaults.standard.integer(forKey: Self.burstsPerDayKey)
        )
        if stored != burstsPerDay {
            burstsPerDay = stored
        }

        guard isEnabled else { return }
        setupDailyReminders()
    }

    private func scheduleBurstReminders() {
        let center = UNUserNotificationCenter.current()
        // Sweep first: the legacy single-morning IDs from before the rhythm
        // existed, and every slot in the allowed range rather than just the
        // current count, so dropping from 3 a day to 1 actually retires slots
        // 2 and 3 instead of leaving them pending forever.
        center.removePendingNotificationRequests(withIdentifiers: BurstReminderPlanner.legacyIdentifiers)
        center.removePendingNotificationRequests(withIdentifiers: BurstReminderPlanner.allSlotIdentifiers)

        let reminders = BurstReminderPlanner.plan(
            count: burstsPerDay,
            userReminderMinutes: Self.userReminderMinutes(),
            dayIndex: Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 0
        )

        for reminder in reminders {
            let content = UNMutableNotificationContent()
            content.title = reminder.title
            content.body = reminder.body
            content.sound = UNNotificationSound.default
            content.categoryIdentifier = "DAILY_DECLARATION"
            // `action` is what routes the tap straight into the burst — see
            // NotificationHandler. The slot fields ride along so opens can be
            // read per slot instead of lumped into one number.
            content.userInfo = [
                "action": "daily_declaration_burst",
                "burst_slot": reminder.index + 1,
                "burst_slots_per_day": reminder.total
            ]

            var dateComponents = DateComponents()
            dateComponents.hour = reminder.hour
            dateComponents.minute = reminder.minute

            // Daily-repeating, one pending request per slot. The previous
            // implementation queued one request per weekday to rotate its copy,
            // which cost seven pending slots out of the OS's 64 for a single
            // invitation a day — three times a day that way would have crowded
            // out the content batch. Rotating on refresh instead buys the same
            // variety for three pending requests.
            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
            let request = UNNotificationRequest(
                identifier: reminder.identifier,
                content: content,
                trigger: trigger
            )
            center.add(request) { error in
                if let error = error {
                    print("❌ Error scheduling burst slot \(reminder.index + 1): \(error.localizedDescription)")
                }
            }
        }

        #if DEBUG
        let times = reminders.map { String(format: "%02d:%02d", $0.hour, $0.minute) }.joined(separator: ", ")
        print("🔔 Daily Burst invitations scheduled at \(times)")
        #endif
    }

    /// The times the user's own declaration reminder batch fires, in minutes
    /// from midnight — the thing the burst slots steer clear of. Empty when that
    /// batch is switched off, in which case there is nothing to collide with.
    private static func userReminderMinutes() -> [Int] {
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: "notificationEnabled") else { return [] }

        let count = defaults.integer(forKey: "notificationCount")
        let start = defaults.integer(forKey: "startTimeIndex")
        let end = defaults.integer(forKey: "endTimeIndex")
        guard count > 0, end > start else { return [] }

        return NotificationManager.shared
            .distributeTimes(startTime: start, endTime: end, count: count)
            .map { $0.hour * 60 + $0.minute }
    }

    /// The scheduled invitation times, for display in Reminders so the user can
    /// see what they just chose.
    var scheduledTimes: [(hour: Int, minute: Int)] {
        BurstReminderPlanner.slotTimes(
            count: burstsPerDay,
            userReminderMinutes: Self.userReminderMinutes()
        )
    }

    private func cancelDailyDeclarationReminder() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: BurstReminderPlanner.legacyIdentifiers)
        center.removePendingNotificationRequests(withIdentifiers: BurstReminderPlanner.allSlotIdentifiers)
        print("Daily declaration reminders cancelled")
    }

    /// A Daily Burst push was tapped: open the burst.
    ///
    /// Two hops on purpose. The burst's cover is owned by the declaration feed,
    /// and a cover asserted on a tab the user is not looking at presents into
    /// nothing — so a tap that landed while they were on Today, Audio or
    /// Profile silently did nothing. `HomeView` listens for this, selects the
    /// feed's tab, and only then posts `ShowDailyDeclarationBurst`, which is
    /// what the feed itself listens for.
    func handleNotificationTap() {
        NotificationCenter.default.post(
            name: Self.openBurstFromNotification,
            object: nil
        )
    }

    /// Posted on a burst push tap. Routed by `HomeView`.
    static let openBurstFromNotification = Notification.Name("OpenDailyBurstFromNotification")
}

// Notification action setup
extension DailyDeclarationReminderService {
    static func setupNotificationActions() {
        let declareAction = UNNotificationAction(
            identifier: "DECLARE_NOW",
            title: "Speak Life Now",
            options: [.foreground]
        )

        let laterAction = UNNotificationAction(
            identifier: "REMIND_LATER",
            title: "Remind Me Later",
            options: []
        )

        let category = UNNotificationCategory(
            identifier: "DAILY_DECLARATION",
            actions: [declareAction, laterAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )

        UNUserNotificationCenter.current().setNotificationCategories([category])
    }
}
