//
//  BurstReminderPlanner.swift
//  SpeakLifeServices
//
//  Decides WHEN the Daily Burst invitations fire and WHAT they say.
//
//  The Daily Burst used to be a once-a-day event: one push at 7:30am, one burst,
//  done. But the burst is seven declarations spoken out loud, and the whole
//  premise of the app is that the more you speak, the more you reap — so the
//  invitation is now a rhythm, not a single alarm. Three times a day by default:
//  set the tone in the morning, refuel at midday, close the day speaking life.
//
//  All of the policy lives here, as pure functions over plain values, so it can
//  be tested without UNUserNotificationCenter, a clock, or a view.
//  `DailyDeclarationReminderService` in the app target does nothing but hand
//  this planner the user's settings and post whatever it returns.
//

import Foundation

// MARK: - Plan

/// One scheduled invitation to come speak a burst.
public struct BurstReminder: Equatable {
    /// 0-based position in the day: 0 is the first invitation, 1 the second.
    public let index: Int
    /// How many invitations the day carries in total. Carried into the payload
    /// so analytics can tell a 1-a-day user's opens from a 3-a-day user's.
    public let total: Int
    public let hour: Int
    public let minute: Int
    public let title: String
    public let body: String

    public init(index: Int, total: Int, hour: Int, minute: Int, title: String, body: String) {
        self.index = index
        self.total = total
        self.hour = hour
        self.minute = minute
        self.title = title
        self.body = body
    }

    /// Stable per-slot identifier. Stable matters: iOS replaces a pending
    /// request with the same identifier in place, so re-running the planner on
    /// every foreground refreshes the copy without ever queueing a duplicate.
    public var identifier: String { BurstReminderPlanner.identifier(forSlot: index) }

    public var minutesFromMidnight: Int { hour * 60 + minute }
}

// MARK: - Planner

public enum BurstReminderPlanner {

    // MARK: Configuration

    /// The out-of-the-box rhythm. Three is the default because it is the
    /// smallest number that turns the burst from an event into a habit loop —
    /// morning, midday, evening — without reading as nagging.
    public static let defaultBurstsPerDay = 3

    /// One a day is the floor (the burst is the app's anchor habit and is never
    /// silently switched off by this control — that is what the reminders toggle
    /// is for). Four is the ceiling: past that the invitations stop being an
    /// invitation.
    public static let allowedBurstsPerDay = 1...4

    /// Minimum gap, in minutes, we keep between a burst invitation and the
    /// nearest notification from the user's own declaration reminder batch.
    static let minGapFromUserRemindersMinutes = 60

    /// Minimum gap, in minutes, we keep between two burst invitations, so
    /// nudging a slot away from a collision can never stack two bursts together.
    static let minGapBetweenBurstsMinutes = 150

    public static func identifier(forSlot index: Int) -> String {
        "daily_burst_slot_\(index + 1)"
    }

    /// Every identifier this planner could ever have written, for the cancel /
    /// re-schedule sweep. Covers the whole allowed range rather than the
    /// current setting, so dropping from 3 a day to 1 actually removes slots 2
    /// and 3 instead of leaving them pending forever.
    public static var allSlotIdentifiers: [String] {
        allowedBurstsPerDay.map { identifier(forSlot: $0 - 1) }
    }

    /// Identifiers written by earlier versions of the burst reminder, swept on
    /// every schedule so an upgrading user does not keep receiving the old
    /// single morning push alongside the new rhythm.
    public static var legacyIdentifiers: [String] {
        var ids = ["daily_declaration_reminder", "daily_declaration_evening_reminder"]
        ids += (1...7).map { "daily_burst_morning_w\($0)" }
        ids += (1...7).map { "daily_burst_evening_w\($0)" }
        return ids
    }

    // MARK: Anchors

    /// Where the invitations sit before any collision nudging. Each row is a
    /// day's rhythm, chosen so the slots land where the day actually has room:
    /// before it starts, in its middle, and before it closes.
    static func anchors(for count: Int) -> [(hour: Int, minute: Int)] {
        switch max(count, 1) {
        case 1:  return [(7, 30)]
        case 2:  return [(7, 30), (19, 30)]
        case 3:  return [(7, 30), (12, 30), (19, 30)]
        default: return [(7, 0), (11, 30), (15, 30), (20, 0)]
        }
    }

    /// How far, in minutes, we are willing to move a slot off its anchor to get
    /// clear of the user's own reminders. Ordered by preference — the anchor
    /// first, then progressively further out, alternating later/earlier so a
    /// morning slot stays a morning slot.
    static let nudgeOffsets = [0, 30, -30, 60, -60, 90, -90]

    // MARK: - Times

    /// Places `count` invitations across the day, keeping each one clear of the
    /// user's own declaration reminders and of the other invitations.
    ///
    /// The burst is shifted rather than dropped. Out of the box the reminder
    /// window opens at 7:00am and the first burst anchor is 7:30, so most users
    /// would otherwise catch two SpeakLife pushes half an hour apart — the
    /// fastest way to train someone to swipe us away. But skipping the burst
    /// whenever a content reminder happens to sit nearby would silently delete
    /// the app's anchor habit for anyone on default settings, so a slot that
    /// cannot find clear air stays on its anchor and accepts the overlap.
    ///
    /// - Parameters:
    ///   - count: how many invitations the day should carry.
    ///   - userReminderMinutes: minutes-from-midnight of the user's own
    ///     declaration reminder batch. Empty when that batch is switched off.
    public static func slotTimes(count: Int,
                                 userReminderMinutes: [Int]) -> [(hour: Int, minute: Int)] {
        let clamped = clampBurstsPerDay(count)
        var placed: [Int] = []
        var result: [(hour: Int, minute: Int)] = []

        for anchor in anchors(for: clamped) {
            let anchorMinutes = anchor.hour * 60 + anchor.minute
            var chosen = anchorMinutes

            for offset in nudgeOffsets {
                let candidate = anchorMinutes + offset
                // Never let a nudge push a slot into the small hours.
                guard candidate >= 6 * 60, candidate <= 22 * 60 else { continue }

                let clearOfUser = userReminderMinutes.allSatisfy {
                    abs($0 - candidate) >= minGapFromUserRemindersMinutes
                }
                let clearOfBursts = placed.allSatisfy {
                    abs($0 - candidate) >= minGapBetweenBurstsMinutes
                }
                if clearOfUser && clearOfBursts {
                    chosen = candidate
                    break
                }
            }

            placed.append(chosen)
            result.append((hour: chosen / 60, minute: chosen % 60))
        }

        return result
    }

    /// Clamps any stored or passed-in value into the supported range. A zero
    /// read back from `UserDefaults` (the value an absent key returns) means
    /// "never set", not "no bursts", so it resolves to the default.
    public static func clampBurstsPerDay(_ value: Int) -> Int {
        guard value > 0 else { return defaultBurstsPerDay }
        return min(max(value, allowedBurstsPerDay.lowerBound), allowedBurstsPerDay.upperBound)
    }

    // MARK: - The Plan

    /// The full set of invitations for a day.
    ///
    /// - Parameters:
    ///   - count: invitations per day, clamped into the allowed range.
    ///   - userReminderMinutes: the user's own reminder batch, to steer clear of.
    ///   - dayIndex: rotates the copy. Callers pass the day of the year, so a
    ///     user who opens the app regularly (which re-runs the planner) never
    ///     reads the same line two mornings running.
    public static func plan(count: Int,
                            userReminderMinutes: [Int],
                            dayIndex: Int) -> [BurstReminder] {
        let clamped = clampBurstsPerDay(count)
        let times = slotTimes(count: clamped, userReminderMinutes: userReminderMinutes)

        return times.enumerated().map { index, time in
            let line = copy(forHour: time.hour, slotIndex: index, dayIndex: dayIndex)
            return BurstReminder(
                index: index,
                total: clamped,
                hour: time.hour,
                minute: time.minute,
                title: line.title,
                body: line.body
            )
        }
    }

    // MARK: - Copy

    /// Which pool a slot draws from, decided by the hour it actually fires at
    /// rather than by its position, so a nudged slot never greets the evening
    /// with "before the day starts".
    enum TimeOfDay {
        case morning, midday, evening

        static func forHour(_ hour: Int) -> TimeOfDay {
            switch hour {
            case ..<11: return .morning
            case 11..<16: return .midday
            default: return .evening
            }
        }
    }

    /// Picks the line for a slot.
    ///
    /// Rotation is keyed on `dayIndex + slotIndex` rather than `dayIndex` alone:
    /// with four invitations a day two of them can share a pool, and without the
    /// slot offset those two would arrive carrying identical copy.
    ///
    /// Every line names the thing being asked for — seven declarations, spoken —
    /// because a push that only says "open SpeakLife" is asking for a tap, and
    /// this one is asking for a voice.
    static func copy(forHour hour: Int, slotIndex: Int, dayIndex: Int) -> (title: String, body: String) {
        let pool: [(title: String, body: String)]
        switch TimeOfDay.forHour(hour) {
        case .morning: pool = morningCopy
        case .midday:  pool = middayCopy
        case .evening: pool = eveningCopy
        }
        // `dayIndex` can arrive negative from a caller doing its own date math;
        // the extra modulus keeps the index inside the pool either way.
        let rotation = ((dayIndex + slotIndex) % pool.count + pool.count) % pool.count
        return pool[rotation]
    }

    static let morningCopy: [(title: String, body: String)] = [
        (
            title: "Your Daily Burst is ready 🔥",
            body: "Seven declarations. Sixty seconds. Speak life over your day before the day speaks over you."
        ),
        (
            title: "Start with your mouth ⚡",
            body: "Seven declarations, out loud, right now. Tap in and set the atmosphere for today."
        ),
        (
            title: "Set the tone 🕊",
            body: "Come speak your seven. One minute of declaring and today has a different weight to it."
        ),
        (
            title: "Seven declarations, one minute 🌅",
            body: "Put the Word in your mouth before the noise gets there first. Your burst is waiting."
        ),
        (
            title: "Speak first, then go 💪",
            body: "Seven declarations before your feet hit the floor running. Tap in and release your faith."
        )
    ]

    static let middayCopy: [(title: String, body: String)] = [
        (
            title: "Round two 🔥",
            body: "Seven more declarations. The more you speak, the more you reap. Take sixty seconds."
        ),
        (
            title: "Midday refuel ⚡",
            body: "Come speak life over the rest of your day. Seven declarations, ready when you are."
        ),
        (
            title: "Say it again 💪",
            body: "Faith comes by hearing, and nobody hears you like you do. Seven declarations, one minute."
        ),
        (
            title: "Don't coast into the afternoon 🌤",
            body: "Seven declarations waiting for your voice. Build your spirit before the second half."
        ),
        (
            title: "Halftime burst 🚀",
            body: "One minute, seven declarations, and you walk into the rest of today full."
        )
    ]

    static let eveningCopy: [(title: String, body: String)] = [
        (
            title: "Close the day strong 🌙",
            body: "Seven declarations before you rest. Speak life over tonight and over tomorrow."
        ),
        (
            title: "One more burst ✨",
            body: "End the day with the Word in your mouth. Seven declarations, sixty seconds."
        ),
        (
            title: "Finish full 🔥",
            body: "Your last burst of the day is ready. Speak your seven and go to sleep full."
        ),
        (
            title: "Before you rest 🕊",
            body: "Seven declarations over your night. Speak them and let your spirit settle."
        ),
        (
            title: "Last call to speak life 🌙",
            body: "Sixty seconds, seven declarations, and today ends the way you wanted it to start."
        )
    ]
}
