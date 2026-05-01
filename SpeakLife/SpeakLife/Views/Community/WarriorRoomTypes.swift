//
//  WarriorRoomTypes.swift
//  SpeakLife
//
//  Reaction and Category enums shared across the Warrior Room feature.
//

import SwiftUI

// MARK: - Reactions

/// The four reaction types a believer can register against a Warrior Room post.
/// Raw values are persisted to Firestore — do not rename without a migration.
enum WarriorRoomReaction: String, Codable, CaseIterable, Identifiable {
    case standing                                   // 🔥 Standing with you
    case takingGround = "taking_ground"             // ⚔️ Taking ground
    case breakthroughComing = "breakthrough_coming" // 🙌 Breakthrough coming
    case alreadyDone = "already_done"               // 👑 Already done

    var id: String { rawValue }

    var emoji: String {
        switch self {
        case .standing:           return "🔥"
        case .takingGround:       return "⚔️"
        case .breakthroughComing: return "🙌"
        case .alreadyDone:        return "👑"
        }
    }

    var label: String {
        switch self {
        case .standing:           return "Standing with you"
        case .takingGround:       return "Taking ground"
        case .breakthroughComing: return "Breakthrough coming"
        case .alreadyDone:        return "Already done"
        }
    }

    var shortLabel: String {
        switch self {
        case .standing:           return "Standing"
        case .takingGround:       return "Taking ground"
        case .breakthroughComing: return "Breakthrough"
        case .alreadyDone:        return "Done"
        }
    }

    var agreementPlaceholder: String {
        switch self {
        case .standing:           return "I'm standing with you. Tell them…"
        case .takingGround:       return "I'm in this fight with you…"
        case .breakthroughComing: return "I'm believing with you for the full thing…"
        case .alreadyDone:        return "It is finished in Jesus' name…"
        }
    }
}

// MARK: - Categories

/// The eight ground-categories a Warrior Room post can be tagged with.
/// Required on every new post. Existing posts created before this feature
/// shipped may have a nil category — the UI treats that as "uncategorized".
enum WarriorRoomCategory: String, Codable, CaseIterable, Identifiable {
    case healing
    case identity
    case calling
    case peace
    case breakthrough
    case warfare
    case relationships
    case faith

    var id: String { rawValue }

    var emoji: String {
        switch self {
        case .healing:       return "🌿"
        case .identity:      return "👑"
        case .calling:       return "🧭"
        case .peace:         return "🕊"
        case .breakthrough:  return "💰"
        case .warfare:       return "⚡"
        case .relationships: return "🤝"
        case .faith:         return "🙏"
        }
    }

    var label: String {
        switch self {
        case .healing:       return "Healing"
        case .identity:      return "Identity"
        case .calling:       return "Calling"
        case .peace:         return "Peace"
        case .breakthrough:  return "Breakthrough"
        case .warfare:       return "Warfare"
        case .relationships: return "Relationships"
        case .faith:         return "Faith"
        }
    }

    var composerPlaceholder: String {
        switch self {
        case .healing:
            return "What healing do you need? Share it with the room."
        case .identity:
            return "Where do you need prayer to walk in who God says you are?"
        case .calling:
            return "What is God calling you to that you need prayer for?"
        case .peace:
            return "What is stealing your peace? Bring it here."
        case .breakthrough:
            return "What breakthrough are you praying for?"
        case .warfare:
            return "What ground are you fighting for? Where do you need backup?"
        case .relationships:
            return "What's happening in your relationships?"
        case .faith:
            return "What are you believing God for?"
        }
    }
}
