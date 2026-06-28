//
//  PersonalDeclaration.swift
//  SpeakLife
//

import Foundation

struct PersonalDeclaration: Codable, Equatable {
    let id: UUID
    let beliefText: String          // raw text from user (transcribed or typed)
    let declarationText: String     // matched declaration
    let verse: String               // matched Bible verse text
    let verseReference: String      // e.g. "Jeremiah 29:11"
    let categoryRaw: String         // DeclarationCategory rawValue
    let startDate: Date
    var receivedDate: Date?
    var testimony: String?

    var isReceived: Bool { receivedDate != nil }

    /// UserDefaults keys for the "days actually spoken" tracking, written by
    /// `PersonalDeclarationCard` as the user speaks. `completedDayCountKey` is
    /// the canonical "Day N" counter. These are reset when a new declaration is
    /// created (see `SavePersonalDeclarationUseCase`) so the count starts fresh.
    static let completedDayCountKey = "personalDeclaration_completedDayCount"
    static let dailySpeakCountKey = "personalDeclaration_dailySpeakCount"
    static let lastSpokenDateKey = "personalDeclaration_lastSpokenDate"

    /// Clears the spoken-day tracking so a newly created declaration starts at
    /// Day 1 instead of inheriting the previous declaration's progress.
    static func resetSpeakTracking(in defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: completedDayCountKey)
        defaults.removeObject(forKey: dailySpeakCountKey)
        defaults.removeObject(forKey: lastSpokenDateKey)
    }

    /// "Day N" reflects the number of unique days the user has actually spoken
    /// this declaration — not calendar drift since `startDate`. This keeps the
    /// feed tile ("Day N of believing"), the breakthrough flow, and the full
    /// card in sync; previously the tile counted calendar days while the card
    /// counted spoken days, so they diverged whenever a day was skipped.
    var dayCount: Int {
        max(1, UserDefaults.standard.integer(forKey: Self.completedDayCountKey))
    }

    var category: DeclarationCategory? {
        DeclarationCategory(rawValue: categoryRaw)
    }
}
