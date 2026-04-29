//
//  PrayerWallPost.swift
//  SpeakLife
//
//  Model for community Warrior Room (Prayer Wall) posts.
//

import Foundation
import FirebaseFirestore

struct PrayerWallPost: Identifiable, Codable {
    @DocumentID var id: String?
    let text: String
    let displayName: String   // e.g. "A sister in Christ"
    let deviceId: String
    let timestamp: Timestamp
    var prayerCount: Int
    var reports: Int
    var isHidden: Bool
    var isAnswered: Bool

    // MARK: - v2 additions (all optional for backwards compat with posts
    // created before the Warrior Room enhancements shipped).

    /// Raw value of `WarriorRoomCategory`. Required on new posts; nil on legacy posts.
    var category: String?

    /// Denormalised count per reaction type, keyed by `WarriorRoomReaction.rawValue`.
    /// Nil on legacy posts — UI falls back to `prayerCount` as the "standing" count.
    var reactionCounts: [String: Int]?

    init(text: String,
         displayName: String,
         deviceId: String,
         category: WarriorRoomCategory? = nil) {
        self.text = text
        self.displayName = displayName
        self.deviceId = deviceId
        self.timestamp = Timestamp()
        self.prayerCount = 0
        self.reports = 0
        self.isHidden = false
        self.isAnswered = false
        self.category = category?.rawValue
        self.reactionCounts = nil
    }
}

// MARK: - Reactions / Category helpers

extension PrayerWallPost {
    /// Total reactions across all four types. Falls back to the legacy
    /// `prayerCount` for posts created before reactionCounts existed.
    var totalReactions: Int {
        if let counts = reactionCounts {
            return counts.values.reduce(0, +)
        }
        return prayerCount
    }

    /// Count for a specific reaction type. Legacy posts attribute every prior
    /// "Praying with you" tap to the new "standing" reaction.
    func count(for reaction: WarriorRoomReaction) -> Int {
        if let counts = reactionCounts {
            return counts[reaction.rawValue] ?? 0
        }
        return reaction == .standing ? prayerCount : 0
    }

    /// Reactions present on the post sorted by count descending.
    /// Used by the card to show the top two reaction icons.
    var topReactions: [(reaction: WarriorRoomReaction, count: Int)] {
        WarriorRoomReaction.allCases
            .map { ($0, count(for: $0)) }
            .filter { $0.1 > 0 }
            .sorted { $0.1 > $1.1 }
    }

    var categoryEnum: WarriorRoomCategory? {
        guard let category else { return nil }
        return WarriorRoomCategory(rawValue: category)
    }
}
