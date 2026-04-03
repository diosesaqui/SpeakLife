//
//  FaithJourneyModel.swift
//  SpeakLife
//
//  Data model for the 21-Day Faith Journey feature.
//

import Foundation

// MARK: - FaithJourney

/// Represents one user's 21-day commitment to a chosen category.
struct FaithJourney: Codable, Identifiable {

    // MARK: - Stored Properties

    var id: String
    var userId: String
    var categoryId: String
    var categoryName: String
    var startDate: Date
    /// Days 1–21 that have been marked complete (by speaking that day's declarations).
    var completedDays: [Int]
    var isActive: Bool
    /// True once a streak-shield has been consumed to cover a missed day.
    var streakShieldUsed: Bool

    // MARK: - Computed Properties

    /// Which calendar day (1–21) the journey is currently on.
    var currentDay: Int {
        let elapsed = Calendar.current.dateComponents([.day], from: startDate, to: Date()).day ?? 0
        return min(max(elapsed + 1, 1), 21)
    }

    var completedDaySet: Set<Int> { Set(completedDays) }

    var isCompleted: Bool { completedDays.count >= 21 }

    var progressPercent: Double { Double(completedDays.count) / 21.0 }

    // MARK: - Milestones

    var hasEarnedWeekOneBadge:  Bool { completedDaySet.count >= 7  }
    var hasUnlockedBonusAudio:  Bool { completedDaySet.count >= 14 }
    var hasEarnedMastery:       Bool { completedDaySet.count >= 21 }

    // MARK: - Init

    init(userId: String, categoryId: String, categoryName: String) {
        self.id              = UUID().uuidString
        self.userId          = userId
        self.categoryId      = categoryId
        self.categoryName    = categoryName
        self.startDate       = Date()
        self.completedDays   = []
        self.isActive        = true
        self.streakShieldUsed = false
    }
}

// MARK: - JourneyMilestone

enum JourneyMilestone: Identifiable {
    case day7Badge
    case day14BonusAudio
    case day21Mastery

    var id: Int { day }

    var day: Int {
        switch self {
        case .day7Badge:       return 7
        case .day14BonusAudio: return 14
        case .day21Mastery:    return 21
        }
    }

    var title: String {
        switch self {
        case .day7Badge:       return "One Week Strong! 🏅"
        case .day14BonusAudio: return "Two Weeks — Bonus Unlocked! 🎵"
        case .day21Mastery:    return "21-Day Mastery! 👑"
        }
    }

    var message: String {
        switch self {
        case .day7Badge:
            return "You've completed 7 days of your faith journey. A badge has been awarded!"
        case .day14BonusAudio:
            return "14 days strong! A bonus audio has been unlocked for you."
        case .day21Mastery:
            return "You've completed the full 21-Day Faith Journey. Share your achievement!"
        }
    }

    var systemIcon: String {
        switch self {
        case .day7Badge:       return "medal.fill"
        case .day14BonusAudio: return "music.note"
        case .day21Mastery:    return "crown.fill"
        }
    }
}

// MARK: - JourneyCategory

struct JourneyCategory: Identifiable {
    let id: String
    let name: String
    let emoji: String

    static let all: [JourneyCategory] = [
        JourneyCategory(id: "faith",         name: "Faith & Trust",         emoji: "🙏"),
        JourneyCategory(id: "healing",        name: "Healing",               emoji: "💚"),
        JourneyCategory(id: "purpose",        name: "Purpose & Identity",    emoji: "✨"),
        JourneyCategory(id: "anxiety",        name: "Peace & Anxiety",       emoji: "🕊️"),
        JourneyCategory(id: "relationships",  name: "Relationships",          emoji: "❤️"),
        JourneyCategory(id: "abundance",      name: "Abundance & Provision",  emoji: "🌟"),
        JourneyCategory(id: "wisdom",         name: "Wisdom & Guidance",     emoji: "💡"),
        JourneyCategory(id: "strength",       name: "Strength & Courage",    emoji: "🦁"),
    ]

    var displayName: String { "\(emoji) \(name)" }
}
