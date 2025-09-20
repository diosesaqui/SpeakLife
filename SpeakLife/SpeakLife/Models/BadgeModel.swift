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
    
    var iconName: String {
        switch self {
        case .streak: return "flame.fill"
        case .consistency: return "calendar.badge.checkmark"
        case .spiritual: return "heart.fill"
        case .social: return "person.3.fill"
        case .milestone: return "crown.fill"
        }
    }
    
    var primaryColor: Color {
        switch self {
        case .streak: return .orange
        case .consistency: return .blue
        case .spiritual: return .purple
        case .social: return .green
        case .milestone: return .yellow
        }
    }
    
    var secondaryColor: Color {
        switch self {
        case .streak: return .red
        case .consistency: return .cyan
        case .spiritual: return .pink
        case .social: return .mint
        case .milestone: return .orange
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
    
    var ringColor: Color {
        switch self {
        case .common: return Color(red: 0.7, green: 0.5, blue: 0.3) // Bronze
        case .rare: return Color(red: 0.75, green: 0.75, blue: 0.75) // Silver
        case .epic: return Color(red: 1.0, green: 0.84, blue: 0.0) // Gold
        case .legendary: return Color(red: 0.9, green: 0.4, blue: 1.0) // Platinum/Purple
        }
    }
    
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
        }
    }
}

// MARK: - Badge Achievement Manager

class BadgeManager: ObservableObject {
    @Published var unlockedBadges: [Badge] = []
    @Published var allBadges: [Badge] = []
    @Published var recentlyUnlocked: Badge?
    
    private let userDefaults = UserDefaults.standard
    private let badgeKey = "UnlockedBadges"
    
    init() {
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
    
    func checkForNewBadges(streakStats: StreakStats, userStats: UserStats) {
        let potentialBadges = allBadges.filter { !$0.isUnlocked }
        let badgeStats = streakStats.toBadgeStreakStats()
        
        for badge in potentialBadges {
            if shouldUnlockBadge(badge.requirement, streakStats: badgeStats, userStats: userStats) {
                unlockBadge(badge)
            }
        }
    }
    
    private func shouldUnlockBadge(_ requirement: AchievementRequirement, streakStats: Badge.StreakStatsForBadges, userStats: UserStats) -> Bool {
        switch requirement {
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
        
        print("🏆 Badge Unlocked: \(badge.title)")
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