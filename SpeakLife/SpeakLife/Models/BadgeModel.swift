//
//  Badge.swift
//  SpeakLife
//
//  Apple award-winning badge system for milestone achievements
//

import SwiftUI
import Foundation

// MARK: - Badge System Models

struct Badge: Identifiable, Codable, Equatable {
    let id = UUID()
    let type: BadgeType
    let rarity: BadgeRarity
    let title: String
    let description: String
    let requirement: AchievementRequirement
    let unlockedAt: Date?
    let isUnlocked: Bool
    
    var sortOrder: Int {
        requirement.sortOrder
    }
    
    var displayTitle: String {
        isUnlocked ? title : "???"
    }
    
    var displayDescription: String {
        isUnlocked ? description : "Keep going to unlock this badge!"
    }
}

enum BadgeType: String, CaseIterable, Codable {
    case streak = "streak"
    case consistency = "consistency"
    case spiritual = "spiritual"
    case social = "social"
    case milestone = "milestone"
    case enforcement = "enforcement"
    /// Guarding — thoughts taken captive. Its own type rather than folded into
    /// `.enforcement`: a seven-day stand and a thought caught at the gate are
    /// different work, and a shared icon would make the collection read as one
    /// feature earning twice.
    case guarding = "guarding"

    var iconName: String {
        switch self {
        case .streak: return "flame.fill"
        case .consistency: return "calendar.badge.checkmark"
        case .spiritual: return "heart.fill"
        case .social: return "person.3.fill"
        case .milestone: return "crown.fill"
        case .enforcement: return "shield.fill"
        // The mind is the domain this one is won in.
        case .guarding: return "brain.head.profile"
        }
    }
    
    var primaryColor: Color {
        switch self {
        case .streak: return .orange
        case .consistency: return .blue
        case .spiritual: return .purple
        case .social: return .green
        case .milestone: return .yellow
        case .enforcement: return .indigo
        case .guarding: return .teal
        }
    }
    
    var secondaryColor: Color {
        switch self {
        case .streak: return .red
        case .consistency: return .cyan
        case .spiritual: return .pink
        case .social: return .mint
        case .milestone: return .orange
        case .enforcement: return .purple
        case .guarding: return .cyan
        }
    }
}

enum BadgeRarity: String, CaseIterable, Codable {
    case common = "common"
    case rare = "rare"
    case epic = "epic"
    case legendary = "legendary"
    
    var displayName: String {
        rawValue.capitalized
    }

    /// Refined metallic palette per tier: [highlight, base, shadow].
    /// One restrained metal per rarity — no per-type rainbow — so badges read
    /// as minted medals rather than candy. Drives the rim and emblem gradients.
    var metalGradient: [Color] {
        switch self {
        case .common: // Bronze
            return [
                Color(red: 0.85, green: 0.62, blue: 0.40),
                Color(red: 0.60, green: 0.40, blue: 0.24),
                Color(red: 0.36, green: 0.23, blue: 0.13)
            ]
        case .rare: // Silver
            return [
                Color(red: 0.96, green: 0.97, blue: 0.99),
                Color(red: 0.72, green: 0.75, blue: 0.80),
                Color(red: 0.42, green: 0.45, blue: 0.50)
            ]
        case .epic: // Gold
            return [
                Color(red: 1.00, green: 0.90, blue: 0.56),
                Color(red: 0.92, green: 0.72, blue: 0.27),
                Color(red: 0.56, green: 0.40, blue: 0.09)
            ]
        case .legendary: // Platinum / iridescent
            return [
                Color(red: 0.93, green: 0.91, blue: 1.00),
                Color(red: 0.66, green: 0.62, blue: 0.88),
                Color(red: 0.38, green: 0.34, blue: 0.60)
            ]
        }
    }

    var metalHighlight: Color { metalGradient[0] }
    var metalBase: Color { metalGradient[1] }
    var metalShadow: Color { metalGradient[2] }

    /// Single representative tone for text labels and small indicators.
    var ringColor: Color { metalBase }

    var glowIntensity: Double {
        switch self {
        case .common: return 0.3
        case .rare: return 0.5
        case .epic: return 0.7
        case .legendary: return 1.0
        }
    }
    
    var particleCount: Int {
        switch self {
        case .common: return 8
        case .rare: return 12
        case .epic: return 16
        case .legendary: return 24
        }
    }
}

enum AchievementRequirement: Codable, Equatable {
    case streakDays(Int)
    case totalDaysCompleted(Int)
    case consecutiveWeeks(Int)
    case perfectWeek
    case firstDay
    /// A finished seven-day Enforcement, keyed by `Enforcement.id`.
    case enforcementCompleted(String)
    /// Cumulative thoughts taken captive, from `GroundTaken.total`.
    ///
    /// This one meets the "metrics we can actually track" bar below more
    /// squarely than anything else here. The counter is whitelisted in
    /// `ProgressSyncStore.syncedCounterKeys`, which makes it append-only and
    /// cross-device by construction: there is no code path that lowers it and
    /// no calendar that expires it. So a badge earned on it can never be taken
    /// back by a restore, a timezone, or a missed day.
    case thoughtsTakenCaptive(Int)
    // Removed untracked requirements:
    // case affirmationsSpoken(Int)
    // case versesRead(Int)
    // case socialShares(Int)
    // case favoritesAdded(Int)
    // case categoryMaster(String)

    var sortOrder: Int {
        switch self {
        case .firstDay: return 1
        case .streakDays(let days): return 100 + days
        case .totalDaysCompleted(let days): return 1000 + days
        case .consecutiveWeeks(let weeks): return 2000 + weeks
        case .perfectWeek: return 2100
        case .enforcementCompleted: return 3000
        case .thoughtsTakenCaptive(let count): return 4000 + count
        }
    }
    
    var description: String {
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
        case .thoughtsTakenCaptive(let count):
            return count == 1
                ? "Take a thought captive"
                : "Take \(count) thoughts captive"
        }
    }
}

// MARK: - Badge Achievement Manager

class BadgeManager: ObservableObject {
    @Published var unlockedBadges: [Badge] = []
    @Published var allBadges: [Badge] = []
    @Published var recentlyUnlocked: Badge?
    
    private let userDefaults: UserDefaults
    private let badgeKey = "UnlockedBadges"

    /// - Parameter userDefaults: injected so a test can award badges into a
    ///   throwaway suite. Awarding writes through `saveBadges`, so a hardcoded
    ///   `.standard` would leave real unlocked badges behind after a test run
    ///   and make the results depend on the order the tests happened to run in.
    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
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
            ),

            // Guarding — thoughts taken captive. The counter behind these is
            // monotonic and synced, so none of them can un-earn.
            //
            // The copy stays inside Guarding's own rule: it names ground taken,
            // never a lapse. There is nothing here that can be broken, missed,
            // or fallen behind on, because the number these read only ever goes
            // up. See `GroundTakenView` for why that is load-bearing.
            Badge(
                type: .guarding,
                rarity: .common,
                title: "First Ground",
                description: "One thought taken captive. That's ground you don't give back.",
                requirement: .thoughtsTakenCaptive(1),
                unlockedAt: getBadgeUnlockDate(.thoughtsTakenCaptive(1)),
                isUnlocked: isBadgeUnlocked(.thoughtsTakenCaptive(1))
            ),

            Badge(
                type: .guarding,
                rarity: .common,
                title: "Watchman",
                description: "Ten thoughts caught at the gate instead of let through.",
                requirement: .thoughtsTakenCaptive(10),
                unlockedAt: getBadgeUnlockDate(.thoughtsTakenCaptive(10)),
                isUnlocked: isBadgeUnlocked(.thoughtsTakenCaptive(10))
            ),

            Badge(
                type: .guarding,
                rarity: .rare,
                title: "Guarded Mind",
                description: "Fifty thoughts taken captive. The reflex is yours now.",
                requirement: .thoughtsTakenCaptive(50),
                unlockedAt: getBadgeUnlockDate(.thoughtsTakenCaptive(50)),
                isUnlocked: isBadgeUnlocked(.thoughtsTakenCaptive(50))
            ),

            Badge(
                type: .guarding,
                rarity: .epic,
                title: "Stronghold",
                description: "A hundred and fifty thoughts taken captive, every one of them answered with the Word.",
                requirement: .thoughtsTakenCaptive(150),
                unlockedAt: getBadgeUnlockDate(.thoughtsTakenCaptive(150)),
                isUnlocked: isBadgeUnlocked(.thoughtsTakenCaptive(150))
            ),

            Badge(
                type: .guarding,
                rarity: .legendary,
                title: "Every Thought",
                description: "Three hundred and sixty-five thoughts taken captive and made obedient to Christ.",
                requirement: .thoughtsTakenCaptive(365),
                unlockedAt: getBadgeUnlockDate(.thoughtsTakenCaptive(365)),
                isUnlocked: isBadgeUnlocked(.thoughtsTakenCaptive(365))
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
    func checkForNewBadges(streakStats: StreakStats, userStats: UserStats,
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
        case .thoughtsTakenCaptive(let count):
            return userStats.thoughtsTakenCaptive >= count
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
    
    var unlockedBadgeCount: Int {
        unlockedBadges.count
    }
    
    var totalBadgeCount: Int {
        allBadges.count
    }
    
    var completionPercentage: Double {
        guard totalBadgeCount > 0 else { return 0 }
        return Double(unlockedBadgeCount) / Double(totalBadgeCount)
    }
    
    func getNextBadgeToUnlock() -> Badge? {
        allBadges.first { !$0.isUnlocked }
    }
    
    func getBadgesByType(_ type: BadgeType) -> [Badge] {
        allBadges.filter { $0.type == type }
    }
    
    func getBadgesByRarity(_ rarity: BadgeRarity) -> [Badge] {
        allBadges.filter { $0.rarity == rarity }
    }
    
    func clearRecentlyUnlocked() {
        recentlyUnlocked = nil
    }
}

// MARK: - Supporting Models

struct UserStats {
    let affirmationsSpoken: Int
    let versesRead: Int
    let socialShares: Int
    let favoritesAdded: Int
    let categoriesCompleted: Set<String>
    /// Cumulative ground taken, from `GroundTaken.total`.
    ///
    /// Defaulted so a caller that has no reason to care about Guarding is not
    /// forced to reach into `UserDefaults` for it. `checkForNewBadges` passes
    /// the real number; anything that leaves it out simply earns no Guarding
    /// badge, which is the safe direction — a badge is never wrongly awarded by
    /// an incomplete stats object.
    var thoughtsTakenCaptive: Int = 0
}

// MARK: - StreakStats Extensions for Badge System

extension StreakStats {
    var consecutiveWeeks: Int {
        // Calculate consecutive weeks based on current streak
        return currentStreak / 7
    }
    
    var hasPerfectWeek: Bool {
        // Check if user has completed at least one full week
        return currentStreak >= 7
    }
    
    // Convert to badge-compatible format
    func toBadgeStreakStats() -> Badge.StreakStatsForBadges {
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
    struct StreakStatsForBadges {
        let currentStreak: Int
        let longestStreak: Int
        let totalDaysCompleted: Int
        let consecutiveWeeks: Int
        let hasPerfectWeek: Bool
    }
}