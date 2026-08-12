//
//  BadgeModel.swift
//  SpeakLifeServices
//
//  Foundation-only badge core: the Badge value type, the type/rarity/
//  requirement enums (with iconName strings but no Color), the manager
//  that owns unlocked badges, and the streak-stats extensions the
//  manager consults.
//
//  The SwiftUI Color extensions on `BadgeType` / `BadgeRarity` live in
//  `SpeakLife/Models/BadgeAppearance.swift`. Same pattern as
//  `ChecklistModelsAppearance.swift` and `ProgressionPhase+Appearance.swift`.
//

import Foundation
import Combine
import SpeakLifeCore

// MARK: - Badge System Models

public struct Badge: Identifiable, Codable, Equatable {
    public let id = UUID()
    public let type: BadgeType
    public let rarity: BadgeRarity
    public let title: String
    public let description: String
    public let requirement: AchievementRequirement
    public let unlockedAt: Date?
    public let isUnlocked: Bool

    public init(type: BadgeType,
                rarity: BadgeRarity,
                title: String,
                description: String,
                requirement: AchievementRequirement,
                unlockedAt: Date?,
                isUnlocked: Bool) {
        self.type = type
        self.rarity = rarity
        self.title = title
        self.description = description
        self.requirement = requirement
        self.unlockedAt = unlockedAt
        self.isUnlocked = isUnlocked
    }

    public var sortOrder: Int {
        requirement.sortOrder
    }

    public var displayTitle: String {
        isUnlocked ? title : "???"
    }

    public var displayDescription: String {
        isUnlocked ? description : "Keep going to unlock this badge!"
    }
}

public enum BadgeType: String, CaseIterable, Codable {
    case streak = "streak"
    case consistency = "consistency"
    case spiritual = "spiritual"
    case social = "social"
    case milestone = "milestone"
    case enforcement = "enforcement"

    public var iconName: String {
        switch self {
        case .streak: return "flame.fill"
        case .consistency: return "calendar.badge.checkmark"
        case .spiritual: return "heart.fill"
        case .social: return "person.3.fill"
        case .milestone: return "crown.fill"
        case .enforcement: return "shield.fill"
        }
    }
}

public enum BadgeRarity: String, CaseIterable, Codable {
    case common = "common"
    case rare = "rare"
    case epic = "epic"
    case legendary = "legendary"

    public var displayName: String {
        rawValue.capitalized
    }

    public var glowIntensity: Double {
        switch self {
        case .common: return 0.3
        case .rare: return 0.5
        case .epic: return 0.7
        case .legendary: return 1.0
        }
    }

    public var particleCount: Int {
        switch self {
        case .common: return 8
        case .rare: return 12
        case .epic: return 16
        case .legendary: return 24
        }
    }
}

public enum AchievementRequirement: Codable, Equatable {
    case streakDays(Int)
    case totalDaysCompleted(Int)
    case consecutiveWeeks(Int)
    case perfectWeek
    case firstDay
    /// A finished seven-day Enforcement, keyed by `Enforcement.id`.
    case enforcementCompleted(String)

    public var sortOrder: Int {
        switch self {
        case .firstDay: return 1
        case .streakDays(let days): return 100 + days
        case .totalDaysCompleted(let days): return 1000 + days
        case .consecutiveWeeks(let weeks): return 2000 + weeks
        case .perfectWeek: return 2100
        case .enforcementCompleted: return 3000
        }
    }

    public var description: String {
        switch self {
        case .streakDays(let days):
            return "Complete \(days) consecutive days"
        case .totalDaysCompleted(let days):
            return "Complete \(days) total days"
        case .consecutiveWeeks(let weeks):
            return "Complete \(weeks) perfect weeks"
        case .perfectWeek:
            return "Complete all tasks for 7 days straight"
        case .firstDay:
            return "Complete your first day"
        case .enforcementCompleted:
            return "Finish a seven-day stand"
        }
    }
}

// MARK: - Badge Achievement Manager

public final class BadgeManager: ObservableObject {
    @Published public var unlockedBadges: [Badge] = []
    @Published public var allBadges: [Badge] = []
    @Published public var recentlyUnlocked: Badge?

    private let userDefaults = UserDefaults.standard
    private let badgeKey = "UnlockedBadges"

    public init() {
        loadBadges()
        initializeAllBadges()
    }

    // MARK: - Badge Definitions

    private func initializeAllBadges() {
        // Only include badges for metrics we can actually track
        allBadges = [
            // First Steps
            Badge(
                type: .milestone,
                rarity: .common,
                title: "First Steps",
                description: "Welcome to your spiritual journey! You've taken the first step towards speaking life.",
                requirement: .firstDay,
                unlockedAt: getBadgeUnlockDate(.firstDay),
                isUnlocked: isBadgeUnlocked(.firstDay)
            ),

            // Streak Badges - PRIMARY TRACKABLE METRIC
            Badge(
                type: .streak,
                rarity: .common,
                title: "Faith Builder",
                description: "Seven days of speaking life! You're building a foundation of faith.",
                requirement: .streakDays(7),
                unlockedAt: getBadgeUnlockDate(.streakDays(7)),
                isUnlocked: isBadgeUnlocked(.streakDays(7))
            ),

            Badge(
                type: .streak,
                rarity: .rare,
                title: "Word Warrior",
                description: "Two weeks strong! You're becoming a warrior with your words.",
                requirement: .streakDays(14),
                unlockedAt: getBadgeUnlockDate(.streakDays(14)),
                isUnlocked: isBadgeUnlocked(.streakDays(14))
            ),

            Badge(
                type: .streak,
                rarity: .epic,
                title: "Faith Overcomer",
                description: "30 days of victory! You've overcome doubt and built unshakeable faith.",
                requirement: .streakDays(30),
                unlockedAt: getBadgeUnlockDate(.streakDays(30)),
                isUnlocked: isBadgeUnlocked(.streakDays(30))
            ),

            Badge(
                type: .streak,
                rarity: .epic,
                title: "Kingdom Heir",
                description: "50 days of declaring your identity! You truly know who you are in Christ.",
                requirement: .streakDays(50),
                unlockedAt: getBadgeUnlockDate(.streakDays(50)),
                isUnlocked: isBadgeUnlocked(.streakDays(50))
            ),

            Badge(
                type: .streak,
                rarity: .legendary,
                title: "Covenant Keeper",
                description: "100 days of faithfulness! You've proven your commitment to the covenant.",
                requirement: .streakDays(100),
                unlockedAt: getBadgeUnlockDate(.streakDays(100)),
                isUnlocked: isBadgeUnlocked(.streakDays(100))
            ),

            Badge(
                type: .streak,
                rarity: .legendary,
                title: "Spiritual Giant",
                description: "200 days of unwavering faith! You stand as a giant in the spirit realm.",
                requirement: .streakDays(200),
                unlockedAt: getBadgeUnlockDate(.streakDays(200)),
                isUnlocked: isBadgeUnlocked(.streakDays(200))
            ),

            Badge(
                type: .milestone,
                rarity: .legendary,
                title: "Destiny Carrier",
                description: "365 days of speaking life! You carry the full weight of your destiny.",
                requirement: .streakDays(365),
                unlockedAt: getBadgeUnlockDate(.streakDays(365)),
                isUnlocked: isBadgeUnlocked(.streakDays(365))
            ),

            // Total Days Completed - TRACKABLE METRIC
            Badge(
                type: .consistency,
                rarity: .rare,
                title: "Dedicated Disciple",
                description: "25 total days completed! Your dedication is inspiring.",
                requirement: .totalDaysCompleted(25),
                unlockedAt: getBadgeUnlockDate(.totalDaysCompleted(25)),
                isUnlocked: isBadgeUnlocked(.totalDaysCompleted(25))
            ),

            Badge(
                type: .consistency,
                rarity: .epic,
                title: "Faithful Steward",
                description: "75 total days completed! You're a faithful steward of your spiritual growth.",
                requirement: .totalDaysCompleted(75),
                unlockedAt: getBadgeUnlockDate(.totalDaysCompleted(75)),
                isUnlocked: isBadgeUnlocked(.totalDaysCompleted(75))
            ),

            Badge(
                type: .consistency,
                rarity: .legendary,
                title: "Unstoppable Force",
                description: "150 total days completed! You're an unstoppable force for the Kingdom!",
                requirement: .totalDaysCompleted(150),
                unlockedAt: getBadgeUnlockDate(.totalDaysCompleted(150)),
                isUnlocked: isBadgeUnlocked(.totalDaysCompleted(150))
            ),

            // Week Consistency - TRACKABLE METRIC
            Badge(
                type: .consistency,
                rarity: .rare,
                title: "Perfect Week",
                description: "Seven perfect days in a row! Your consistency is building character.",
                requirement: .perfectWeek,
                unlockedAt: getBadgeUnlockDate(.perfectWeek),
                isUnlocked: isBadgeUnlocked(.perfectWeek)
            ),

            Badge(
                type: .consistency,
                rarity: .epic,
                title: "Week Warrior",
                description: "Four perfect weeks! You're mastering the rhythm of spiritual discipline.",
                requirement: .consecutiveWeeks(4),
                unlockedAt: getBadgeUnlockDate(.consecutiveWeeks(4)),
                isUnlocked: isBadgeUnlocked(.consecutiveWeeks(4))
            ),

            // Enforcement badges — one per campaign. Ids match `enforcements.json`.
            Badge(
                type: .enforcement,
                rarity: .rare,
                title: "Peace Holder",
                description: "Seven days enforcing a mind that is clear, sound, and at rest.",
                requirement: .enforcementCompleted("peace"),
                unlockedAt: getBadgeUnlockDate(.enforcementCompleted("peace")),
                isUnlocked: isBadgeUnlocked(.enforcementCompleted("peace"))
            ),

            Badge(
                type: .enforcement,
                rarity: .rare,
                title: "Provision Holder",
                description: "Seven days standing as a child of the God who owns everything.",
                requirement: .enforcementCompleted("provision"),
                unlockedAt: getBadgeUnlockDate(.enforcementCompleted("provision")),
                isUnlocked: isBadgeUnlocked(.enforcementCompleted("provision"))
            ),

            Badge(
                type: .enforcement,
                rarity: .rare,
                title: "Healing Holder",
                description: "Seven days enforcing wholeness over your body.",
                requirement: .enforcementCompleted("healing"),
                unlockedAt: getBadgeUnlockDate(.enforcementCompleted("healing")),
                isUnlocked: isBadgeUnlocked(.enforcementCompleted("healing"))
            ),

            Badge(
                type: .enforcement,
                rarity: .epic,
                title: "Ground Holder",
                description: "Seven days enforcing a verdict that was already rendered.",
                requirement: .enforcementCompleted("warfare"),
                unlockedAt: getBadgeUnlockDate(.enforcementCompleted("warfare")),
                isUnlocked: isBadgeUnlocked(.enforcementCompleted("warfare"))
            )

            // Removed social shares, favorites, categories, etc. until we can properly track them
        ]

        // Sort badges by their requirements
        allBadges.sort { $0.sortOrder < $1.sortOrder }
    }

    // MARK: - Badge State Management

    private func isBadgeUnlocked(_ requirement: AchievementRequirement) -> Bool {
        unlockedBadges.contains { $0.requirement == requirement }
    }

    private func getBadgeUnlockDate(_ requirement: AchievementRequirement) -> Date? {
        unlockedBadges.first { $0.requirement == requirement }?.unlockedAt
    }

    // MARK: - Badge Unlocking Logic

    /// - Parameter completedEnforcementIds: `EnforcementProgress.completedEnforcementIds`. Defaults
    ///   empty so existing callers are unaffected.
    public func checkForNewBadges(streakStats: StreakStats, userStats: UserStats,
                                  completedEnforcementIds: [String] = []) {
        let potentialBadges = allBadges.filter { !$0.isUnlocked }
        let badgeStats = streakStats.toBadgeStreakStats()

        for badge in potentialBadges {
            if shouldUnlockBadge(badge.requirement, streakStats: badgeStats, userStats: userStats,
                                 completedEnforcementIds: completedEnforcementIds) {
                unlockBadge(badge)
            }
        }
    }

    private func shouldUnlockBadge(_ requirement: AchievementRequirement, streakStats: Badge.StreakStatsForBadges, userStats: UserStats,
                                   completedEnforcementIds: [String] = []) -> Bool {
        switch requirement {
        case .enforcementCompleted(let enforcementId):
            return completedEnforcementIds.contains(enforcementId)
        case .firstDay:
            return streakStats.totalDaysCompleted >= 1
        case .streakDays(let days):
            return streakStats.currentStreak >= days
        case .totalDaysCompleted(let days):
            return streakStats.totalDaysCompleted >= days
        case .consecutiveWeeks(let weeks):
            return streakStats.consecutiveWeeks >= weeks
        case .perfectWeek:
            return streakStats.hasPerfectWeek
        }
    }

    private func unlockBadge(_ badge: Badge) {
        // Guard against double-unlock: check unlockedBadges directly (source of truth in UserDefaults)
        // allBadges.isUnlocked can be stale if data failed to decode on launch
        guard !unlockedBadges.contains(where: { $0.requirement == badge.requirement }) else { return }

        let unlockedBadge = Badge(
            type: badge.type,
            rarity: badge.rarity,
            title: badge.title,
            description: badge.description,
            requirement: badge.requirement,
            unlockedAt: Date(),
            isUnlocked: true
        )

        unlockedBadges.append(unlockedBadge)
        recentlyUnlocked = unlockedBadge
        saveBadges()

        // Update the all badges array
        if let index = allBadges.firstIndex(where: { $0.requirement == badge.requirement }) {
            allBadges[index] = unlockedBadge
        }

    }

    // MARK: - Persistence

    private func saveBadges() {
        if let encoded = try? JSONEncoder().encode(unlockedBadges) {
            userDefaults.set(encoded, forKey: badgeKey)
        }
    }

    private func loadBadges() {
        if let data = userDefaults.data(forKey: badgeKey),
           let decoded = try? JSONDecoder().decode([Badge].self, from: data) {
            unlockedBadges = decoded
        }
    }

    // MARK: - Public Interface

    public var unlockedBadgeCount: Int {
        unlockedBadges.count
    }

    public var totalBadgeCount: Int {
        allBadges.count
    }

    public var completionPercentage: Double {
        guard totalBadgeCount > 0 else { return 0 }
        return Double(unlockedBadgeCount) / Double(totalBadgeCount)
    }

    public func getNextBadgeToUnlock() -> Badge? {
        allBadges.first { !$0.isUnlocked }
    }

    public func getBadgesByType(_ type: BadgeType) -> [Badge] {
        allBadges.filter { $0.type == type }
    }

    public func getBadgesByRarity(_ rarity: BadgeRarity) -> [Badge] {
        allBadges.filter { $0.rarity == rarity }
    }

    public func clearRecentlyUnlocked() {
        recentlyUnlocked = nil
    }
}

// MARK: - Supporting Models

public struct UserStats {
    public let affirmationsSpoken: Int
    public let versesRead: Int
    public let socialShares: Int
    public let favoritesAdded: Int
    public let categoriesCompleted: Set<String>

    public init(affirmationsSpoken: Int,
                versesRead: Int,
                socialShares: Int,
                favoritesAdded: Int,
                categoriesCompleted: Set<String>) {
        self.affirmationsSpoken = affirmationsSpoken
        self.versesRead = versesRead
        self.socialShares = socialShares
        self.favoritesAdded = favoritesAdded
        self.categoriesCompleted = categoriesCompleted
    }
}

// MARK: - StreakStats Extensions for Badge System

extension StreakStats {
    public var consecutiveWeeks: Int {
        // Calculate consecutive weeks based on current streak
        return currentStreak / 7
    }

    public var hasPerfectWeek: Bool {
        // Check if user has completed at least one full week
        return currentStreak >= 7
    }

    // Convert to badge-compatible format
    public func toBadgeStreakStats() -> Badge.StreakStatsForBadges {
        return Badge.StreakStatsForBadges(
            currentStreak: currentStreak,
            longestStreak: longestStreak,
            totalDaysCompleted: totalDaysCompleted,
            consecutiveWeeks: consecutiveWeeks,
            hasPerfectWeek: hasPerfectWeek
        )
    }
}

extension Badge {
    public struct StreakStatsForBadges {
        public let currentStreak: Int
        public let longestStreak: Int
        public let totalDaysCompleted: Int
        public let consecutiveWeeks: Int
        public let hasPerfectWeek: Bool

        public init(currentStreak: Int, longestStreak: Int, totalDaysCompleted: Int, consecutiveWeeks: Int, hasPerfectWeek: Bool) {
            self.currentStreak = currentStreak
            self.longestStreak = longestStreak
            self.totalDaysCompleted = totalDaysCompleted
            self.consecutiveWeeks = consecutiveWeeks
            self.hasPerfectWeek = hasPerfectWeek
        }
    }
}
