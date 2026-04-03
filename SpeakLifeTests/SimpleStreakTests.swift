//
//  SimpleStreakTests.swift
//  SpeakLifeTests  
//
//  Simple tests to verify core streak logic works correctly
//

import XCTest
@testable import SpeakLife

final class SimpleStreakTests: XCTestCase {
    
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
    
    // MARK: - Core Streak Logic Tests
    
    func testFirstDay_ShouldHaveStreakOfOne() {
        // Given: Fresh start
        XCTAssertEqual(streakStats.currentStreak, 0)
        
        // When: Complete first day
        let today = Date()
        streakStats.updateStreak(for: today)
        
        // Then: Should have streak of 1
        XCTAssertEqual(streakStats.currentStreak, 1)
        XCTAssertEqual(streakStats.longestStreak, 1)
        XCTAssertEqual(streakStats.totalDaysCompleted, 1)
    }
    
    func testTwoConsecutiveDays_ShouldHaveStreakOfTwo() {
        // Given: Completed yesterday
        let today = Date()
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        
        streakStats.updateStreak(for: yesterday)
        XCTAssertEqual(streakStats.currentStreak, 1)
        
        // When: Complete today
        streakStats.updateStreak(for: today)
        
        // Then: Should have streak of 2
        XCTAssertEqual(streakStats.currentStreak, 2)
        XCTAssertEqual(streakStats.longestStreak, 2)
        XCTAssertEqual(streakStats.totalDaysCompleted, 2)
    }
    
    func testThreeConsecutiveDays_ShouldHaveStreakOfThree() {
        // Given: Completed for 3 consecutive days
        let today = Date()
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: today)!
        
        streakStats.updateStreak(for: twoDaysAgo)
        streakStats.updateStreak(for: yesterday)
        streakStats.updateStreak(for: today)
        
        // Then: Should have streak of 3
        XCTAssertEqual(streakStats.currentStreak, 3)
        XCTAssertEqual(streakStats.longestStreak, 3)
        XCTAssertEqual(streakStats.totalDaysCompleted, 3)
    }
    
    func testSameDay_ShouldNotIncrementStreak() {
        // Given: Completed today
        let today = Date()
        streakStats.updateStreak(for: today)
        XCTAssertEqual(streakStats.currentStreak, 1)
        
        // When: Complete same day again
        streakStats.updateStreak(for: today)
        
        // Then: Streak should remain 1, but total should increment
        XCTAssertEqual(streakStats.currentStreak, 1)
        XCTAssertEqual(streakStats.totalDaysCompleted, 2)
    }
    
    func testStreakBreak_ShouldResetToOne() {
        // Given: Had a streak, then missed days
        let today = Date()
        let threeDaysAgo = calendar.date(byAdding: .day, value: -3, to: today)!
        
        streakStats.updateStreak(for: threeDaysAgo)
        XCTAssertEqual(streakStats.currentStreak, 1)
        
        // When: Complete today (after missing days)
        streakStats.updateStreak(for: today)
        
        // Then: Streak should reset to 1
        XCTAssertEqual(streakStats.currentStreak, 1)
        XCTAssertEqual(streakStats.longestStreak, 1)
        XCTAssertEqual(streakStats.totalDaysCompleted, 2)
    }
    
    func testLongestStreakPreservation() {
        // Given: Build 5-day streak
        let today = Date()
        for i in (1...5).reversed() {
            let date = calendar.date(byAdding: .day, value: -i, to: today)!
            streakStats.updateStreak(for: date)
        }
        XCTAssertEqual(streakStats.currentStreak, 5)
        XCTAssertEqual(streakStats.longestStreak, 5)
        
        // When: Break streak and start new one
        let futureDate = calendar.date(byAdding: .day, value: 3, to: today)!
        streakStats.updateStreak(for: futureDate)
        
        // Then: Current resets but longest is preserved
        XCTAssertEqual(streakStats.currentStreak, 1)
        XCTAssertEqual(streakStats.longestStreak, 5) // Preserved
        XCTAssertEqual(streakStats.totalDaysCompleted, 6)
    }
    
    // MARK: - Display Value Test
    
    func testDisplayValues_ShouldMatchActualStreak() {
        // This simulates what the UI components would show
        
        // Day 1
        streakStats.updateStreak(for: Date())
        XCTAssertEqual(streakStats.currentStreak, 1)
        
        // Day 2 
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date())!
        streakStats.updateStreak(for: tomorrow)
        XCTAssertEqual(streakStats.currentStreak, 2)
        
        // This is what should show in celebration screen and stats
        let displayedStreak = streakStats.currentStreak
        XCTAssertEqual(displayedStreak, 2, "UI should display streak of 2, not 1")
    }
    
    // MARK: - Streak Validity Test
    
    func testStreakValidity() {
        // Given: Completed yesterday
        let yesterday = calendar.date(byAdding: .day, value: -1, to: Date())!
        streakStats.updateStreak(for: yesterday)
        XCTAssertEqual(streakStats.currentStreak, 1)
        
        // When: Check if still valid today
        streakStats.checkStreakValidity()
        
        // Then: Should still be valid
        XCTAssertEqual(streakStats.currentStreak, 1)
        
        // But if we simulate old completion...
        let threeDaysAgo = calendar.date(byAdding: .day, value: -3, to: Date())!
        streakStats.lastCompletedDate = threeDaysAgo
        streakStats.checkStreakValidity()
        
        // Then: Should be reset
        XCTAssertEqual(streakStats.currentStreak, 0)
    }
}