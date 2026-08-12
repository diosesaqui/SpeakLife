//
//  EnhancedStreakViewModelTests.swift
//  SpeakLifeTests
//
//  Unit tests for EnhancedStreakViewModel to ensure streak management and celebration logic works correctly
//

import XCTest
import Combine
@testable import SpeakLife

// MARK: - Waiting without sleeping

/// Two ways to wait that do not depend on a shared CI runner keeping time.
///
/// The pattern these replace was everywhere in this suite: create an
/// `XCTestExpectation`, fulfil it from `DispatchQueue.main.asyncAfter(0.6)`,
/// and `wait(for:timeout: 1.0)`. The expectation was never attached to the
/// thing under test — it was a sleep with a stopwatch on it, and the stopwatch
/// allowed 0.4s of slack.
///
/// That is not enough slack on a loaded macOS runner. Production schedules its
/// own `asyncAfter(0.5)` on the main queue and the test's timer queues behind
/// it, so the two delays serialise into the 1.0s budget with the view model's
/// work in between. `testAutoCompleteFirstTask_ShouldNotHappenOnFutureDays`
/// and `testHandlePersistentStoreRemoteChangeNotification` both went red on
/// main this way while passing locally. Nine more tests carried the same fuse
/// unlit.
///
/// Defined on `XCTestCase` rather than on one class so the whole test module
/// can use it — `SyncConflictResolverTests` needs it too.
extension XCTestCase {

    /// Spins the main run loop until `condition` holds, then returns at once.
    ///
    /// Fast when the machine is fast — it returns on the first poll that
    /// passes, not after a fixed sleep — and patient when the machine is
    /// loaded. The timeout is generous because it only ever costs anything on
    /// a genuine failure.
    func waitUntil(_ description: String,
                   timeout: TimeInterval = 10,
                   file: StaticString = #filePath,
                   line: UInt = #line,
                   _ condition: () -> Bool) {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() {
            guard Date() < deadline else {
                XCTFail("Timed out after \(timeout)s waiting for: \(description)",
                        file: file, line: line)
                return
            }
            // Running the main run loop is what lets main-queue work — the
            // `asyncAfter` production schedules — actually execute.
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.01))
        }
    }

    /// Lets scheduled main-queue work run for a fixed window, then returns.
    ///
    /// For asserting that something did NOT happen, which cannot be expressed
    /// as waiting for a condition. Unlike the old pattern there is no timeout
    /// racing the delay, so a slow runner makes this late rather than failed.
    func drainMainQueue(for interval: TimeInterval) {
        let deadline = Date().addingTimeInterval(interval)
        while Date() < deadline {
            RunLoop.current.run(mode: .default, before: deadline)
        }
    }

    /// `waitUntil` for `async` tests.
    ///
    /// The same bet as the sleep-expectations, spelled differently and just as
    /// lossy: `try await Task.sleep(nanoseconds: 300_000_000)` followed by an
    /// assertion is a 0.3s wager that the work finished. When it doesn't, the
    /// failure is not a timeout — it is the assertion itself going off early,
    /// which is why `testToggleAudioFavorite` reported a bare "XCTAssertTrue
    /// failed" and read like a logic bug rather than a slow machine.
    ///
    /// Polls in short naps so a fast machine pays almost nothing.
    func waitUntil(_ description: String,
                   timeout: TimeInterval = 10,
                   file: StaticString = #filePath,
                   line: UInt = #line,
                   _ condition: () -> Bool) async {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() {
            guard Date() < deadline else {
                XCTFail("Timed out after \(timeout)s waiting for: \(description)",
                        file: file, line: line)
                return
            }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
    }
}

final class EnhancedStreakViewModelTests: XCTestCase {
    
    var viewModel: EnhancedStreakViewModel!
    var cancellables: Set<AnyCancellable>!
    var savedCompletions: [BurstCompletion] = []
    let calendar = Calendar.current

    override func setUp() {
        super.setUp()
        cancellables = Set<AnyCancellable>()

        // Clearing UserDefaults is not enough on its own.
        //
        // `EnhancedStreakViewModel.init` calls `reconcileWithSyncedProgress`,
        // which raises `currentStreak` to `BurstCompletionTracker.shared`'s if
        // that one is higher. The tracker is a process-wide singleton holding
        // its history in memory, so whatever an earlier suite left in it walks
        // straight into these tests — including `testInitialState`, which
        // expects a streak of zero. Empty it here and hand it back in tearDown,
        // the same way StreakFreezeTests and StreakBreakNotificationTests do.
        savedCompletions = BurstCompletionTracker.shared.completions
        BurstCompletionTracker.shared.completions = []

        UserDefaults.standard.removeObject(forKey: "dailyChecklist")
        UserDefaults.standard.removeObject(forKey: "streakStats")
        UserDefaults.standard.removeObject(forKey: "hasAutoCompletedFirstTask")
        purgeSyncedTaskCompletions()

        viewModel = EnhancedStreakViewModel()
    }

    override func tearDown() {
        cancellables = nil
        viewModel = nil

        BurstCompletionTracker.shared.completions = savedCompletions

        // Clean up UserDefaults
        UserDefaults.standard.removeObject(forKey: "dailyChecklist")
        UserDefaults.standard.removeObject(forKey: "streakStats")
        UserDefaults.standard.removeObject(forKey: "hasAutoCompletedFirstTask")
        purgeSyncedTaskCompletions()

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
        // Given: A task in the checklist that a user can actually tick
        let task = firstCompletableTask
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
        
        // Then: the day is earned and the streak moves.
        //
        // Asserted through `isStreakEarned`, not `isCompleted`. `isCompleted`
        // is allSatisfy over every row, and the declaration and Guarding rows
        // are earned by speaking rather than by ticking — `completeTask`
        // refuses both — so once either is present no loop over `completeTask`
        // can ever make it true. The Burst alone gates the streak, which is
        // what "day completion" means here and what this test is named for.
        XCTAssertTrue(viewModel.todayChecklist.isStreakEarned)
        XCTAssertNotNil(viewModel.todayChecklist.completedAt)
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
        
        // Then: Celebration should be triggered
        waitUntil("the completion celebration to fire") { celebrationTriggered }
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
        
        // Then: Celebration should reflect 7-day milestone
        waitUntil("the milestone celebration data to arrive") {
            self.viewModel.celebrationData != nil
        }
        XCTAssertNotNil(viewModel.celebrationData)
        XCTAssertEqual(viewModel.celebrationData?.streakNumber, 7)
        XCTAssertTrue((viewModel.celebrationData?.motivationalMessage.contains("7") ?? false) || 
                      (viewModel.celebrationData?.motivationalMessage.contains("WEEK") ?? false))
    }
    
    /// A new personal record set ON a milestone day is marked in the celebration.
    ///
    /// This used to build to day 4 and expect a celebration, which it can never
    /// get: `celebrationMilestones` is [1, 3, 7, 14, 30, 50, 100, 200, 365] and
    /// `completeDay()` only builds `celebrationData` on a milestone, on purpose.
    /// It also pre-walked the streak all the way to 4 with `updateStreak`, which
    /// pins `longestStreak` to `currentStreak` as it goes — so by the time
    /// `completeDay()` captured the previous record it was already 4, and
    /// `isNewRecord` would have been false even had a celebration existed.
    ///
    /// Day 3 is the first milestone that can carry a record: walk to 2, leave
    /// the old record at 2, and let today's completion be the one that beats it.
    func testNewRecord_ShouldBeMarkedInCelebration() {
        let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: Date())!
        let yesterday = calendar.date(byAdding: .day, value: -1, to: Date())!
        viewModel.streakStats.updateStreak(for: twoDaysAgo)
        viewModel.streakStats.updateStreak(for: yesterday)
        XCTAssertEqual(viewModel.streakStats.currentStreak, 2, "precondition")
        XCTAssertEqual(viewModel.streakStats.longestStreak, 2, "precondition")

        // `completeDay()` builds celebrationData synchronously, so there is
        // nothing to wait for. The 2.5s wait this test used to open was for
        // `showCompletionCelebration`, which flips after the fire animation and
        // is not what is asserted below.
        completeAllTasks()

        XCTAssertEqual(viewModel.streakStats.currentStreak, 3)
        XCTAssertNotNil(viewModel.celebrationData)
        XCTAssertEqual(viewModel.celebrationData?.streakNumber, 3)
        XCTAssertTrue(viewModel.celebrationData?.isNewRecord ?? false,
                      "day 3 beat the previous record of 2")
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
        let taskToComplete = firstCompletableTask
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
        waitUntil("the Burst to auto-complete") {
            self.viewModel.todayChecklist.completedTasksCount == 1
        }

        // Then: the Burst should be completed. `autoCompleteFirstTaskIfDemoCompleted`
        // targets "complete_daily_burst" by id — the demo IS the Burst — and
        // not whichever row happens to sit first.
        let burst = viewModel.todayChecklist.tasks.first { $0.id == "complete_daily_burst" }
        XCTAssertTrue(burst?.isCompleted ?? false)

        // When: Call auto-complete again (simulating view re-appearing)
        viewModel.autoCompleteFirstTaskIfDemoCompleted(hasCompletedDemo: true)

        // Then: Still only one task should be completed (no double completion)
        drainMainQueue(for: 1.0)
        XCTAssertEqual(viewModel.todayChecklist.completedTasksCount, 1)
    }
    
    func testAutoCompleteFirstTask_ShouldNotHappenOnFutureDays() {
        // Given: Auto-complete has been done on first day
        viewModel.autoCompleteFirstTaskIfDemoCompleted(hasCompletedDemo: true)
        waitUntil("the first day's Burst to auto-complete") {
            self.viewModel.todayChecklist.completedTasksCount == 1
        }

        // When: Simulate moving to next day by creating a new view model
        // (This simulates the app being reopened on a new day)
        let newDayViewModel = EnhancedStreakViewModel()

        // Reset the checklist to simulate a new day with no completed tasks
        newDayViewModel.resetDay()

        // Attempt auto-complete on the new day
        newDayViewModel.autoCompleteFirstTaskIfDemoCompleted(hasCompletedDemo: true)

        // Then: nothing is auto-completed on the new day.
        //
        // A negative cannot be waited FOR, so this gives the production
        // `asyncAfter(0.5)` more than enough room to fire and then checks that
        // it did not. Comfortably clear of 0.5 without racing a timeout.
        drainMainQueue(for: 1.0)
        XCTAssertEqual(newDayViewModel.todayChecklist.completedTasksCount, 0)
    }
    
    func testAutoCompleteFirstTask_PersistsAcrossAppRestarts() {
        // Given: Auto-complete has been triggered once
        viewModel.autoCompleteFirstTaskIfDemoCompleted(hasCompletedDemo: true)
        waitUntil("the Burst to auto-complete") {
            self.viewModel.todayChecklist.completedTasksCount == 1
        }

        // When: Create multiple new view models (simulating app restarts)
        for i in 1...3 {
            let newViewModel = EnhancedStreakViewModel()
            
            // Reset to get fresh checklist
            newViewModel.resetDay()
            
            // Try to auto-complete again
            newViewModel.autoCompleteFirstTaskIfDemoCompleted(hasCompletedDemo: true)
            
            // Then: No auto-completion should happen
            drainMainQueue(for: 1.0)
            XCTAssertEqual(newViewModel.todayChecklist.completedTasksCount, 0, 
                          "Auto-completion should not happen on app restart #\(i)")
        }
    }
    
    func testAutoCompleteFirstTask_DoesNotHappenWithoutDemo() {
        // Given: Fresh start with demo NOT completed
        XCTAssertEqual(viewModel.todayChecklist.completedTasksCount, 0)
        
        // When: Call auto-complete with demo not completed
        viewModel.autoCompleteFirstTaskIfDemoCompleted(hasCompletedDemo: false)
        
        // Then: No tasks should be completed
        drainMainQueue(for: 1.0)
        XCTAssertEqual(viewModel.todayChecklist.completedTasksCount, 0)
    }
    
    func testAutoCompleteFirstTask_DoesNotHappenIfTasksAlreadyCompleted() {
        // Given: Manually complete a task first
        viewModel.completeTask(taskId: firstCompletableTask.id)
        XCTAssertEqual(viewModel.todayChecklist.completedTasksCount, 1)
        
        // When: Try to auto-complete
        viewModel.autoCompleteFirstTaskIfDemoCompleted(hasCompletedDemo: true)
        
        drainMainQueue(for: 1.0)
        
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
        
        // Then: Still only one task should be completed (no race condition).
        // Five calls each schedule at most one `asyncAfter(0.5)`, so this window
        // clears all of them before the count is checked.
        drainMainQueue(for: 1.5)
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
        
        // Then: Badge unlock might be triggered (depends on badge requirements)
        //
        // This test asserts nothing — `badgeUnlockTriggered` is collected and
        // never read, because the popup is scheduled behind delays that nest to
        // eight seconds and depend on whether a celebration is already showing.
        // It is kept as a crash check: the badge path runs, and running it must
        // not blow up. Draining the queue is what exercises it.
        drainMainQueue(for: 1.5)
        _ = badgeUnlockTriggered
    }
    
    // MARK: - Helper Methods
    
    private func completeAllTasks() {
        for task in viewModel.todayChecklist.tasks {
            viewModel.completeTask(taskId: task.id)
        }
    }

    /// The first row a user can actually tick.
    ///
    /// Not `tasks.first`. `completeTask` refuses the personal-declaration and
    /// Guarding rows by design — both are derived from elsewhere, so ticking
    /// them by hand would record ground the user never took — and the
    /// declaration row is inserted at index 0 when the user carries one. So
    /// targeting position silently no-ops, and the test reads as "completing a
    /// task does nothing".
    ///
    /// Production already learned this: `autoCompleteFirstTaskIfDemoCompleted`
    /// carries the note "The Burst by id, not whatever happens to be first."
    /// These tests had not.

    /// Clears today's synced task-completion rows.
    ///
    /// `completeTask` mirrors every bonus task to `ProgressSyncStore.shared` as
    /// a `taskCompletion` event keyed `<dayStamp>|<taskId>`, and that store is
    /// backed by the app's real on-disk SQLite store on the simulator — not by
    /// anything this suite owns. The rows outlive the test, the suite, and the
    /// run, so a day's worth of test runs piles up completions stamped with
    /// today's date. A fresh view model then replays them onto today's
    /// checklist through `applySyncedTaskCompletions`, and a test that
    /// completed exactly one task counts three.
    ///
    /// Run before the view model is built, so it cannot read what earlier runs
    /// left, and again on the way out so the next suite starts clean.
    private func purgeSyncedTaskCompletions() {
        let store = ProgressSyncStore.shared

        // These two are NOT the sleep-with-a-stopwatch pattern — each waits on a
        // real completion handler from `ProgressSyncStore`, which is the right
        // shape. Their timeouts are simply too tight for a struggling runner:
        // `testCompleteTask_ShouldUpdateChecklist` went red on main with
        // "Exceeded timeout of 5 seconds, unfulfilled: read taskCompletion
        // events" on a run where the simulator also failed to launch outright
        // and the test phase took 616 seconds.
        //
        // A correct expectation costs nothing extra by being patient: it is
        // signalled the instant the callback fires, so the only thing a larger
        // number changes is how long a genuine hang takes to report.
        let fetched = expectation(description: "read taskCompletion events")
        var keys: [String] = []
        store.events(ofKind: ProgressSyncStore.Kind.taskCompletion) { events in
            keys = events.map(\.key)
            fetched.fulfill()
        }
        wait(for: [fetched], timeout: 30)

        guard !keys.isEmpty else { return }
        let deleted = expectation(description: "delete taskCompletion events")
        deleted.expectedFulfillmentCount = keys.count
        for key in keys {
            store.deleteEvent(kind: ProgressSyncStore.Kind.taskCompletion, key: key) { _ in
                deleted.fulfill()
            }
        }
        wait(for: [deleted], timeout: 60)
    }

    private var firstCompletableTask: DailyTask {
        // The Burst is on every checklist, so this always finds something.
        viewModel.todayChecklist.tasks.first {
            $0.id != TaskLibrary.personalDeclarationTaskId && $0.id != TaskLibrary.guardTaskId
        }!
    }

    
    // MARK: - Mock/Test Helper Extensions
    
    private func simulateAppRestart() -> EnhancedStreakViewModel {
        // Data is saved automatically by the viewModel
        // Create new instance (simulates app restart)
        return EnhancedStreakViewModel()
    }
}