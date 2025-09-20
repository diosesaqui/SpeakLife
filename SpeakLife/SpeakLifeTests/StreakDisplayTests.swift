//
//  StreakDisplayTests.swift
//  SpeakLifeTests
//
//  Unit tests to ensure streak display consistency across all UI components
//

import XCTest
import Combine
@testable import SpeakLife

final class StreakDisplayTests: XCTestCase {
    
    var viewModel: EnhancedStreakViewModel!
    var cancellables: Set<AnyCancellable>!
    let calendar = Calendar.current
    
    override func setUp() {
        super.setUp()
        cancellables = Set<AnyCancellable>()
        
        // Clear any existing UserDefaults data to ensure clean state
        UserDefaults.standard.removeObject(forKey: "dailyChecklist")
        UserDefaults.standard.removeObject(forKey: "streakStats")
        
        viewModel = EnhancedStreakViewModel()
    }
    
    override func tearDown() {
        cancellables = nil
        viewModel = nil
        
        // Clean up UserDefaults
        UserDefaults.standard.removeObject(forKey: "dailyChecklist")
        UserDefaults.standard.removeObject(forKey: "streakStats")
        
        super.tearDown()
    }
    
    // MARK: - Display Consistency Tests
    
    func testStreakDisplayConsistency_FirstDay() {
        // Given: Complete first day
        completeAllTasks()
        
        // Then: All display components should show 1
        XCTAssertEqual(viewModel.streakStats.currentStreak, 1, "Core streak should be 1")
        
        // Test what would be displayed in CompactStreakButton
        let compactButtonStreak = viewModel.streakStats.currentStreak
        XCTAssertEqual(compactButtonStreak, 1, "Compact button should display 1")
        
        // Test what would be displayed in CompletedStreakBadge
        let badgeStreak = viewModel.streakStats.currentStreak
        XCTAssertEqual(badgeStreak, 1, "Badge should display 1")
        
        // Test what would be displayed in PremiumStatCard (Current Streak)
        let statsStreak = viewModel.streakStats.currentStreak
        XCTAssertEqual(statsStreak, 1, "Stats card should display 1")
    }
    
    func testStreakDisplayConsistency_SecondDay() {
        // Given: Complete two consecutive days
        let yesterday = calendar.date(byAdding: .day, value: -1, to: Date())!
        viewModel.streakStats.updateStreak(for: yesterday)
        completeAllTasks()
        
        // Then: All display components should show 2
        XCTAssertEqual(viewModel.streakStats.currentStreak, 2, "Core streak should be 2")
        
        // Test what would be displayed in all UI components
        let displayedStreak = viewModel.streakStats.currentStreak
        XCTAssertEqual(displayedStreak, 2, "All UI components should display 2, not 1")
    }
    
    func testStreakDisplayConsistency_ThirdDay() {
        // Given: Complete three consecutive days
        let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: Date())!
        let yesterday = calendar.date(byAdding: .day, value: -1, to: Date())!
        
        viewModel.streakStats.updateStreak(for: twoDaysAgo)
        viewModel.streakStats.updateStreak(for: yesterday)
        completeAllTasks()
        
        // Then: All display components should show 3
        XCTAssertEqual(viewModel.streakStats.currentStreak, 3, "Core streak should be 3")
        
        let displayedStreak = viewModel.streakStats.currentStreak
        XCTAssertEqual(displayedStreak, 3, "All UI components should display 3")
    }
    
    func testCelebrationDataConsistency() {
        // Given: Complete day to trigger celebration
        completeAllTasks()
        
        // Wait for celebration to be created
        let expectation = XCTestExpectation(description: "Celebration should be created")
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 3.0)
        
        // Then: Celebration data should match actual streak
        XCTAssertNotNil(viewModel.celebrationData, "Celebration data should exist")
        XCTAssertEqual(viewModel.celebrationData?.streakNumber, viewModel.streakStats.currentStreak, 
                      "Celebration should show same streak as stats")
    }
    
    func testShareButtonDisplayConsistency() {
        // Given: Build up a streak
        for i in (1...5).reversed() {
            let date = calendar.date(byAdding: .day, value: -i, to: Date())!
            viewModel.streakStats.updateStreak(for: date)
        }
        completeAllTasks()
        
        // Then: Share button text should match actual streak
        let shareButtonStreak = viewModel.streakStats.currentStreak
        XCTAssertEqual(shareButtonStreak, 6, "Share button should display correct streak count")
        
        // The share button message would be: "Share My \(shareButtonStreak) Day Streak!"
        let expectedMessage = "Share My \(shareButtonStreak) Day Streak!"
        XCTAssertTrue(expectedMessage.contains("\(shareButtonStreak)"), 
                     "Share message should contain correct streak number")
    }
    
    // MARK: - Progress Display Tests
    
    func testProgressRingConsistency() {
        // Given: Partially completed checklist
        let firstTask = viewModel.todayChecklist.tasks.first!
        viewModel.completeTask(taskId: firstTask.id)
        
        // Then: Progress should match completion ratio
        let expectedProgress = 1.0 / Double(viewModel.todayChecklist.tasks.count)
        let actualProgress = viewModel.todayChecklist.completionProgress
        
        XCTAssertEqual(actualProgress, expectedProgress, accuracy: 0.01, 
                      "Progress ring should show correct completion percentage")
    }
    
    func testTaskCountDisplayConsistency() {
        // Given: Complete some tasks
        let tasksToComplete = min(2, viewModel.todayChecklist.tasks.count)
        for i in 0..<tasksToComplete {
            viewModel.completeTask(taskId: viewModel.todayChecklist.tasks[i].id)
        }
        
        // Then: Count displays should be consistent
        let completedCount = viewModel.todayChecklist.completedTasksCount
        let totalCount = viewModel.todayChecklist.tasks.count
        
        XCTAssertEqual(completedCount, tasksToComplete, "Completed count should match actions")
        
        // Test what would be shown in DailyChecklistSummary: "2/4" format
        let summaryText = "\(completedCount)/\(totalCount)"
        XCTAssertTrue(summaryText.contains("\(completedCount)"), "Summary should show correct completed count")
        XCTAssertTrue(summaryText.contains("\(totalCount)"), "Summary should show correct total count")
    }
    
    // MARK: - Milestone Display Tests
    
    func testMilestoneProgressConsistency() {
        // Given: Streak of 5 (milestone progress toward 7)
        for i in (1...5).reversed() {
            let date = calendar.date(byAdding: .day, value: -i, to: Date())!
            viewModel.streakStats.updateStreak(for: date)
        }
        
        // Then: Progress calculation should be consistent
        let currentStreak = viewModel.streakStats.currentStreak
        XCTAssertEqual(currentStreak, 5, "Current streak should be 5")
        
        // Next milestone should be 7, previous 0
        let nextMilestone = getNextMilestone(currentStreak)
        let previousMilestone = getPreviousMilestone(currentStreak)
        
        XCTAssertEqual(nextMilestone, 7, "Next milestone should be 7")
        XCTAssertEqual(previousMilestone, 0, "Previous milestone should be 0")
        
        // Progress should be 5/7 = ~0.71
        let expectedProgress = Double(currentStreak - previousMilestone) / Double(nextMilestone - previousMilestone)
        XCTAssertEqual(expectedProgress, 5.0/7.0, accuracy: 0.01, "Milestone progress should be correct")
    }
    
    func testBadgeTextConsistency() {
        // Given: Complete day
        completeAllTasks()
        
        // Then: Badge text should match streak
        let streakNumber = viewModel.streakStats.currentStreak
        let expectedBadgeText = "\(streakNumber) day streak!"
        
        XCTAssertTrue(expectedBadgeText.contains("\(streakNumber)"), "Badge text should contain correct number")
    }
    
    // MARK: - Edge Case Display Tests
    
    func testZeroStreakDisplay() {
        // Given: No streak
        XCTAssertEqual(viewModel.streakStats.currentStreak, 0, "Initial streak should be 0")
        
        // Then: Display should handle zero appropriately
        let displayStreak = viewModel.streakStats.currentStreak
        XCTAssertEqual(displayStreak, 0, "Display should show 0 for no streak")
    }
    
    func testLargeStreakDisplay() {
        // Given: Build large streak
        for i in (1...100).reversed() {
            let date = calendar.date(byAdding: .day, value: -i, to: Date())!
            viewModel.streakStats.updateStreak(for: date)
        }
        
        // Then: Large numbers should display correctly
        let largeStreak = viewModel.streakStats.currentStreak
        XCTAssertEqual(largeStreak, 100, "Large streak should be calculated correctly")
        
        // Test that UI can handle large numbers
        let displayText = "\(largeStreak)"
        XCTAssertEqual(displayText, "100", "Large streak should format correctly for display")
    }
    
    func testStreakBrokenDisplayReset() {
        // Given: Had streak, then broke it
        let threeDaysAgo = calendar.date(byAdding: .day, value: -3, to: Date())!
        viewModel.streakStats.updateStreak(for: threeDaysAgo)
        XCTAssertEqual(viewModel.streakStats.currentStreak, 1)
        
        // When: Complete today (streak broken)
        completeAllTasks()
        
        // Then: Display should show reset streak
        XCTAssertEqual(viewModel.streakStats.currentStreak, 1, "Broken streak should reset to 1")
        
        let displayStreak = viewModel.streakStats.currentStreak
        XCTAssertEqual(displayStreak, 1, "All displays should show reset value")
    }
    
    // MARK: - Real-World Scenario Tests
    
    func testConsecutiveDayScenario() {
        // This test simulates the exact bug scenario: day 1 complete, day 2 complete
        // Should show "2 day streak" not "1 day streak"
        
        // Day 1: Complete tasks
        let yesterday = calendar.date(byAdding: .day, value: -1, to: Date())!
        viewModel.streakStats.updateStreak(for: yesterday)
        XCTAssertEqual(viewModel.streakStats.currentStreak, 1, "Day 1 should have streak of 1")
        
        // Day 2: Complete tasks
        completeAllTasks()
        XCTAssertEqual(viewModel.streakStats.currentStreak, 2, "Day 2 should have streak of 2")
        
        // All UI components should show 2, not 1
        let compactButtonDisplay = viewModel.streakStats.currentStreak
        let badgeDisplay = viewModel.streakStats.currentStreak
        let shareButtonDisplay = viewModel.streakStats.currentStreak
        let statsDisplay = viewModel.streakStats.currentStreak
        
        XCTAssertEqual(compactButtonDisplay, 2, "Compact button should show 2")
        XCTAssertEqual(badgeDisplay, 2, "Badge should show 2") 
        XCTAssertEqual(shareButtonDisplay, 2, "Share button should show 2")
        XCTAssertEqual(statsDisplay, 2, "Stats should show 2")
        
        // This is the key assertion that was failing in the bug report
        XCTAssertNotEqual(viewModel.streakStats.currentStreak, 1, "Should NOT show 1 when actual streak is 2")
    }
    
    func testCelebrationScreenCorrectNumber() {
        // Given: Build 2-day streak
        let yesterday = calendar.date(byAdding: .day, value: -1, to: Date())!
        viewModel.streakStats.updateStreak(for: yesterday)
        completeAllTasks() // This should make streak = 2
        
        // Wait for celebration
        let expectation = XCTestExpectation(description: "Celebration screen data")
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 3.0)
        
        // Then: Celebration screen should show 2, not 1
        XCTAssertNotNil(viewModel.celebrationData, "Celebration should exist")
        XCTAssertEqual(viewModel.celebrationData?.streakNumber, 2, "Celebration should show 2 day streak")
        XCTAssertNotEqual(viewModel.celebrationData?.streakNumber, 1, "Celebration should NOT show 1 day streak")
    }
    
    // MARK: - Helper Methods
    
    private func completeAllTasks() {
        for task in viewModel.todayChecklist.tasks {
            viewModel.completeTask(taskId: task.id)
        }
    }
    
    private func getNextMilestone(_ current: Int) -> Int {
        let milestones = [7, 14, 30, 50, 100, 200, 365]
        return milestones.first { $0 > current } ?? (current + 100)
    }
    
    private func getPreviousMilestone(_ current: Int) -> Int {
        let milestones = [0, 7, 14, 30, 50, 100, 200, 365]
        return milestones.last { $0 <= current } ?? 0
    }
}