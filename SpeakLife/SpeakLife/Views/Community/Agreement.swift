//
//  Agreement.swift
//  SpeakLife
//
//  A short statement of agreement another believer adds over a Warrior
//  Room post. One agreement per user per post — these form a chain below
//  the original post and are not themselves reactable.
//

import Foundation
import FirebaseFirestore

struct Agreement: Identifiable, Codable, Equatable {
    @DocumentID var id: String?
    let userId: String
    let displayName: String
    let reactionType: String
    let text: String
    let timestamp: Timestamp

    /// The reaction the believer chose alongside this agreement, if recognised.
    var reaction: WarriorRoomReaction? {
        WarriorRoomReaction(rawValue: reactionType)
    }

    /// Spec cap — enforced at the input level and at write time.
    static let maxLength = 150
}
