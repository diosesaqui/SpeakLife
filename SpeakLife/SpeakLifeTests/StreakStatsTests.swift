//
//  StreakStatsTests.swift
//  SpeakLifeTests
//
//  Unit tests for StreakStats model to ensure streak calculation logic works correctly
//

import XCTest
@testable import SpeakLife

final class StreakStatsTests: XCTestCase {
    
    var streakStats: StreakStats!
    let calendar = Calendar.current
    
    override func setUp() {
        super.setUp()
        streakStats = StreakStats()
    }
    
    override func tearDown() {
        streakStats = nil
        super.tearDown()
    }
    
    // MARK: - First Completion Tests
    
    func testFirstCompletion_ShouldSetStreakToOne() {
        // Given: Fresh StreakStats with no previous completions
        let today = Date()
        
        // When: First completion
        streakStats.updateStreak(for: today)
        
        // Then: Streak should be 1
        XCTAssertEqual(streakStats.currentStreak, 1)
        XCTAssertEqual(streakStats.longestStreak, 1)
        XCTAssertEqual(streakStats.totalDaysCompleted, 1)
        XCTAssertNotNil(streakStats.lastCompletedDate)
        XCTAssertEqual(calendar.startOfDay(for: streakStats.lastCompletedDate!), calendar.startOfDay(for: today))
    }
    
    // MARK: - Consecutive Day Tests
    
    func testConsecutiveDays_ShouldIncrementStreak() {
        // Given: Completed yesterday
        let today = Date()
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        streakStats.updateStreak(for: yesterday)
        
        // When: Complete today (consecutive day)
        streakStats.updateStreak(for: today)
        
        // Then: Streak should increment to 2
        XCTAssertEqual(streakStats.currentStreak, 2)
        XCTAssertEqual(streakStats.longestStreak, 2)
        XCTAssertEqual(streakStats.totalDaysCompleted, 2)
    }
    
    func testThreeConsecutiveDays_ShouldIncrementToThree() {
        // Given: Completed two days ago and yesterday
        let today = Date()
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: today)!
        
        streakStats.updateStreak(for: twoDaysAgo)
        streakStats.updateStreak(for: yesterday)
        
        // When: Complete today (third consecutive day)
        streakStats.updateStreak(for: today)
        
        // Then: Streak should be 3
        XCTAssertEqual(streakStats.currentStreak, 3)
        XCTAssertEqual(streakStats.longestStreak, 3)
        XCTAssertEqual(streakStats.totalDaysCompleted, 3)
    }
    
    // MARK: - Same Day Completion Tests
    
    func testSameDay_ShouldNotChangeStreak() {
        // Given: Completed today already
        let today = Date()
        streakStats.updateStreak(for: today)
        let initialStreak = streakStats.currentStreak
        let initialTotal = streakStats.totalDaysCompleted
        
        // When: Try to complete same day again
        streakStats.updateStreak(for: today)
        
        // Then: Streak should not change but total should increment
        XCTAssertEqual(streakStats.currentStreak, initialStreak)
        XCTAssertEqual(streakStats.totalDaysCompleted, initialTotal + 1)
    }
    
    // MARK: - Streak Break Tests
    
    func testSkipOneDay_ShouldResetStreakToOne() {
        // Given: Completed 3 days ago (streak broken)
        let today = Date()
        let threeDaysAgo = calendar.date(byAdding: .day, value: -3, to: today)!
        streakStats.updateStreak(for: threeDaysAgo)
        XCTAssertEqual(streakStats.currentStreak, 1)
        
        // When: Complete today (after missing days)
        streakStats.updateStreak(for: today)
        
        // Then: Streak should reset to 1
        XCTAssertEqual(streakStats.currentStreak, 1)
        XCTAssertEqual(streakStats.longestStreak, 1) // Longest is still 1 from first completion
        XCTAssertEqual(streakStats.totalDaysCompleted, 2)
    }
    
    func testLongStreakThenBreak_ShouldMaintainLongestStreak() {
        // Given: Build up a 5-day streak
        let today = Date()
        for i in (1...5).reversed() {
            let date = calendar.date(byAdding: .day, value: -i, to: today)!
            streakStats.updateStreak(for: date)
        }
        XCTAssertEqual(streakStats.currentStreak, 5)
        XCTAssertEqual(streakStats.longestStreak, 5)
        
        // When: Skip several days and complete today
        let futureDate = calendar.date(byAdding: .day, value: 10, to: today)!
        streakStats.updateStreak(for: futureDate)
        
        // Then: Current streak resets but longest streak is preserved
        XCTAssertEqual(streakStats.currentStreak, 1)
        XCTAssertEqual(streakStats.longestStreak, 5) // Should preserve the longest
        XCTAssertEqual(streakStats.totalDaysCompleted, 6)
    }
    
    // MARK: - Streak Validity Check Tests
    
    func testCheckStreakValidity_WithRecentCompletion_ShouldMaintainStreak() {
        // Given: Completed yesterday
        let today = Date()
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        streakStats.updateStreak(for: yesterday)
        XCTAssertEqual(streakStats.currentStreak, 1)
        
        // When: Check validity today (still valid)
        streakStats.checkStreakValidity()
        
        // Then: Streak should be maintained
        XCTAssertEqual(streakStats.currentStreak, 1)
    }
    
    func testCheckStreakValidity_WithOldCompletion_ShouldResetStreak() {
        // Given: Completed 3 days ago
        let today = Date()
        let threeDaysAgo = calendar.date(byAdding: .day, value: -3, to: today)!
        streakStats.updateStreak(for: threeDaysAgo)
        XCTAssertEqual(streakStats.currentStreak, 1)
        
        // When: Check validity today (expired)
        streakStats.checkStreakValidity()
        
        // Then: Streak should be reset to 0
        XCTAssertEqual(streakStats.currentStreak, 0)
    }
    
    func testCheckStreakValidity_WithNoCompletion_ShouldHaveZeroStreak() {
        // Given: No previous completions
        XCTAssertNil(streakStats.lastCompletedDate)
        
        // When: Check validity
        streakStats.checkStreakValidity()
        
        // Then: Streak should be 0
        XCTAssertEqual(streakStats.currentStreak, 0)
    }
    
    // MARK: - Edge Case Tests
    
    func testCompletionAtMidnight_ShouldWorkCorrectly() {
        // Given: Yesterday at 23:59
        let calendar = Calendar.current
        let today = Date()
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let yesterdayLate = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: yesterday)!
        
        streakStats.updateStreak(for: yesterdayLate)
        
        // When: Today at 00:01
        let todayEarly = calendar.date(bySettingHour: 0, minute: 1, second: 0, of: today)!
        streakStats.updateStreak(for: todayEarly)
        
        // Then: Should be consecutive (streak = 2)
        XCTAssertEqual(streakStats.currentStreak, 2)
    }
    
    func testFutureDate_ShouldWorkCorrectly() {
        // Given: Complete today
        let today = Date()
        streakStats.updateStreak(for: today)
        
        // When: Complete tomorrow
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        streakStats.updateStreak(for: tomorrow)
        
        // Then: Should be consecutive (streak = 2)
        XCTAssertEqual(streakStats.currentStreak, 2)
    }
    
    // MARK: - Record Breaking Tests
    
    func testNewRecord_ShouldUpdateLongestStreak() {
        // Given: Previous longest streak of 3
        let today = Date()
        for i in (1...3).reversed() {
            let date = calendar.date(byAdding: .day, value: -i, to: today)!
            streakStats.updateStreak(for: date)
        }
        XCTAssertEqual(streakStats.longestStreak, 3)
        
        // Break the streak
        let futureDate = calendar.date(byAdding: .day, value: 10, to: today)!
        streakStats.updateStreak(for: futureDate)
        XCTAssertEqual(streakStats.currentStreak, 1)
        XCTAssertEqual(streakStats.longestStreak, 3)
        
        // When: Build a new longer streak (4 days)
        for i in 1...3 {
            let date = calendar.date(byAdding: .day, value: i, to: futureDate)!
            streakStats.updateStreak(for: date)
        }
        
        // Then: Longest streak should be updated to 4
        XCTAssertEqual(streakStats.currentStreak, 4)
        XCTAssertEqual(streakStats.longestStreak, 4)
    }
    
    // MARK: - Integration Tests
    
    func testRealWorldScenario_WeekLongStreak() {
        // Simulate a week-long streak
        let today = Date()
        
        // Complete 7 consecutive days
        for i in (1...7).reversed() {
            let date = calendar.date(byAdding: .day, value: -i, to: today)!
            streakStats.updateStreak(for: date)
        }
        
        // Verify final state
        XCTAssertEqual(streakStats.currentStreak, 7)
        XCTAssertEqual(streakStats.longestStreak, 7)
        XCTAssertEqual(streakStats.totalDaysCompleted, 7)
        
        // Complete today for 8th day
        streakStats.updateStreak(for: today)
        
        XCTAssertEqual(streakStats.currentStreak, 8)
        XCTAssertEqual(streakStats.longestStreak, 8)
        XCTAssertEqual(streakStats.totalDaysCompleted, 8)
    }
    
    func testRealWorldScenario_StreakBreakAndRecover() {
        let today = Date()
        
        // Build 5-day streak
        for i in (5...9).reversed() {
            let date = calendar.date(byAdding: .day, value: -i, to: today)!
            streakStats.updateStreak(for: date)
        }
        XCTAssertEqual(streakStats.currentStreak, 5)
        
        // Skip 3 days, then complete
        let recoveryDate = calendar.date(byAdding: .day, value: -2, to: today)!
        streakStats.updateStreak(for: recoveryDate)
        
        // Verify streak reset but longest preserved
        XCTAssertEqual(streakStats.currentStreak, 1)
        XCTAssertEqual(streakStats.longestStreak, 5)
        
        // Build new streak
        streakStats.updateStreak(for: calendar.date(byAdding: .day, value: -1, to: today)!)
        streakStats.updateStreak(for: today)
        
        XCTAssertEqual(streakStats.currentStreak, 3)
        XCTAssertEqual(streakStats.longestStreak, 5)
    }
}