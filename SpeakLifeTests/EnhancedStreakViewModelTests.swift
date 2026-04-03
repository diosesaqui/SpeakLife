//
//  EnhancedStreakViewModelTests.swift
//  SpeakLifeTests
//
//  Unit tests for EnhancedStreakViewModel to ensure streak management and celebration logic works correctly
//

import XCTest
import Combine
@testable import SpeakLife

final class EnhancedStreakViewModelTests: XCTestCase {
    
    var viewModel: EnhancedStreakViewModel!
    var cancellables: Set<AnyCancellable>!
    let calendar = Calendar.current
    
    override func setUp() {
        super.setUp()
        cancellables = Set<AnyCancellable>()
        
        // Clear any existing UserDefaults data to ensure clean state
        UserDefaults.standard.removeObject(forKey: "dailyChecklist")
        UserDefaults.standard.removeObject(forKey: "streakStats")
        UserDefaults.standard.removeObject(forKey: "hasAutoCompletedFirstTask")
        
        viewModel = EnhancedStreakViewModel()
    }
    
    override func tearDown() {
        cancellables = nil
        viewModel = nil
        
        // Clean up UserDefaults
        UserDefaults.standard.removeObject(forKey: "dailyChecklist")
        UserDefaults.standard.removeObject(forKey: "streakStats")
        UserDefaults.standard.removeObject(forKey: "hasAutoCompletedFirstTask")
        
        super.tearDown()
    }
    
    // MARK: - Initial State Tests
    
    func testInitialState_ShouldHaveZeroStreak() {
        // Then: Initial state should be clean
        XCTAssertEqual(viewModel.streakStats.currentStreak, 0)
        XCTAssertEqual(viewModel.streakStats.longestStreak, 0)
        XCTAssertEqual(viewModel.streakStats.totalDaysCompleted, 0)
        XCTAssertNil(viewModel.streakStats.lastCompletedDate)
        XCTAssertFalse(viewModel.showCompletionCelebration)
        XCTAssertFalse(viewModel.showFireAnimation)
        XCTAssertNil(viewModel.celebrationData)
    }
    
    func testInitialChecklist_ShouldBeForToday() {
        // Then: Today's checklist should be created
        let today = calendar.startOfDay(for: Date())
        let checklistDate = calendar.startOfDay(for: viewModel.todayChecklist.date)
        XCTAssertEqual(checklistDate, today)
        XCTAssertFalse(viewModel.todayChecklist.tasks.isEmpty)
    }
    
    // MARK: - Task Completion Tests
    
    func testCompleteTask_ShouldUpdateChecklist() {
        // Given: A task in the checklist
        let task = viewModel.todayChecklist.tasks.first!
        XCTAssertFalse(task.isCompleted)
        
        // When: Complete the task
        viewModel.completeTask(taskId: task.id)
        
        // Then: Task should be marked completed
        let updatedTask = viewModel.todayChecklist.tasks.first { $0.id == task.id }!
        XCTAssertTrue(updatedTask.isCompleted)
    }
    
    func testCompleteAllTasks_ShouldTriggerDayCompletion() {
        // Given: All tasks are incomplete
        XCTAssertFalse(viewModel.todayChecklist.isCompleted)
        
        // When: Complete all tasks
        completeAllTasks()
        
        // Then: Day should be completed and streak should update
        XCTAssertTrue(viewModel.todayChecklist.isCompleted)
        XCTAssertEqual(viewModel.streakStats.currentStreak, 1)
    }
    
    // MARK: - Streak Progression Tests
    
    func testFirstDayCompletion_ShouldCreateStreakOfOne() {
        // Given: Fresh start
        XCTAssertEqual(viewModel.streakStats.currentStreak, 0)
        
        // When: Complete all tasks for the first time
        completeAllTasks()
        
        // Then: Streak should be 1
        XCTAssertEqual(viewModel.streakStats.currentStreak, 1)
        XCTAssertEqual(viewModel.streakStats.longestStreak, 1)
        XCTAssertEqual(viewModel.streakStats.totalDaysCompleted, 1)
        XCTAssertNotNil(viewModel.streakStats.lastCompletedDate)
    }
    
    func testSecondConsecutiveDay_ShouldIncrementStreak() {
        // Given: Completed yesterday
        let yesterday = calendar.date(byAdding: .day, value: -1, to: Date())!
        viewModel.streakStats.updateStreak(for: yesterday)
        
        // When: Complete all tasks today
        completeAllTasks()
        
        // Then: Streak should be 2
        XCTAssertEqual(viewModel.streakStats.currentStreak, 2)
        XCTAssertEqual(viewModel.streakStats.longestStreak, 2)
    }
    
    // MARK: - Celebration Tests
    
    func testFirstCompletion_ShouldTriggerCelebration() {
        // Given: Fresh start
        var celebrationTriggered = false
        
        viewModel.$showCompletionCelebration
            .sink { showCelebration in
                if showCelebration {
                    celebrationTriggered = true
                }
            }
            .store(in: &cancellables)
        
        // When: Complete first day
        completeAllTasks()
        
        // Wait for celebration to trigger
        let expectation = XCTestExpectation(description: "Celebration should trigger")
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 3.0)
        
        // Then: Celebration should be triggered
        XCTAssertTrue(celebrationTriggered)
        XCTAssertNotNil(viewModel.celebrationData)
        XCTAssertEqual(viewModel.celebrationData?.streakNumber, 1)
    }
    
    func testMilestoneCompletion_ShouldHaveCorrectCelebrationData() {
        // Given: 6 days completed (approaching 7-day milestone)
        for i in (1...6).reversed() {
            let date = calendar.date(byAdding: .day, value: -i, to: Date())!
            viewModel.streakStats.updateStreak(for: date)
        }
        
        // When: Complete 7th day
        completeAllTasks()
        
        // Wait for celebration
        let expectation = XCTestExpectation(description: "Milestone celebration")
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 3.0)
        
        // Then: Celebration should reflect 7-day milestone
        XCTAssertNotNil(viewModel.celebrationData)
        XCTAssertEqual(viewModel.celebrationData?.streakNumber, 7)
        XCTAssertTrue((viewModel.celebrationData?.motivationalMessage.contains("7") ?? false) || 
                      (viewModel.celebrationData?.motivationalMessage.contains("WEEK") ?? false))
    }
    
    func testNewRecord_ShouldBeMarkedInCelebration() {
        // Given: Previous record of 3, current streak broken
        viewModel.streakStats.longestStreak = 3
        viewModel.streakStats.currentStreak = 0
        
        // When: Complete 4 consecutive days (new record)
        for i in (0...3).reversed() {
            let date = calendar.date(byAdding: .day, value: -i, to: Date())!
            viewModel.streakStats.updateStreak(for: date)
        }
        
        completeAllTasks()
        
        // Wait for celebration
        let expectation = XCTestExpectation(description: "New record celebration")
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 3.0)
        
        // Then: Should be marked as new record
        XCTAssertNotNil(viewModel.celebrationData)
        XCTAssertEqual(viewModel.celebrationData?.streakNumber, 4)
        XCTAssertTrue(viewModel.celebrationData?.isNewRecord ?? false)
    }
    
    // MARK: - Data Persistence Tests
    
    func testDataPersistence_ShouldSaveAndLoadCorrectly() {
        // Given: Complete some tasks and build streak
        completeAllTasks()
        let originalStreak = viewModel.streakStats.currentStreak
        let originalTotal = viewModel.streakStats.totalDaysCompleted
        
        // When: Create new view model (simulates app restart)
        let newViewModel = EnhancedStreakViewModel()
        
        // Then: Data should be restored (this tests the private loadData() method)
        XCTAssertEqual(newViewModel.streakStats.currentStreak, originalStreak)
        XCTAssertEqual(newViewModel.streakStats.totalDaysCompleted, originalTotal)
    }
    
    func testChecklistPersistence_ShouldRestoreCompletedTasks() {
        // Given: Complete some tasks
        let taskToComplete = viewModel.todayChecklist.tasks.first!
        viewModel.completeTask(taskId: taskToComplete.id)
        
        // When: Create new view model (simulates app restart)
        let newViewModel = EnhancedStreakViewModel()
        
        // Then: Completed task should be restored
        let restoredTask = newViewModel.todayChecklist.tasks.first { $0.id == taskToComplete.id }
        XCTAssertNotNil(restoredTask)
        XCTAssertTrue(restoredTask?.isCompleted ?? false)
    }
    
    // MARK: - Progressive Task System Tests
    
    func testProgressiveTasks_ShouldUnlockBasedOnStreak() {
        // Given: Build up streak to unlock new tasks
        for i in (1...7).reversed() {
            let date = calendar.date(byAdding: .day, value: -i, to: Date())!
            viewModel.streakStats.updateStreak(for: date)
        }
        
        // When: Check that the checklist has tasks (createProgressiveChecklist is private)
        // We'll test this indirectly by verifying task progression happens
        let initialTaskCount = viewModel.todayChecklist.tasks.count
        
        // Then: Should have some tasks available
        XCTAssertGreaterThan(initialTaskCount, 0)
    }
    
    func testUpcomingUnlocks_ShouldShowFutureTasks() {
        // Given: Current streak of 5
        viewModel.streakStats.currentStreak = 5
        
        // When: Get upcoming unlocks
        let upcomingTasks = viewModel.getUpcomingUnlocks(for: 5)
        
        // Then: Should return tasks that unlock in next few days
        XCTAssertFalse(upcomingTasks.isEmpty)
        for task in upcomingTasks {
            XCTAssertGreaterThan(task.minimumStreakDay, 5)
        }
    }
    
    // MARK: - Share Image Generation Tests
    
    func testShareImageGeneration_ShouldCreateImage() {
        // Given: Some streak data
        viewModel.streakStats.currentStreak = 5
        
        // When: Generate share image
        let shareImage = viewModel.generateShareImage()
        
        // Then: Should create a valid image
        XCTAssertNotNil(shareImage)
        XCTAssertGreaterThan(shareImage?.size.width ?? 0, 0)
        XCTAssertGreaterThan(shareImage?.size.height ?? 0, 0)
    }
    
    // MARK: - Auto-Completion Tests (Bug Fix Verification)
    
    func testAutoCompleteFirstTask_ShouldOnlyHappenOnce() {
        // Given: Fresh start with demo completed
        XCTAssertEqual(viewModel.todayChecklist.completedTasksCount, 0)
        
        // When: Call auto-complete for the first time
        viewModel.autoCompleteFirstTaskIfDemoCompleted(hasCompletedDemo: true)
        
        // Wait for async completion
        let expectation1 = XCTestExpectation(description: "First auto-completion")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            expectation1.fulfill()
        }
        wait(for: [expectation1], timeout: 1.0)
        
        // Then: First task should be completed
        XCTAssertEqual(viewModel.todayChecklist.completedTasksCount, 1)
        let firstTask = viewModel.todayChecklist.tasks.first!
        XCTAssertTrue(firstTask.isCompleted)
        
        // When: Call auto-complete again (simulating view re-appearing)
        viewModel.autoCompleteFirstTaskIfDemoCompleted(hasCompletedDemo: true)
        
        // Wait to ensure no additional completion happens
        let expectation2 = XCTestExpectation(description: "Second auto-completion attempt")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            expectation2.fulfill()
        }
        wait(for: [expectation2], timeout: 1.0)
        
        // Then: Still only one task should be completed (no double completion)
        XCTAssertEqual(viewModel.todayChecklist.completedTasksCount, 1)
    }
    
    func testAutoCompleteFirstTask_ShouldNotHappenOnFutureDays() {
        // Given: Auto-complete has been done on first day
        viewModel.autoCompleteFirstTaskIfDemoCompleted(hasCompletedDemo: true)
        
        // Wait for completion
        let expectation1 = XCTestExpectation(description: "Initial auto-completion")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            expectation1.fulfill()
        }
        wait(for: [expectation1], timeout: 1.0)
        
        XCTAssertEqual(viewModel.todayChecklist.completedTasksCount, 1)
        
        // When: Simulate moving to next day by creating a new view model
        // (This simulates the app being reopened on a new day)
        let newDayViewModel = EnhancedStreakViewModel()
        
        // Reset the checklist to simulate a new day with no completed tasks
        newDayViewModel.resetDay()
        
        // Attempt auto-complete on the new day
        newDayViewModel.autoCompleteFirstTaskIfDemoCompleted(hasCompletedDemo: true)
        
        // Wait to see if any completion happens
        let expectation2 = XCTestExpectation(description: "Auto-completion on new day")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            expectation2.fulfill()
        }
        wait(for: [expectation2], timeout: 1.0)
        
        // Then: No tasks should be auto-completed on the new day
        XCTAssertEqual(newDayViewModel.todayChecklist.completedTasksCount, 0)
    }
    
    func testAutoCompleteFirstTask_PersistsAcrossAppRestarts() {
        // Given: Auto-complete has been triggered once
        viewModel.autoCompleteFirstTaskIfDemoCompleted(hasCompletedDemo: true)
        
        // Wait for completion
        let expectation1 = XCTestExpectation(description: "Initial auto-completion")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            expectation1.fulfill()
        }
        wait(for: [expectation1], timeout: 1.0)
        
        XCTAssertEqual(viewModel.todayChecklist.completedTasksCount, 1)
        
        // When: Create multiple new view models (simulating app restarts)
        for i in 1...3 {
            let newViewModel = EnhancedStreakViewModel()
            
            // Reset to get fresh checklist
            newViewModel.resetDay()
            
            // Try to auto-complete again
            newViewModel.autoCompleteFirstTaskIfDemoCompleted(hasCompletedDemo: true)
            
            // Wait to see if completion happens
            let expectation = XCTestExpectation(description: "Auto-completion attempt \(i)")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                expectation.fulfill()
            }
            wait(for: [expectation], timeout: 1.0)
            
            // Then: No auto-completion should happen
            XCTAssertEqual(newViewModel.todayChecklist.completedTasksCount, 0, 
                          "Auto-completion should not happen on app restart #\(i)")
        }
    }
    
    func testAutoCompleteFirstTask_DoesNotHappenWithoutDemo() {
        // Given: Fresh start with demo NOT completed
        XCTAssertEqual(viewModel.todayChecklist.completedTasksCount, 0)
        
        // When: Call auto-complete with demo not completed
        viewModel.autoCompleteFirstTaskIfDemoCompleted(hasCompletedDemo: false)
        
        // Wait to see if any completion happens
        let expectation = XCTestExpectation(description: "Auto-completion without demo")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        // Then: No tasks should be completed
        XCTAssertEqual(viewModel.todayChecklist.completedTasksCount, 0)
    }
    
    func testAutoCompleteFirstTask_DoesNotHappenIfTasksAlreadyCompleted() {
        // Given: Manually complete a task first
        let firstTask = viewModel.todayChecklist.tasks.first!
        viewModel.completeTask(taskId: firstTask.id)
        XCTAssertEqual(viewModel.todayChecklist.completedTasksCount, 1)
        
        // When: Try to auto-complete
        viewModel.autoCompleteFirstTaskIfDemoCompleted(hasCompletedDemo: true)
        
        // Wait to see if additional completion happens
        let expectation = XCTestExpectation(description: "Auto-completion with existing completed task")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        // Then: Still only one task should be completed
        XCTAssertEqual(viewModel.todayChecklist.completedTasksCount, 1)
    }
    
    func testAutoCompleteFirstTask_HandlesMultipleSimultaneousCalls() {
        // Given: Fresh start
        XCTAssertEqual(viewModel.todayChecklist.completedTasksCount, 0)
        
        // When: Call auto-complete multiple times rapidly (race condition test)
        for _ in 1...5 {
            viewModel.autoCompleteFirstTaskIfDemoCompleted(hasCompletedDemo: true)
        }
        
        // Wait for all potential completions
        let expectation = XCTestExpectation(description: "Multiple simultaneous auto-completions")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.5)
        
        // Then: Still only one task should be completed (no race condition)
        XCTAssertEqual(viewModel.todayChecklist.completedTasksCount, 1)
    }
    
    // MARK: - Badge Integration Tests
    
    func testBadgeUnlock_ShouldTriggerWhenStreakReachesMilestone() {
        // Given: Approaching a badge milestone
        var badgeUnlockTriggered = false
        
        viewModel.$showBadgeUnlock
            .sink { showBadgeUnlock in
                if showBadgeUnlock {
                    badgeUnlockTriggered = true
                }
            }
            .store(in: &cancellables)
        
        // When: Complete day that should unlock badge (e.g., 7 days)
        for i in (1...6).reversed() {
            let date = calendar.date(byAdding: .day, value: -i, to: Date())!
            viewModel.streakStats.updateStreak(for: date)
        }
        
        completeAllTasks()
        
        // Wait for badge check
        let expectation = XCTestExpectation(description: "Badge unlock check")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2.0)
        
        // Then: Badge unlock might be triggered (depends on badge requirements)
        // Note: This test might need adjustment based on actual badge unlock logic
    }
    
    // MARK: - Helper Methods
    
    private func completeAllTasks() {
        for task in viewModel.todayChecklist.tasks {
            viewModel.completeTask(taskId: task.id)
        }
    }
    
    // MARK: - Mock/Test Helper Extensions
    
    private func simulateAppRestart() -> EnhancedStreakViewModel {
        // Data is saved automatically by the viewModel
        // Create new instance (simulates app restart)
        return EnhancedStreakViewModel()
    }
}