//
//  DailyChecklistModels.swift
//  SpeakLife
//
//  Progressive daily checklist models for enhanced streak feature
//  

import Foundation
import SwiftUI

// MARK: - Task Categories & Types
enum TaskCategory: String, CaseIterable, Codable {
    case foundation = "foundation"     // Core spiritual practices
    case growth = "growth"            // Personal development
    case impact = "impact"            // Community engagement
    case mastery = "mastery"          // Advanced practices
    
    var displayName: String {
        switch self {
        case .foundation: return "Foundation"
        case .growth: return "Growth"
        case .impact: return "Impact"
        case .mastery: return "Mastery"
        }
    }
    
    var color: Color {
        switch self {
        case .foundation: return .blue
        case .growth: return .green
        case .impact: return .orange
        case .mastery: return .purple
        }
    }
    
    var emoji: String {
        switch self {
        case .foundation: return "🌱"
        case .growth: return "🌿"
        case .impact: return "🌟"
        case .mastery: return "👑"
        }
    }
}

enum TaskType: String, CaseIterable, Codable {
    case speak = "speak"
    case listen = "listen"
    case read = "read"
    case share = "share"
    case reflect = "reflect"
    case memorize = "memorize"
    case worship = "worship"
    case serve = "serve"
    case study = "study"
    case teach = "teach"
}

enum DifficultyLevel: Int, CaseIterable, Codable {
    case beginner = 1
    case intermediate = 2
    case advanced = 3
    case expert = 4
    
    var displayName: String {
        switch self {
        case .beginner: return "Beginner"
        case .intermediate: return "Intermediate"
        case .advanced: return "Advanced"
        case .expert: return "Expert"
        }
    }
}

// MARK: - Enhanced Daily Task Model
struct DailyTask: Identifiable, Codable {
    let id: String
    let title: String
    let description: String
    let icon: String
    let category: TaskCategory
    let type: TaskType
    let difficulty: DifficultyLevel
    let minimumStreakDay: Int
    let estimatedMinutes: Int
    var isCompleted: Bool = false
    var completedAt: Date?
    var isNewlyUnlocked: Bool = false
    
    init(id: String, title: String, description: String, icon: String, 
         category: TaskCategory, type: TaskType, difficulty: DifficultyLevel = .beginner,
         minimumStreakDay: Int = 1, estimatedMinutes: Int = 5,
         isCompleted: Bool = false, completedAt: Date? = nil) {
        self.id = id
        self.title = title
        self.description = description
        self.icon = icon
        self.category = category
        self.type = type
        self.difficulty = difficulty
        self.minimumStreakDay = minimumStreakDay
        self.estimatedMinutes = estimatedMinutes
        self.isCompleted = isCompleted
        self.completedAt = completedAt
    }
}

// MARK: - Daily Checklist Model
struct DailyChecklist: Codable {
    let date: Date
    var tasks: [DailyTask]
    var completedAt: Date?
    var currentPhase: ProgressionPhase
    var newTasksUnlocked: [String] = []
    
    var isCompleted: Bool {
        tasks.allSatisfy { $0.isCompleted }
    }
    
    var completionProgress: Double {
        let completedCount = tasks.filter { $0.isCompleted }.count
        return Double(completedCount) / Double(tasks.count)
    }
    
    var completedTasksCount: Int {
        tasks.filter { $0.isCompleted }.count
    }
    
    var estimatedTotalMinutes: Int {
        tasks.reduce(0) { $0 + $1.estimatedMinutes }
    }
}

// MARK: - Progression System
enum ProgressionPhase: String, CaseIterable, Codable {
    case foundation = "foundation"     // Days 1-7
    case growth = "growth"            // Days 8-30
    case impact = "impact"            // Days 31-100
    case mastery = "mastery"          // Days 100+
    
    var displayName: String {
        switch self {
        case .foundation: return "Building Foundation"
        case .growth: return "Growing Deeper"
        case .impact: return "Making Impact"
        case .mastery: return "Spiritual Mastery"
        }
    }
    
    var description: String {
        switch self {
        case .foundation: return "Establishing core spiritual habits"
        case .growth: return "Expanding your spiritual practices"
        case .impact: return "Reaching out and serving others"
        case .mastery: return "Advanced spiritual disciplines"
        }
    }
    
    var minStreakDay: Int {
        switch self {
        case .foundation: return 1
        case .growth: return 8
        case .impact: return 31
        case .mastery: return 100
        }
    }
    
    var maxStreakDay: Int {
        switch self {
        case .foundation: return 7
        case .growth: return 30
        case .impact: return 99
        case .mastery: return Int.max
        }
    }
    
    var color: Color {
        switch self {
        case .foundation: return .blue
        case .growth: return .green
        case .impact: return .orange
        case .mastery: return .purple
        }
    }
    
    var emoji: String {
        switch self {
        case .foundation: return "🌱"
        case .growth: return "🌿"
        case .impact: return "🌟"
        case .mastery: return "👑"
        }
    }
    
    static func getPhase(for streakDay: Int) -> ProgressionPhase {
        if streakDay >= 100 { return .mastery }
        if streakDay >= 31 { return .impact }
        if streakDay >= 8 { return .growth }
        return .foundation
    }
}

// MARK: - Streak Statistics
struct StreakStats: Codable {
    var currentStreak: Int = 0
    var longestStreak: Int = 0
    var totalDaysCompleted: Int = 0
    var lastCompletedDate: Date?
    
    mutating func updateStreak(for date: Date) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: date)
        
        print("🔥 STREAK DEBUG: Updating streak for date: \(today)")
        print("🔥 STREAK DEBUG: Current streak before update: \(currentStreak)")
        print("🔥 STREAK DEBUG: Last completed date: \(lastCompletedDate?.description ?? "None")")
        
        if let lastDate = lastCompletedDate {
            let lastDateStart = calendar.startOfDay(for: lastDate)
            let daysDifference = calendar.dateComponents([.day], from: lastDateStart, to: today).day ?? 0
            print("🔥 STREAK DEBUG: Days difference: \(daysDifference)")
            print("🔥 STREAK DEBUG: Last date (start of day): \(lastDateStart)")
            print("🔥 STREAK DEBUG: Today (start of day): \(today)")
            
            if daysDifference == 1 {
                // Consecutive day
                currentStreak += 1
                print("🔥 STREAK DEBUG: Consecutive day! New streak: \(currentStreak)")
            } else if daysDifference > 1 {
                // Streak broken
                currentStreak = 1
                print("🔥 STREAK DEBUG: Streak broken! Reset to: \(currentStreak)")
            } else if daysDifference == 0 {
                // Same day - don't increment streak or totals (already counted)
                print("🔥 STREAK DEBUG: Same day, no updates. Streak remains: \(currentStreak)")
                // Early return to avoid double-counting total days
                return
            } else {
                // daysDifference < 0 - completion in the past relative to last completion
                // This shouldn't normally happen, but handle it gracefully
                print("🔥 STREAK DEBUG: Date is before last completion. Streak remains: \(currentStreak)")
            }
        } else {
            // First completion
            currentStreak = 1
            print("🔥 STREAK DEBUG: First completion! Streak set to: \(currentStreak)")
        }
        
        longestStreak = max(longestStreak, currentStreak)
        totalDaysCompleted += 1
        lastCompletedDate = today
        
        print("🔥 STREAK DEBUG: Final streak: \(currentStreak), longest: \(longestStreak), total days: \(totalDaysCompleted)")
    }
    
    mutating func checkStreakValidity() {
        guard let lastDate = lastCompletedDate else {
            currentStreak = 0
            return
        }
        
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let daysDifference = calendar.dateComponents([.day], from: lastDate, to: today).day ?? 0
        
        if daysDifference > 1 {
            currentStreak = 0
        }
    }
}

// MARK: - Completion Celebration Data
struct CompletionCelebration {
    let streakNumber: Int
    let isNewRecord: Bool
    let motivationalMessage: String
    let shareImage: UIImage?
    
    static func generateMessage(for streak: Int, isRecord: Bool) -> String {
        if isRecord {
            return "🏆 NEW RECORD! \(streak) days of speaking LIFE! You're unstoppable!"
        }
        
        switch streak {
        case 1:
            return "🔥 Day 1 Complete! You've started something POWERFUL!"
        case 7:
            return "🔥 ONE WEEK STRONG! Your persistence is moving mountains!"
        case 30:
            return "🔥 30 DAYS! You're transformed by the renewing of your mind!"
        case 100:
            return "🔥 100 DAYS! You're a WARRIOR of faith and declaration!"
        default:
            return "🔥 \(streak) DAYS! Keep speaking life—heaven is listening!"
        }
    }
}

// MARK: - Progressive Task Library
struct TaskLibrary {
    
    // MARK: - Foundation Phase Tasks (Days 1-7)
    static let foundationTasks: [DailyTask] = [
        DailyTask(
            id: "speak_affirmation",
            title: "Speak a Favorited Affirmation",
            description: "Declare one of your saved affirmations out loud",
            icon: "speaker.wave.3.fill",
            category: .foundation,
            type: .speak,
            difficulty: .beginner,
            minimumStreakDay: 1,
            estimatedMinutes: 2
        ),
        DailyTask(
            id: "read_devotional",
            title: "Read Daily Devotional",
            description: "Spend time in God's Word and truth",
            icon: "book.fill",
            category: .foundation,
            type: .read,
            difficulty: .beginner,
            minimumStreakDay: 1,
            estimatedMinutes: 5
        ),
        DailyTask(
            id: "listen_audio",
            title: "Listen to Audio Affirmation",
            description: "Faith comes by hearing God's Word",
            icon: "headphones",
            category: .foundation,
            type: .listen,
            difficulty: .beginner,
            minimumStreakDay: 1,
            estimatedMinutes: 4
        ),
        DailyTask(
            id: "gratitude_moment",
            title: "Express Gratitude",
            description: "Thank God for one specific blessing today",
            icon: "heart.fill",
            category: .foundation,
            type: .reflect,
            difficulty: .beginner,
            minimumStreakDay: 2,
            estimatedMinutes: 2
        )
    ]
    
    // MARK: - Growth Phase Tasks (Days 8-30)
    static let growthTasks: [DailyTask] = [
        DailyTask(
            id: "journal_insight",
            title: "Journal One Insight",
            description: "Write down one thing God showed you today",
            icon: "pencil.and.scribble",
            category: .growth,
            type: .reflect,
            difficulty: .intermediate,
            minimumStreakDay: 8,
            estimatedMinutes: 5
        ),
        DailyTask(
            id: "memorize_verse",
            title: "Memorize Scripture",
            description: "Learn or review a Bible verse",
            icon: "brain.head.profile",
            category: .growth,
            type: .memorize,
            difficulty: .intermediate,
            minimumStreakDay: 10,
            estimatedMinutes: 8
        ),
        DailyTask(
            id: "worship_song",
            title: "Worship Through Music",
            description: "Listen to or sing a worship song",
            icon: "music.note",
            category: .growth,
            type: .worship,
            difficulty: .beginner,
            minimumStreakDay: 12,
            estimatedMinutes: 6
        ),
        DailyTask(
            id: "study_deeper",
            title: "Deeper Bible Study",
            description: "Study a passage using cross-references",
            icon: "magnifyingglass",
            category: .growth,
            type: .study,
            difficulty: .intermediate,
            minimumStreakDay: 15,
            estimatedMinutes: 12
        ),
        DailyTask(
            id: "prayer_walk",
            title: "Prayer Walk",
            description: "Pray while walking, connecting body and spirit",
            icon: "figure.walk",
            category: .growth,
            type: .worship,
            difficulty: .intermediate,
            minimumStreakDay: 20,
            estimatedMinutes: 10
        )
    ]
    
    // MARK: - Impact Phase Tasks (Days 31-100)
    static let impactTasks: [DailyTask] = [
        DailyTask(
            id: "share_affirmation",
            title: "Share an Affirmation",
            description: "Share God's truth with someone today",
            icon: "square.and.arrow.up.fill",
            category: .impact,
            type: .share,
            difficulty: .intermediate,
            minimumStreakDay: 31,
            estimatedMinutes: 5
        ),
        DailyTask(
            id: "encourage_someone",
            title: "Encourage Someone",
            description: "Send an encouraging message to someone",
            icon: "message.fill",
            category: .impact,
            type: .serve,
            difficulty: .intermediate,
            minimumStreakDay: 35,
            estimatedMinutes: 7
        ),
        DailyTask(
            id: "pray_for_others",
            title: "Pray for Others",
            description: "Intercede for family, friends, or community",
            icon: "hands.and.sparkles.fill",
            category: .impact,
            type: .worship,
            difficulty: .intermediate,
            minimumStreakDay: 40,
            estimatedMinutes: 8
        ),
        DailyTask(
            id: "serve_someone",
            title: "Act of Service",
            description: "Do something kind for someone without expecting return",
            icon: "hands.clap.fill",
            category: .impact,
            type: .serve,
            difficulty: .advanced,
            minimumStreakDay: 50,
            estimatedMinutes: 15
        ),
        DailyTask(
            id: "testimony_share",
            title: "Share Your Testimony",
            description: "Tell someone how God has worked in your life",
            icon: "megaphone.fill",
            category: .impact,
            type: .share,
            difficulty: .advanced,
            minimumStreakDay: 60,
            estimatedMinutes: 10
        )
    ]
    
    // MARK: - Mastery Phase Tasks (Days 100+)
    static let masteryTasks: [DailyTask] = [
        DailyTask(
            id: "mentor_someone",
            title: "Mentor Someone",
            description: "Guide someone younger in faith",
            icon: "person.2.fill",
            category: .mastery,
            type: .teach,
            difficulty: .expert,
            minimumStreakDay: 100,
            estimatedMinutes: 20
        ),
        DailyTask(
            id: "fast_and_pray",
            title: "Fast and Pray",
            description: "Skip a meal and spend time in prayer",
            icon: "leaf.fill",
            category: .mastery,
            type: .worship,
            difficulty: .expert,
            minimumStreakDay: 120,
            estimatedMinutes: 30
        ),
        DailyTask(
            id: "teach_truth",
            title: "Teach God's Truth",
            description: "Teach or explain biblical truth to others",
            icon: "person.crop.circle.fill.badge.plus",
            category: .mastery,
            type: .teach,
            difficulty: .expert,
            minimumStreakDay: 150,
            estimatedMinutes: 25
        ),
        DailyTask(
            id: "create_content",
            title: "Create Spiritual Content",
            description: "Write, record, or create content that encourages others",
            icon: "video.fill",
            category: .mastery,
            type: .share,
            difficulty: .expert,
            minimumStreakDay: 200,
            estimatedMinutes: 30
        )
    ]
    
    // MARK: - All Tasks Combined
    static let allTasks: [DailyTask] = foundationTasks + growthTasks + impactTasks + masteryTasks
    
    // MARK: - Task Selection Logic
    static func getAvailableTasks(for streakDay: Int) -> [DailyTask] {
        return allTasks.filter { $0.minimumStreakDay <= streakDay }
    }
    
    static func getCoreTasksForStreak(_ streakDay: Int) -> [DailyTask] {
        let phase = ProgressionPhase.getPhase(for: streakDay)
        let availableTasks = getAvailableTasks(for: streakDay)
        
        switch phase {
        case .foundation:
            // Always include foundation tasks, add 4th task after day 4
            return Array(foundationTasks.filter { $0.minimumStreakDay <= streakDay }.prefix(4))
            
        case .growth:
            // Mix foundation and growth tasks
            let foundation = Array(foundationTasks.prefix(2)) // Keep core habits
            let growth = availableTasks.filter { $0.category == .growth }
            return foundation + Array(growth.prefix(2))
            
        case .impact:
            // Mix foundation, growth, and impact tasks
            let foundation = Array(foundationTasks.prefix(1)) // Keep one core habit
            let growth = Array(growthTasks.filter { $0.minimumStreakDay <= streakDay }.prefix(1))
            let impact = availableTasks.filter { $0.category == .impact }
            return foundation + growth + Array(impact.prefix(2))
            
        case .mastery:
            // Advanced combination with all categories
            let foundation = Array(foundationTasks.prefix(1))
            let growth = Array(growthTasks.filter { $0.minimumStreakDay <= streakDay }.prefix(1))
            let impact = Array(impactTasks.filter { $0.minimumStreakDay <= streakDay }.prefix(1))
            let mastery = availableTasks.filter { $0.category == .mastery }
            return foundation + growth + impact + Array(mastery.prefix(1))
        }
    }
    
    static func getNewlyUnlockedTasks(currentStreak: Int, previousStreak: Int) -> [DailyTask] {
        let currentAvailable = getAvailableTasks(for: currentStreak)
        let previousAvailable = getAvailableTasks(for: previousStreak)
        
        return currentAvailable.filter { task in
            !previousAvailable.contains { $0.id == task.id }
        }
    }
}
