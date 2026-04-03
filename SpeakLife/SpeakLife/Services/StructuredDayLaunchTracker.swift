//
//  StructuredDayLaunchTracker.swift
//  SpeakLife
//
//  Tracks whether the Structured Day checklist has been shown during today's
//  app session. Resets automatically each calendar day.
//

import Foundation

enum StructuredDayLaunchTracker {

    private static let key = "structuredDayLastShownDate"

    static func hasShownToday() -> Bool {
        guard let stored = UserDefaults.standard.object(forKey: key) as? Date else { return false }
        return Calendar.current.isDateInToday(stored)
    }

    static func markShownToday() {
        UserDefaults.standard.set(Date(), forKey: key)
    }

    static func reset() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}
