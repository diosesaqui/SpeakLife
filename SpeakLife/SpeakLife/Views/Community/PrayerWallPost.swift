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

    /// The auth uid of the post creator. Required for rules-based ownership
    /// gating (only the author can mark `isAnswered`). Optional for backwards
    /// compat — legacy posts have nil and are owned by no one (rules deny
    /// all owner-gated mutations on them).
    var authorUid: String?

    init(text: String,
         displayName: String,
         deviceId: String,
         category: WarriorRoomCategory? = nil,
         authorUid: String? = nil) {
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
        self.authorUid = authorUid
    }
}

// MARK: - Reactions / Category helpers

extension PrayerWallPost {
    /// Total reactions across all four types. `prayerCount` is kept in sync
    /// with the running total by the ViewModel on every reaction write, so
    /// it's the authoritative total for both legacy and v2 posts.
    var totalReactions: Int {
        prayerCount
    }

    /// Count for a specific reaction type.
    ///
    /// For legacy posts (`reactionCounts == nil`) every prior 🙏 tap is
    /// attributed to `.standing`.
    ///
    /// For posts that crossed the v2 boundary mid-life (some legacy 🙏 taps,
    /// then later a non-`.standing` reaction was added), `prayerCount` will
    /// be higher than the sum of `reactionCounts`. We attribute that gap to
    /// `.standing` so the legacy taps still appear in the per-reaction
    /// breakdown.
    func count(for reaction: WarriorRoomReaction) -> Int {
        guard let counts = reactionCounts else {
            return reaction == .standing ? prayerCount : 0
        }
        let raw = max(0, counts[reaction.rawValue] ?? 0)
        guard reaction == .standing else { return raw }
        let sum = counts.values.map { max(0, $0) }.reduce(0, +)
        let gap = max(0, prayerCount - sum)
        return raw + gap
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
