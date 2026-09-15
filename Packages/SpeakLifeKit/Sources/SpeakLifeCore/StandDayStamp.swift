//
//  StandDayStamp.swift
//  SpeakLifeCore
//
//  The "yyyy-MM-dd" local-day stamp a Stand uses to answer one question:
//  did this person speak today?
//
//  It is DISPLAY ONLY. It drives the week strip and nothing else. Progress
//  lives in `dayNumber`, which mirrors `EnforcementProgress.currentDay` and is
//  monotonic. That separation is deliberate and load-bearing: a stamp written
//  under a wrong clock, or flushed from the offline queue two days late, costs
//  a dot on a strip and can never cost a campaign day.
//
//  Two members in different time zones each use THEIR OWN local day. Nobody is
//  late because of a date line.
//

import Foundation

public enum StandDayStamp {

    /// The stamp for a date in a given calendar.
    ///
    /// Derived from `DateComponents`, never from an interval divided by 86,400.
    /// A day is not always 86,400 seconds — DST makes it 23 or 25 hours twice a
    /// year, and the divide-by-a-constant version silently puts those days on
    /// the wrong stamp.
    public static func stamp(for date: Date = Date(),
                             calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        guard let y = c.year, let m = c.month, let d = c.day else { return "" }
        return String(format: "%04d-%02d-%02d", y, m, d)
    }

    /// The stamps for the last `count` days, oldest first, ending on `date`.
    ///
    /// Used by the week strip. Walks the calendar day by day rather than
    /// subtracting seconds, for the same reason as above.
    public static func lastDays(_ count: Int,
                                endingOn date: Date = Date(),
                                calendar: Calendar = .current) -> [String] {
        guard count > 0 else { return [] }
        var out: [String] = []
        for offset in stride(from: count - 1, through: 0, by: -1) {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: date) else { continue }
            out.append(stamp(for: day, calendar: calendar))
        }
        return out
    }

    /// True when `stamp` names the same day as `date` in `calendar`.
    public static func isToday(_ stamp: String,
                              on date: Date = Date(),
                              calendar: Calendar = .current) -> Bool {
        !stamp.isEmpty && stamp == self.stamp(for: date, calendar: calendar)
    }

    /// The IANA identifier written alongside a day write, so the server can
    /// schedule a nudge for the member's own evening.
    public static var currentTimeZoneIdentifier: String {
        TimeZone.current.identifier
    }

    /// Shape check matching the one in `firestore.rules`.
    ///
    /// The rules validate shape only and deliberately not the value — see the
    /// comment on `isWellFormedDayStamp` there. This mirrors that check so the
    /// client never sends a write the server is going to bounce.
    public static func isWellFormed(_ stamp: String) -> Bool {
        guard stamp.count == 10 else { return false }
        let parts = stamp.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3,
              parts[0].count == 4, parts[1].count == 2, parts[2].count == 2 else { return false }
        return parts.allSatisfy { $0.allSatisfy(\.isNumber) }
    }
}
