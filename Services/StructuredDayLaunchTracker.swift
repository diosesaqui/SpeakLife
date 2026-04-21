//
//  StructuredDayLaunchTracker.swift
//  SpeakLife
//
//  Tracks whether the Structured Day checklist has been shown during today's
//  app session. Resets automatically each calendar day.
//
//  Replaces the BurstCompletionTracker launch-gate logic for the auto-show flow.
//  The burst is still accessible via notification tap and via the checklist task.
//

import Foundation

enum StructuredDayLaunchTracker {

    private static let key = "structuredDayLastShownDate"

    /// Returns true if the Structured Day view has already been shown today.
    static func hasShownToday() -> Bool {
        guard let stored = UserDefaults.standard.object(forKey: key) as? Date else {
            return false
        }
        return Calendar.current.isDateInToday(stored)
    }

    /// Marks the Structured Day view as shown for today.
    static func markShownToday() {
        UserDefaults.standard.set(Date(), forKey: key)
    }

    /// Resets the tracker (e.g. for testing or if user wants to see it again).
    static func reset() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}
