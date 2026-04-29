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

    var declarationPlaceholder: String {
        switch self {
        case .standing:           return "I stand with you and declare…"
        case .takingGround:       return "I'm in this fight with you. I declare…"
        case .breakthroughComing: return "I'm believing with you for the full thing…"
        case .alreadyDone:        return "It is finished in Jesus' name. I declare…"
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
            return "Declare your healing. What is Christ's payment covering today?"
        case .identity:
            return "Declare who God says you are. Speak it like you own it."
        case .calling:
            return "Declare your calling. What territory are you stepping into?"
        case .peace:
            return "Declare your peace. What is fear losing authority over right now?"
        case .breakthrough:
            return "Declare your breakthrough. What door is God opening?"
        case .warfare:
            return "What ground are you taking back? Declare it."
        case .relationships:
            return "Declare what God is doing in your relationships. Speak it."
        case .faith:
            return "Declare what you are believing God for. Say it boldly."
        }
    }
}
