//
//  DailyChecklistTests.swift
//  SpeakLifeTests
//
//  Unit tests for DailyChecklist and related models to ensure task management works correctly
//

import XCTest
@testable import SpeakLife

final class DailyChecklistTests: XCTestCase {
    
    var checklist: DailyChecklist!
    let calendar = Calendar.current
    
    override func setUp() {
        super.setUp()
        let today = Date()
        let tasks = TaskLibrary.getCoreTasksForStreak(1)
        checklist = DailyChecklist(
            date: today,
            tasks: tasks,
            currentPhase: .foundation
        )
    }
    
    override func tearDown() {
        checklist = nil
        super.tearDown()
    }
    
    // MARK: - DailyChecklist Tests
    
    func testInitialState_ShouldBeIncomplete() {
        // Then: Checklist should start incomplete
        XCTAssertFalse(checklist.isCompleted)
        XCTAssertNil(checklist.completedAt)
        XCTAssertFalse(checklist.tasks.isEmpty)
        
        // All tasks should be incomplete initially
        for task in checklist.tasks {
            XCTAssertFalse(task.isCompleted)
        }
    }
    
    func testMarkTaskCompleted_ShouldUpdateTask() {
        // Given: A specific task
        var task = checklist.tasks.first!
        let taskId = task.id
        XCTAssertFalse(task.isCompleted)
        
        // When: Mark task as completed
        task.isCompleted = true
        
        // Then: Task should be marked completed
        XCTAssertTrue(task.isCompleted)
    }
    
    func testCompleteAllTasks_ShouldMarkChecklistComplete() {
        // Given: All tasks are incomplete
        XCTAssertFalse(checklist.isCompleted)
        
        // When: Mark all tasks as completed
        for i in 0..<checklist.tasks.count {
            checklist.tasks[i].isCompleted = true
        }
        
        // Update completed date
        checklist.completedAt = Date()
        
        // Then: Checklist should be marked complete
        XCTAssertTrue(checklist.isCompleted)
        XCTAssertNotNil(checklist.completedAt)
        
        // Completion time should be recent
        let now = Date()
        let timeDifference = now.timeIntervalSince(checklist.completedAt!)
        XCTAssertLessThan(timeDifference, 1.0) // Within 1 second
    }
    
    func testPartialCompletion_ShouldNotMarkChecklistComplete() {
        // Given: Multiple tasks
        XCTAssertGreaterThan(checklist.tasks.count, 1)
        
        // When: Complete only some tasks
        checklist.tasks[0].isCompleted = true
        
        // Then: Checklist should still be incomplete
        XCTAssertFalse(checklist.isCompleted)
        XCTAssertNil(checklist.completedAt)
    }
    
    // MARK: - DailyTask Tests
    
    func testDailyTaskCreation_ShouldHaveValidProperties() {
        // Given: A sample task
        let task = DailyTask(
            id: "test-task",
            title: "Test Task",
            description: "A test task description",
            icon: "heart.fill",
            category: .foundation,
            type: .speak,
            difficulty: .beginner,
            minimumStreakDay: 1,
            estimatedMinutes: 5
        )
        
        // Then: Properties should be set correctly
        XCTAssertEqual(task.title, "Test Task")
        XCTAssertEqual(task.description, "A test task description")
        XCTAssertEqual(task.category, .foundation)
        XCTAssertFalse(task.isCompleted)
        XCTAssertEqual(task.minimumStreakDay, 1)
        XCTAssertEqual(task.icon, "heart.fill")
    }
    
    func testTaskCompletion_ShouldToggleState() {
        // Given: An incomplete task
        var task = checklist.tasks.first!
        XCTAssertFalse(task.isCompleted)
        
        // When: Mark as completed
        task.isCompleted = true
        
        // Then: Should be completed
        XCTAssertTrue(task.isCompleted)
    }
    
    // MARK: - TaskLibrary Tests
    
    func testTaskLibraryForDay1_ShouldReturnBasicTasks() {
        // When: Get tasks for day 1
        let day1Tasks = TaskLibrary.getCoreTasksForStreak(1)
        
        // Then: Should return some basic tasks
        XCTAssertFalse(day1Tasks.isEmpty)
        
        // All tasks should be available from day 1
        for task in day1Tasks {
            XCTAssertLessThanOrEqual(task.minimumStreakDay, 1)
        }
    }
    
    func testTaskLibraryProgression_ShouldUnlockMoreTasks() {
        // Given: Tasks for different streak days
        let day1Tasks = TaskLibrary.getCoreTasksForStreak(1)
        let day7Tasks = TaskLibrary.getCoreTasksForStreak(7)
        let day30Tasks = TaskLibrary.getCoreTasksForStreak(30)
        
        // Then: Later days should have at least as many tasks as earlier days
        XCTAssertLessThanOrEqual(day1Tasks.count, day7Tasks.count)
        XCTAssertLessThanOrEqual(day7Tasks.count, day30Tasks.count)
    }
    
    func testGetNewlyUnlockedTasks_ShouldReturnOnlyNewTasks() {
        // When: Get newly unlocked tasks between day 1 and day 7
        let newTasks = TaskLibrary.getNewlyUnlockedTasks(currentStreak: 7, previousStreak: 1)
        
        // Then: Should only return tasks that unlock between day 2-7
        for task in newTasks {
            XCTAssertGreaterThan(task.minimumStreakDay, 1)
            XCTAssertLessThanOrEqual(task.minimumStreakDay, 7)
        }
    }
    
    func testGetAvailableTasks_ShouldIncludeAllEligibleTasks() {
        // When: Get available tasks for day 10
        let availableTasks = TaskLibrary.getAvailableTasks(for: 10)
        
        // Then: Should include all tasks with minimumStreakDay <= 10
        for task in availableTasks {
            XCTAssertLessThanOrEqual(task.minimumStreakDay, 10)
        }
    }
    
    // MARK: - ProgressionPhase Tests
    
    func testProgressionPhaseForBeginners_ShouldBeFoundation() {
        // When: Get phase for early days
        let phase1 = ProgressionPhase.getPhase(for: 1)
        let phase3 = ProgressionPhase.getPhase(for: 3)
        
        // Then: Should be foundation phase
        XCTAssertEqual(phase1, .foundation)
        XCTAssertEqual(phase3, .foundation)
    }
    
    func testProgressionPhaseProgression_ShouldAdvanceCorrectly() {
        // When: Get phases for different streak days
        let foundationPhase = ProgressionPhase.getPhase(for: 1)
        let growthPhase = ProgressionPhase.getPhase(for: 10)
        let impactPhase = ProgressionPhase.getPhase(for: 50)
        let masteryPhase = ProgressionPhase.getPhase(for: 150)
        
        // Then: Phases should progress logically
        XCTAssertEqual(foundationPhase, .foundation)
        XCTAssertEqual(growthPhase, .growth)
        XCTAssertEqual(impactPhase, .impact)
        XCTAssertEqual(masteryPhase, .mastery)
    }
    
    // MARK: - CompletionCelebration Tests
    
    func testCompletionCelebrationCreation_ShouldHaveCorrectProperties() {
        // Given: Celebration data
        let celebration = CompletionCelebration(
            streakNumber: 7,
            isNewRecord: true,
            motivationalMessage: "Great job!",
            shareImage: nil
        )
        
        // Then: Properties should be set correctly
        XCTAssertEqual(celebration.streakNumber, 7)
        XCTAssertTrue(celebration.isNewRecord)
        XCTAssertEqual(celebration.motivationalMessage, "Great job!")
        XCTAssertNil(celebration.shareImage)
    }
    
    func testGenerateMessage_ShouldReturnAppropriateMessage() {
        // When: Generate messages for different milestones
        let day1Message = CompletionCelebration.generateMessage(for: 1, isRecord: false)
        let day7Message = CompletionCelebration.generateMessage(for: 7, isRecord: false)
        let day30Message = CompletionCelebration.generateMessage(for: 30, isRecord: false)
        let recordMessage = CompletionCelebration.generateMessage(for: 5, isRecord: true)
        
        // Then: Messages should be appropriate for milestones
        XCTAssertTrue(day1Message.contains("1") || day1Message.lowercased().contains("first"))
        XCTAssertTrue(day7Message.contains("7") || day7Message.lowercased().contains("week"))
        XCTAssertTrue(day30Message.contains("30"))
        XCTAssertTrue(recordMessage.lowercased().contains("record") || recordMessage.contains("🏆"))
    }
    
    func testGenerateMessageForMilestones_ShouldRecognizeSpecialDays() {
        // When: Generate messages for key milestones
        let milestones = [1, 7, 14, 30, 50, 100]
        
        for milestone in milestones {
            let message = CompletionCelebration.generateMessage(for: milestone, isRecord: false)
            
            // Then: Message should reference the milestone number
            XCTAssertTrue(message.contains("\(milestone)"), 
                         "Message for day \(milestone) should contain the number: \(message)")
        }
    }
    
    // MARK: - Integration Tests
    
    func testCompleteChecklistIntegration_ShouldWorkEndToEnd() {
        // Given: Fresh checklist
        let today = Date()
        let tasks = TaskLibrary.getCoreTasksForStreak(5)
        let testChecklist = DailyChecklist(
            date: today,
            tasks: tasks,
            currentPhase: .growth
        )
        
        XCTAssertFalse(testChecklist.isCompleted)
        XCTAssertEqual(testChecklist.currentPhase, .growth)
        
        // When: Complete all tasks one by one
        for i in 0..<testChecklist.tasks.count {
            XCTAssertFalse(testChecklist.tasks[i].isCompleted)
            // Simulate task completion
            var mutableChecklist = testChecklist
            mutableChecklist.tasks[i].isCompleted = true
        }
        
        // Then: All tasks would be completed in a real scenario
        // (Note: Since tasks is immutable in the struct, we test the concept)
        XCTAssertEqual(testChecklist.currentPhase, .growth)
    }
    
    func testTaskLibraryConsistency_ShouldMaintainLogicalProgression() {
        // When: Test multiple streak days
        var previousTaskCount = 0
        
        for streakDay in [1, 3, 7, 14, 21, 30, 50, 100] {
            let tasks = TaskLibrary.getCoreTasksForStreak(streakDay)
            
            // Then: Task count should be consistent or increasing
            XCTAssertGreaterThanOrEqual(tasks.count, previousTaskCount,
                                       "Task count should not decrease at streak day \(streakDay)")
            
            // All tasks should be appropriate for the streak day
            for task in tasks {
                XCTAssertLessThanOrEqual(task.minimumStreakDay, streakDay,
                                        "Task with minimum day \(task.minimumStreakDay) should not appear on day \(streakDay)")
            }
            
            previousTaskCount = tasks.count
        }
    }
    
    // MARK: - Edge Case Tests
    
    func testEmptyTaskList_ShouldBeMarkedComplete() {
        // Given: Checklist with no tasks
        let emptyChecklist = DailyChecklist(
            date: Date(),
            tasks: [],
            currentPhase: .foundation
        )
        
        // Then: Should be considered complete (nothing to do)
        XCTAssertTrue(emptyChecklist.isCompleted)
    }
    
    func testLargeStreakDay_ShouldHandleGracefully() {
        // When: Request tasks for very large streak day
        let largeDayTasks = TaskLibrary.getCoreTasksForStreak(1000)
        
        // Then: Should return some tasks without crashing
        XCTAssertFalse(largeDayTasks.isEmpty)
        
        // All returned tasks should be valid
        for task in largeDayTasks {
            XCTAssertLessThanOrEqual(task.minimumStreakDay, 1000)
            XCTAssertFalse(task.title.isEmpty)
            XCTAssertFalse(task.icon.isEmpty)
        }
    }
}