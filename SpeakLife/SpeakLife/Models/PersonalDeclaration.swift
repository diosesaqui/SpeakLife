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

    var dayCount: Int {
        max(1, (Calendar.current.dateComponents([.day], from: startDate, to: Date()).day ?? 0) + 1)
    }

    var category: DeclarationCategory? {
        DeclarationCategory(rawValue: categoryRaw)
    }
}
