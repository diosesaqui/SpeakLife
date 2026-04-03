//
//  BurstCompletionModel.swift
//  SpeakLife
//
//  Model for tracking daily burst completions and spiritual strength
//

import Foundation
import SwiftUI

// MARK: - Burst Completion Data Model

struct BurstCompletion: Codable {
    let date: Date
    let completedAt: Date
    let declarationCount: Int
    let timeSpent: TimeInterval // in seconds
    var spiritualStrengthScore: Int // 1-100 scale
}

// MARK: - Spiritual Strength Calculator

struct SpiritualStrengthMetrics {
    let consistency: Double // 0-1 based on streak
    let frequency: Double // 0-1 based on completions per week
    let dedication: Double // 0-1 based on time spent
    let growth: Double // 0-1 based on improvement trend
    
    var overallScore: Int {
        let weighted = (consistency * 0.35) + (frequency * 0.25) + (dedication * 0.2) + (growth * 0.2)
        return Int(weighted * 100)
    }
}

// MARK: - Burst Completion Tracker

class BurstCompletionTracker: ObservableObject {
    static let shared = BurstCompletionTracker()
    
    @Published var completions: [BurstCompletion] = []
    @Published var weeklyData: [DailyStrengthData] = []
    @Published var monthlyTrend: [MonthlyStrengthData] = []
    @Published var currentStrengthScore: Int = 0
    @Published var strengthLevel: StrengthLevel = .warrior
    
    private let userDefaultsKey = "burstCompletions"
    private let calendar = Calendar.current
    
    enum StrengthLevel: String, CaseIterable {
        case warrior = "Warrior"
        case champion = "Champion"
        case conqueror = "Conqueror"
        case victorious = "Victorious"
        case unstoppable = "Unstoppable"
        
        var color: Color {
            switch self {
            case .warrior: return .blue
            case .champion: return .green
            case .conqueror: return .orange
            case .victorious: return .purple
            case .unstoppable: return .yellow
            }
        }
        
        var minimumScore: Int {
            switch self {
            case .warrior: return 0
            case .champion: return 20
            case .conqueror: return 40
            case .victorious: return 60
            case .unstoppable: return 80
            }
        }
        
        var icon: String {
            switch self {
            case .warrior: return "shield.fill"
            case .champion: return "medal.fill"
            case .conqueror: return "crown.fill"
            case .victorious: return "star.circle.fill"
            case .unstoppable: return "bolt.circle.fill"
            }
        }
    }
    
    struct DailyStrengthData: Identifiable {
        let id = UUID()
        let date: Date
        let score: Int
        let completed: Bool
        let dayLabel: String
    }
    
    struct MonthlyStrengthData: Identifiable {
        let id = UUID()
        let month: String
        let averageScore: Int
        let completionRate: Double
        let totalCompletions: Int
    }
    
    init() {
        loadCompletions()
        cleanupDuplicatesOneTime() // One-time cleanup of true duplicates (same timestamp)
        calculateCurrentStrength()
        generateWeeklyData()
        generateMonthlyTrend()
    }
    
    // MARK: - Public Methods
    
    var currentStreak: Int {
        calculateCurrentStreak()
    }
    
    func recordBurstCompletion(declarationCount: Int, timeSpent: TimeInterval) {
        let today = calendar.startOfDay(for: Date())
        let isFirstCompletionToday = !completions.contains(where: { calendar.startOfDay(for: $0.date) == today })
        
        let metrics = calculateMetricsInternal()
        let strengthScore = metrics.overallScore
        
        let completion = BurstCompletion(
            date: today,
            completedAt: Date(),
            declarationCount: declarationCount,
            timeSpent: timeSpent,
            spiritualStrengthScore: strengthScore
        )
        
        #if DEBUG
        let completionType = isFirstCompletionToday ? "First completion" : "Additional completion"
        print("✅ BurstCompletionTracker: Recording \(completionType) for \(today) with score \(strengthScore)")
        #endif
        
        completions.append(completion)
        saveCompletions()
        updateStrengthLevel(score: strengthScore)
        generateWeeklyData()
        generateMonthlyTrend()
        
        // Send notification for milestone achievements only on first completion of the day
        if isFirstCompletionToday {
            checkAndCelebrateMilestones()
        }
    }
    
    func getTodaysCompletion() -> BurstCompletion? {
        let today = calendar.startOfDay(for: Date())
        return completions.first { calendar.startOfDay(for: $0.date) == today }
    }
    
    func hasTodaysCompletion() -> Bool {
        return getTodaysCompletion() != nil
    }
    
    func getCompletionsForWeek() -> [BurstCompletion] {
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: Date())!
        return completions.filter { $0.date >= weekAgo }
    }
    
    func getCompletionsForMonth() -> [BurstCompletion] {
        let monthAgo = calendar.date(byAdding: .month, value: -1, to: Date())!
        return completions.filter { $0.date >= monthAgo }
    }
    
    func getUniqueDaysCount() -> Int {
        let uniqueDays = Set(completions.map { calendar.startOfDay(for: $0.date) })
        return uniqueDays.count
    }
    
    // MARK: - Public Methods for Graph
    
    func calculateMetrics() -> SpiritualStrengthMetrics {
        calculateMetricsInternal()
    }
    
    // MARK: - Private Methods
    
    private func cleanupDuplicatesOneTime() {
        // Only remove completions that have identical timestamps (true duplicates)
        // Allow multiple completions per day with different timestamps
        var uniqueCompletions: [BurstCompletion] = []
        var seenTimestamps: Set<Date> = []
        
        for completion in completions {
            if !seenTimestamps.contains(completion.completedAt) {
                seenTimestamps.insert(completion.completedAt)
                uniqueCompletions.append(completion)
            } else {
                #if DEBUG
                print("🧹 BurstCompletionTracker: Removing true duplicate with timestamp \(completion.completedAt)")
                #endif
            }
        }
        
        // Update completions only if we found true duplicates
        if uniqueCompletions.count < completions.count {
            completions = uniqueCompletions.sorted(by: { $0.date < $1.date })
            saveCompletions()
        }
    }
    
    private func calculateMetricsInternal() -> SpiritualStrengthMetrics {
        let weekCompletions = getCompletionsForWeek()
        let monthCompletions = getCompletionsForMonth()
        
        // Consistency: based on consecutive days
        let consistency = calculateConsistencyScore()
        
        // Frequency: completions in last 7 days
        let frequency = Double(weekCompletions.count) / 7.0
        
        // Dedication: average time spent
        let avgTimeSpent = weekCompletions.isEmpty ? 0 : 
            weekCompletions.map(\.timeSpent).reduce(0, +) / Double(weekCompletions.count)
        let dedication = min(avgTimeSpent / 180.0, 1.0) // 3 minutes = perfect score
        
        // Growth: improvement trend
        let growth = calculateGrowthTrend(monthCompletions)
        
        return SpiritualStrengthMetrics(
            consistency: consistency,
            frequency: frequency,
            dedication: dedication,
            growth: growth
        )
    }
    
    private func calculateCurrentStreak() -> Int {
        var consecutiveDays = 0
        var currentDate = calendar.startOfDay(for: Date())
        
        // Check consecutive days starting from today going backwards
        for _ in 0..<365 {  // Check up to a year back
            // Count day as complete if there's at least one completion that day
            if completions.contains(where: { calendar.startOfDay(for: $0.date) == currentDate }) {
                consecutiveDays += 1
                currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate)!
            } else {
                break
            }
        }
        
        return consecutiveDays
    }
    
    private func calculateConsistencyScore() -> Double {
        let streak = calculateCurrentStreak()
        return min(Double(streak) / 7.0, 1.0) // 7 days = perfect consistency
    }
    
    private func calculateGrowthTrend(_ monthCompletions: [BurstCompletion]) -> Double {
        guard monthCompletions.count > 7 else { return 0.5 } // neutral if not enough data
        
        let sorted = monthCompletions.sorted { $0.date < $1.date }
        let firstWeek = Array(sorted.prefix(7))
        let lastWeek = Array(sorted.suffix(7))
        
        let firstWeekAvg = firstWeek.map { Double($0.spiritualStrengthScore) }.reduce(0, +) / Double(firstWeek.count)
        let lastWeekAvg = lastWeek.map { Double($0.spiritualStrengthScore) }.reduce(0, +) / Double(lastWeek.count)
        
        let improvement = (lastWeekAvg - firstWeekAvg) / 100.0
        return min(max(0.5 + improvement, 0), 1) // 0.5 is neutral, cap at 0-1
    }
    
    private func calculateCurrentStrength() {
        let metrics = calculateMetricsInternal()
        currentStrengthScore = metrics.overallScore
        updateStrengthLevel(score: currentStrengthScore)
    }
    
    private func updateStrengthLevel(score: Int) {
        for level in StrengthLevel.allCases.reversed() {
            if score >= level.minimumScore {
                strengthLevel = level
                break
            }
        }
    }
    
    private func generateWeeklyData() {
        weeklyData = []
        let today = calendar.startOfDay(for: Date())
        
        for dayOffset in (0..<7).reversed() {
            if let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) {
                let dayCompletions = completions.filter { calendar.startOfDay(for: $0.date) == date }
                let dayFormatter = DateFormatter()
                dayFormatter.dateFormat = "E"
                
                // Sum all completion scores for the day (allows multiple completions)
                let totalScore = dayCompletions.map { $0.spiritualStrengthScore }.reduce(0, +)
                
                weeklyData.append(DailyStrengthData(
                    date: date,
                    score: totalScore,
                    completed: !dayCompletions.isEmpty,
                    dayLabel: dayFormatter.string(from: date)
                ))
            }
        }
    }
    
    private func generateMonthlyTrend() {
        monthlyTrend = []
        let today = Date()
        
        for monthOffset in (0..<3).reversed() {
            if let monthStart = calendar.date(byAdding: .month, value: -monthOffset, to: today) {
                let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart)!
                let monthCompletions = completions.filter { 
                    $0.date >= monthStart && $0.date < monthEnd 
                }
                
                if !monthCompletions.isEmpty {
                    let avgScore = monthCompletions.map { $0.spiritualStrengthScore }.reduce(0, +) / monthCompletions.count
                    let daysInMonth = calendar.range(of: .day, in: .month, for: monthStart)?.count ?? 30
                    let completionRate = Double(monthCompletions.count) / Double(daysInMonth)
                    
                    let monthFormatter = DateFormatter()
                    monthFormatter.dateFormat = "MMM"
                    
                    monthlyTrend.append(MonthlyStrengthData(
                        month: monthFormatter.string(from: monthStart),
                        averageScore: avgScore,
                        completionRate: completionRate,
                        totalCompletions: monthCompletions.count
                    ))
                }
            }
        }
    }
    
    private func checkAndCelebrateMilestones() {
        let uniqueDays = getUniqueDaysCount()
        
        // Check for milestone achievements based on unique days
        let milestones = [7, 21, 30, 50, 100]
        if milestones.contains(uniqueDays) {
            // This would trigger a celebration animation or notification
            NotificationCenter.default.post(
                name: Notification.Name("BurstMilestoneAchieved"),
                object: nil,
                userInfo: ["count": uniqueDays]
            )
        }
    }
    
    // MARK: - Persistence
    
    private func saveCompletions() {
        if let encoded = try? JSONEncoder().encode(completions) {
            UserDefaults.standard.set(encoded, forKey: userDefaultsKey)
        }
    }
    
    private func loadCompletions() {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let decoded = try? JSONDecoder().decode([BurstCompletion].self, from: data) {
            completions = decoded
        }
    }
}