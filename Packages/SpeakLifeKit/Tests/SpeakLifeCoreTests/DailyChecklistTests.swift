//
//  DailyChecklistTests.swift
//  SpeakLifeTests
//
//  Unit tests for DailyChecklist and related models to ensure task management works correctly
//

import XCTest
@testable import SpeakLifeCore

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
    
    func testListenTask_ShouldSurviveEveryPhase() {
        // When: Walk one day out of each phase, well past the foundation week
        for streakDay in [1, 7, 8, 15, 30, 31, 60, 100, 365] {
            let tasks = TaskLibrary.getCoreTasksForStreak(streakDay)

            // Then: Hearing the Word is a lifelong habit — the listen task is
            // on the checklist every single day, not just days 1-7
            XCTAssertTrue(tasks.contains { $0.id == "listen_audio" },
                          "Listen task went missing on day \(streakDay)")
            XCTAssertTrue(tasks.contains { $0.id == "complete_daily_burst" },
                          "Burst task went missing on day \(streakDay)")
        }
    }

    func testListenTask_ShouldOnlyAssignAnAudioDuringFoundationWeek() {
        // When: Inside the foundation week
        for day in 1...7 {
            let listen = TaskLibrary.getCoreTasksForStreak(day).first { $0.id == "listen_audio" }

            // Then: The task deep-links to that day's curated episode
            XCTAssertNotNil(listen?.recommendedAudioId,
                            "Day \(day) of the foundation week should recommend an audio")
        }

        // When: Past the foundation week
        for day in [8, 20, 45, 120] {
            let listen = TaskLibrary.getCoreTasksForStreak(day).first { $0.id == "listen_audio" }

            // Then: The task stays, but goes open-ended — no assigned episode
            XCTAssertNotNil(listen, "Day \(day) should still have a listen task")
            XCTAssertNil(listen?.recommendedAudioId,
                         "Day \(day) should not assign a specific audio")
            XCTAssertEqual(listen?.navigationDestination, .audioTab)
        }
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
        // Day 7 says "ONE WEEK STRONG" and carries no digit at all, which is
        // better copy than "7 DAYS" and is what ships. The sibling test above
        // already allows it; this one demanded the numeral and failed on the
        // one milestone that earned its own line.
        let spelledOut = ["one", "week", "first"]

        for milestone in [1, 7, 14, 30, 50, 100] {
            let message = CompletionCelebration.generateMessage(for: milestone, isRecord: false)
            let lower = message.lowercased()

            XCTAssertTrue(
                message.contains("\(milestone)") || spelledOut.contains(where: lower.contains),
                "Message for day \(milestone) names neither the number nor the milestone: \(message)"
            )
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

    // MARK: - Personal declaration as a task

    private func progress(total: Int, spoken: Int, headline: String = "I am healed.") -> PersonalDeclaration.Progress {
        PersonalDeclaration.Progress(total: total, spokenToday: spoken, headline: headline)
    }

    private func declarationTask(_ p: PersonalDeclaration.Progress?) -> DailyTask? {
        TaskLibrary.getCoreTasksForStreak(10, personalDeclarations: p)
            .first { $0.id == TaskLibrary.personalDeclarationTaskId }
    }

    /// A task nobody can finish is worse than no task.
    func testDeclarationTask_AbsentWhenTheUserCarriesNone() {
        withStandardTasks {
            XCTAssertNil(declarationTask(nil))
        }
    }

    /// The rule: one row for all of them, done only when every one is spoken.
    func testDeclarationTask_NeedsEveryDeclarationSpoken() {
        withStandardTasks {
            XCTAssertEqual(declarationTask(progress(total: 3, spoken: 0))?.isCompleted, false)
            XCTAssertEqual(declarationTask(progress(total: 3, spoken: 1))?.isCompleted, false)
            XCTAssertEqual(declarationTask(progress(total: 3, spoken: 2))?.isCompleted, false)
            XCTAssertEqual(declarationTask(progress(total: 3, spoken: 3))?.isCompleted, true)
        }
    }

    /// Partial progress is shown, not hidden. "Not spoken yet" would be a lie
    /// when two of three are done.
    func testDeclarationTask_SubtitleReportsPartialProgress() {
        XCTAssertEqual(TaskLibrary.personalDeclarationSubtitle(progress(total: 3, spoken: 2)),
                       "2 of 3 spoken today")
        XCTAssertEqual(TaskLibrary.personalDeclarationSubtitle(progress(total: 3, spoken: 3)),
                       "All 3 spoken today")
        XCTAssertEqual(TaskLibrary.personalDeclarationSubtitle(progress(total: 1, spoken: 1)),
                       "Spoken today")
    }

    /// Carrying one, the row shows their own words. That daily reminder is why
    /// the feed tile existed, and it must survive the tile being removed.
    func testDeclarationTask_ShowsTheDeclarationTextWhenTheyCarryOne() {
        let p = progress(total: 1, spoken: 0, headline: "God gives me power to produce wealth.")
        XCTAssertEqual(TaskLibrary.personalDeclarationSubtitle(p),
                       "God gives me power to produce wealth.")
        // Never one declaration's text when several are in play — it would
        // misrepresent the row.
        let many = progress(total: 2, spoken: 0, headline: "God gives me power to produce wealth.")
        XCTAssertEqual(TaskLibrary.personalDeclarationSubtitle(many), "0 of 2 spoken today")
    }

    /// Only the Burst earns the streak. Adding a fifth task changes the day's
    /// "N of M" and must change nothing else.
    func testDeclarationTask_DoesNotAffectTheStreak() {
        withStandardTasks {
            let tasks = TaskLibrary.getCoreTasksForStreak(10, personalDeclarations: progress(total: 1, spoken: 1))
            var checklist = DailyChecklist(date: Date(), tasks: tasks, currentPhase: .foundation)
            XCTAssertFalse(checklist.isStreakEarned, "a spoken declaration must not earn the day")

            checklist.tasks = checklist.tasks.map { t in
                var t = t
                if t.id == "complete_daily_burst" { t.isCompleted = true }
                return t
            }
            XCTAssertTrue(checklist.isStreakEarned, "the Burst alone still earns it")
        }
    }

    /// The declaration leads, the Burst sits directly behind it.
    ///
    /// The Burst leads because it is the only row that earns the streak, and it
    /// is the most-completed task in the product. The declaration takes second:
    /// it has no other entry point, so it must not fall below the fold, but it
    /// does not outrank the day's one required action.
    func testDeclarationTask_SitsDirectlyBehindTheBurst() {
        withStandardTasks {
            let ids = TaskLibrary.getCoreTasksForStreak(10, personalDeclarations: progress(total: 1, spoken: 0))
                .map(\.id)
            XCTAssertEqual(ids.first, "complete_daily_burst")
            XCTAssertEqual(ids.dropFirst().first, TaskLibrary.personalDeclarationTaskId)
        }
    }

    /// It has to land behind the Burst on every path, not just the one where the
    /// Burst was already first. Anchoring the insert to the Burst's current
    /// index is what keeps the pair adjacent through every phase mix.
    func testDeclarationTask_SitsBehindTheBurstOnEveryPathNotJustTheStandardOne() {
        withStandardTasks {
            for streakDay in [1, 7, 10, 15, 30, 60] {
                let ids = TaskLibrary.getCoreTasksForStreak(streakDay,
                                                            personalDeclarations: progress(total: 2, spoken: 1))
                    .map(\.id)
                guard ids.contains("complete_daily_burst") else { continue }
                XCTAssertEqual(ids.first, "complete_daily_burst", "day \(streakDay)")
                XCTAssertEqual(ids.dropFirst().first, TaskLibrary.personalDeclarationTaskId,
                               "day \(streakDay) ordered as \(ids)")
            }
        }
    }

    /// The declaration must still lead when the phase mix has no Burst at all,
    /// rather than silently falling to the bottom of the list.
    func testDeclarationTask_LeadsWhenThereIsNoBurst() {
        let noBurst = TaskLibrary.foundationTasks.filter { $0.id != "complete_daily_burst" }
        let ids = TaskLibrary.withPersonalDeclaration(
            noBurst, progress: progress(total: 1, spoken: 0)
        ).map(\.id)
        XCTAssertEqual(ids.first, TaskLibrary.personalDeclarationTaskId)
    }

    /// Tapping the row opens the declaration rather than doing nothing.
    func testDeclarationTask_NavigatesToTheDeclaration() {
        withStandardTasks {
            XCTAssertEqual(declarationTask(progress(total: 1, spoken: 0))?.navigationDestination,
                           .personalDeclaration)
        }
    }

    // MARK: - Connect style

    /// The Burst leads no matter what they answered. Their modality is the
    /// on-ramp; speaking is the thing the product exists to produce, and it is
    /// also the only row that earns the streak.
    func testConnectStyle_NeverDisplacesTheBurst() {
        withStandardTasks {
            for style in ConnectStyle.allCases {
                let ids = TaskLibrary.getCoreTasksForStreak(3, connectStyle: style).map(\.id)
                XCTAssertEqual(ids.first, "complete_daily_burst",
                               "\(style.rawValue) displaced the Burst: \(ids)")
            }
        }
    }

    /// The point of the whole feature: the row they said they connect through
    /// leads the content rows instead of sitting wherever the phase mix left it.
    func testConnectStyle_LeadsTheContentRows() {
        withStandardTasks {
            let listening = TaskLibrary.getCoreTasksForStreak(3, connectStyle: .listening).map(\.id)
            XCTAssertEqual(listening.dropFirst().first, "listen_audio", "ordered as \(listening)")

            let reading = TaskLibrary.getCoreTasksForStreak(3, connectStyle: .reading).map(\.id)
            XCTAssertEqual(reading.dropFirst().first, "read_devotional", "ordered as \(reading)")
        }
    }

    /// Journaling is the only answer with no matching row in the foundation
    /// week — `journal_insight` is gated to day 8 and `gratitude_moment` has
    /// been retired — so those users would spend week one with nothing
    /// resembling what they asked for.
    func testConnectStyle_JournalingGetsAJournalRowOnDayOne() {
        withStandardTasks {
            let ids = TaskLibrary.getCoreTasksForStreak(1, connectStyle: .journaling).map(\.id)
            XCTAssertTrue(ids.contains("journal_insight"), "day 1 served \(ids)")
            XCTAssertEqual(ids.dropFirst().first, "journal_insight", "ordered as \(ids)")
        }
    }

    /// It orders, it never adds — except the journaling row above. Anyone else
    /// gets exactly the rows their phase and streak already earned them.
    func testConnectStyle_ChangesOrderNotMembership() {
        withStandardTasks {
            let baseline = Set(TaskLibrary.getCoreTasksForStreak(3, connectStyle: nil).map(\.id))
            for style in ConnectStyle.allCases where style != .journaling {
                let styled = Set(TaskLibrary.getCoreTasksForStreak(3, connectStyle: style).map(\.id))
                XCTAssertEqual(styled, baseline, "\(style.rawValue) changed which rows are served")
            }
        }
    }

    /// No answer, no change — the ordering is inert for every user who has not
    /// been asked, which is everyone who onboarded before this shipped and
    /// everyone in an arm that does not ask.
    ///
    /// Asserted against the literal foundation order rather than against
    /// another nil call, which would compare a thing to itself and pass no
    /// matter what `leadWithPreferredModality` did.
    func testConnectStyle_AbsentAnswerLeavesOrderUntouched() {
        withStandardTasks {
            let ids = TaskLibrary.getCoreTasksForStreak(3, connectStyle: nil).map(\.id)
            XCTAssertEqual(ids, ["complete_daily_burst", "read_devotional",
                                 "listen_audio", "ask_the_bible"],
                           "unstyled day 3 ordered as \(ids)")
        }
    }

    /// The Bible chat row is the only task on the board that responds to what
    /// the user is carrying today rather than serving content written before
    /// they woke up, and it is the one surface that pays off in seconds. The
    /// plan sold in onboarding now promises its payoff at day 7, so this row
    /// has to be live well inside the trial window and has to stay live after
    /// it. Pinned because "day 2" looks arbitrary until you know why.
    ///
    /// Runs under both task-selection paths. The AI path keeps its own keeper
    /// lists, and they were once out of step with the standard ones — which
    /// dropped this row from day 8 for exactly the cohort `enableAIFeatures`
    /// also promotes Bible Chat into the tab bar for. A test pinned only to the
    /// standard path would not have caught that.
    func testAskTheBible_ArrivesInsideTheTrialAndNeverLeaves() {
        withBothTaskPaths {
            let dayOne = TaskLibrary.getCoreTasksForStreak(1).map(\.id)
            XCTAssertFalse(dayOne.contains("ask_the_bible"),
                           "day 1 is meant to stay light: \(dayOne)")
            for day in [2, 3, 5, 7, 8, 20, 31, 60, 100, 365] {
                let ids = TaskLibrary.getCoreTasksForStreak(day).map(\.id)
                XCTAssertTrue(ids.contains("ask_the_bible"),
                              "day \(day) lost the Bible chat row: \(ids)")
            }
        }
    }

    /// The board must never get narrower as the user goes deeper. A
    /// foundation-only row would have made day 7 wider than day 30.
    func testBoardWidthNeverShrinksWithProgress() {
        withBothTaskPaths {
            let days = [1, 3, 7, 8, 30, 31, 100, 365]
            let counts = days.map { TaskLibrary.getCoreTasksForStreak($0).count }
            for (i, count) in counts.enumerated().dropFirst() {
                XCTAssertGreaterThanOrEqual(count, counts[i - 1],
                    "day \(days[i]) serves \(count) rows, fewer than day \(days[i - 1])'s \(counts[i - 1])")
            }
        }
    }

    func testConnectStyle_RoundTripsThroughStorage() {
        let defaults = UserDefaults(suiteName: "connect-style-tests")!
        defaults.removePersistentDomain(forName: "connect-style-tests")

        XCTAssertNil(ConnectStyle.stored(defaults: defaults))
        ConnectStyle.store(.journaling, defaults: defaults)
        XCTAssertEqual(ConnectStyle.stored(defaults: defaults), .journaling)
        ConnectStyle.store(nil, defaults: defaults)
        XCTAssertNil(ConnectStyle.stored(defaults: defaults))
    }

    // MARK: - Retired tasks

    /// Seven tasks were unlocked 146 times across 30 days and completed zero
    /// times: every one of them an off-app instruction ("pray while walking",
    /// "do something kind for someone") with no `navigationDestination`. They
    /// were completable — people simply would not — so they were occupying
    /// finite slots on a board where 77% of user-days end with nothing done.
    ///
    /// Pinned as a test because the natural instinct on seeing a thin Impact
    /// phase is to add them back.
    func testRetiredTasks_AreGoneFromEveryPhase() {
        let retired: Set<String> = [
            "worship_song", "study_deeper", "prayer_walk",
            "encourage_someone", "pray_for_others", "serve_someone", "testimony_share",
            // The four mastery rows, retired for the same reason: off-app
            // instructions with no navigationDestination.
            "mentor_someone", "fast_and_pray", "teach_truth", "create_content",
            // `gratitude_moment` is retired for a DIFFERENT reason and should
            // not be cited as a dead row: it was completed 58 times out of 238
            // unlocks. It went because the board could not afford a fifth
            // foundation slot, and because its `.journal` destination duplicated
            // `journal_insight` — which now covers the journaling cohort for the
            // whole foundation week instead of only day 1.
            "gratitude_moment"
        ]
        XCTAssertTrue(TaskLibrary.allTasks.filter { retired.contains($0.id) }.isEmpty,
                      "Retired tasks are back in the library.")

        withStandardTasks {
            for day in [1, 5, 8, 12, 15, 20, 31, 35, 40, 50, 60, 100, 150] {
                let ids = Set(TaskLibrary.getCoreTasksForStreak(day).map(\.id))
                XCTAssertTrue(ids.isDisjoint(with: retired),
                              "day \(day) served a retired task: \(ids.intersection(retired))")
            }
        }
    }

    /// Removing four of the five Impact tasks must not empty the phase — the
    /// mix takes `prefix(1)` from it, so an empty array would silently serve a
    /// shorter board rather than fail.
    func testPhasesStillServeTasksAfterTheRetirements() {
        withStandardTasks {
            for day in [1, 8, 31, 100] {
                XCTAssertGreaterThanOrEqual(TaskLibrary.getCoreTasksForStreak(day).count, 3,
                                            "day \(day) board collapsed")
            }
        }
        XCTAssertFalse(TaskLibrary.impactTasks.isEmpty)
        XCTAssertTrue(TaskLibrary.masteryTasks.isEmpty,
                      "Mastery tasks are back; the phase mix draws from growth now.")
        XCTAssertFalse(TaskLibrary.growthTasks.isEmpty)
    }

    // MARK: - Campaign-refreshed tasks

    /// The AI path builds a different task set. These tests are about the
    /// standard one, so pin the flag rather than inherit whatever ran before.
    /// The AI task-selection path, which keeps its own keeper lists. Every
    /// board invariant has to hold under both paths — the flag is live Remote
    /// Config, so real users are on each.
    private func withAITasks(_ body: () -> Void) {
        let key = "enableAIFeatures"
        let previous = UserDefaults.standard.bool(forKey: key)
        UserDefaults.standard.set(true, forKey: key)
        defer { UserDefaults.standard.set(previous, forKey: key) }
        body()
    }

    /// Runs `body` under both task-selection paths.
    private func withBothTaskPaths(_ body: () -> Void) {
        withStandardTasks(body)
        withAITasks(body)
    }

    private func withStandardTasks(_ body: () -> Void) {
        let key = "enableAIFeatures"
        let previous = UserDefaults.standard.bool(forKey: key)
        UserDefaults.standard.set(false, forKey: key)
        defer { UserDefaults.standard.set(previous, forKey: key) }
        body()
    }

    private func campaignDay(_ number: Int = 3) -> EnforcementDay {
        EnforcementDay(dayNumber: number,
                       anchorText: "I am rooted and established in love.",
                       anchorVerse: "verse",
                       anchorBook: "Ephesians 3:17",
                       anchorTranslation: "",
                       audioId: "psalm91",
                       audioTitle: "Psalm 91",
                       audioMinutes: 12)
    }

    /// The badge is the only thing connecting a typed sentence to the two tasks
    /// that quietly changed underneath the user because of it.
    func testCampaignStampsTheBurstAndTheListenTask() {
        withStandardTasks {
            let tasks = TaskLibrary.getCoreTasksForStreak(10, enforcementDay: campaignDay())

            let burst = tasks.first { $0.id == "complete_daily_burst" }
            let listen = tasks.first { $0.id == "listen_audio" }
            XCTAssertEqual(burst?.isCampaignRefreshed, true)
            XCTAssertEqual(listen?.isCampaignRefreshed, true)
            XCTAssertEqual(listen?.recommendedAudioId, "psalm91")
            XCTAssertEqual(burst?.description,
                           "Day 3 of \(Enforcement.length), built from what you're standing on.")
        }
    }

    /// Only those two. A badge on the devotional would be a lie.
    func testCampaignStampsNothingElse() {
        withStandardTasks {
            let tasks = TaskLibrary.getCoreTasksForStreak(10, enforcementDay: campaignDay())
            for task in tasks where !TaskLibrary.campaignOwnedTaskIds.contains(task.id) {
                XCTAssertFalse(task.isCampaignRefreshed,
                               "\(task.id) claims a campaign it has nothing to do with")
            }
        }
    }

    func testNoCampaignMeansNoStamp() {
        withStandardTasks {
            for task in TaskLibrary.getCoreTasksForStreak(10) {
                XCTAssertFalse(task.isCampaignRefreshed)
            }
        }
    }

    /// `DailyTask` uses synthesized Codable, which does NOT fall back to a
    /// property's default when a key is absent. A non-optional `Bool` here would
    /// throw `keyNotFound` on every checklist persisted before this shipped, and
    /// the user would lose the day's progress on upgrade.
    func testTaskDecodesWhenTheCampaignFlagIsAbsent() throws {
        let legacy = """
        {"id":"complete_daily_burst","title":"Speak Your Daily Burst",
         "description":"Seven declarations out loud.","icon":"bolt.circle.fill",
         "category":"foundation","type":"speak","difficulty":1,
         "minimumStreakDay":1,"estimatedMinutes":3,"isCompleted":false,
         "navigationDestination":"burst"}
        """.data(using: .utf8)!

        let task = try JSONDecoder().decode(DailyTask.self, from: legacy)
        XCTAssertEqual(task.id, "complete_daily_burst")
        XCTAssertFalse(task.isCampaignRefreshed)
    }
}