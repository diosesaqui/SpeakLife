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

    /// UserDefaults key for the canonical "days actually spoken" counter.
    /// Written by `PersonalDeclarationCard` on the first speak of each new day.
    static let completedDayCountKey = "personalDeclaration_completedDayCount"

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
