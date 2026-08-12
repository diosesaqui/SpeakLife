//
//  StreakStatsTests.swift
//  SpeakLifeTests
//
//  Unit tests for StreakStats model to ensure streak calculation logic works correctly
//

import XCTest
@testable import SpeakLifeCore

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
        
        // Then: nothing moves. `updateStreak` returns early on a same-day
        // repeat, and it is right to — the field counts DAYS completed, not
        // completions, so speaking twice in one day is still one day. The old
        // expectation of initialTotal + 1 would have made the counter drift
        // upward every time someone opened the app twice.
        XCTAssertEqual(streakStats.currentStreak, initialStreak)
        XCTAssertEqual(streakStats.totalDaysCompleted, initialTotal)
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

    // MARK: - Helpers for the cross-device tests

    private func day(_ daysAgo: Int) -> Date {
        calendar.startOfDay(for: calendar.date(byAdding: .day, value: -daysAgo, to: Date())!)
    }

    // MARK: - Merged Completion History
    //
    // StreakHistory is the input the streak-freeze decision is made from: the
    // union of every device's day-completion rows. Its two questions — how
    // long is the run, and when did it end — have to be answered identically
    // on every device, so they are pure functions of the day set.

    func testStreakHistory_ConsecutiveDaysStopsAtTheFirstMissedDay() {
        // Completed 1, 2, 3 and 5 days ago. Day 4 is missing.
        let history = StreakHistory(dates: [day(1), day(2), day(3), day(5)])

        XCTAssertEqual(history.consecutiveDays(endingOn: day(1)), 3)
        XCTAssertEqual(history.consecutiveDays(endingOn: day(5)), 1)
        XCTAssertEqual(history.consecutiveDays(endingOn: day(0)), 0,
                       "Today was never completed, so no run ends on it")
        XCTAssertEqual(history.lastCompletedDay, day(1))
    }

    func testStreakHistory_NormalizesTimestampsAndCollapsesRepeatsWithinADay() {
        let today = calendar.startOfDay(for: Date())
        let morning = calendar.date(byAdding: .hour, value: 7, to: today)!
        let evening = calendar.date(byAdding: .hour, value: 21, to: today)!

        let history = StreakHistory(dates: [morning, evening])

        XCTAssertEqual(history.completedDays, [today],
                       "Two bursts in one day are one completed day")
        XCTAssertEqual(history.consecutiveDays(endingOn: evening), 1)
    }

    func testStreakHistory_EmptyHasNoLastDay() {
        let history = StreakHistory()
        XCTAssertTrue(history.isEmpty)
        XCTAssertNil(history.lastCompletedDay)
        XCTAssertEqual(history.consecutiveDays(endingOn: Date()), 0)
    }

    // MARK: - Cross-Device Merge (StreakStats.merging)
    //
    // These pin the invariants the iCloud settings merge depends on: history
    // only ever moves up, the live count follows the most recent completion,
    // a stale blob cannot resurrect a dead streak, and both devices compute
    // the same answer so repeated merges converge instead of ping-ponging.

    func testMerging_HistoricalFieldsOnlyEverMoveUp() {
        let today = calendar.startOfDay(for: Date())

        var mine = StreakStats()
        mine.longestStreak = 12
        mine.totalDaysCompleted = 40
        mine.celebratedMilestones = [1, 3, 7]
        mine.lastCompletedDate = today

        var theirs = StreakStats()
        theirs.longestStreak = 9
        theirs.totalDaysCompleted = 55
        theirs.celebratedMilestones = [1, 14]
        theirs.lastCompletedDate = today

        let merged = mine.merging(theirs)

        XCTAssertEqual(merged.longestStreak, 12)
        XCTAssertEqual(merged.totalDaysCompleted, 55)
        XCTAssertEqual(merged.celebratedMilestones, [1, 3, 7, 14],
                       "Celebrated milestones union so a celebration never re-fires")
        XCTAssertEqual(merged, theirs.merging(mine))
    }

    func testMerging_MostRecentCompletionOwnsTheLiveCount() {
        var mine = StreakStats()
        mine.currentStreak = 9
        mine.longestStreak = 9
        mine.streakFreezeAvailable = false
        mine.lastCompletedDate = day(4)

        var theirs = StreakStats()
        theirs.currentStreak = 2
        theirs.longestStreak = 9
        theirs.lastCompletedDate = day(0)

        XCTAssertEqual(mine.merging(theirs).currentStreak, 2)
        XCTAssertEqual(theirs.merging(mine).currentStreak, 2)
        XCTAssertEqual(mine.merging(theirs).lastCompletedDate, day(0))
    }

    /// The "zombie streak": a blob from a phone that has not synced in days
    /// must not hand back a count with no completions behind it.
    func testMerging_StaleBlobCannotResurrectABrokenStreak() {
        var mine = StreakStats()
        mine.currentStreak = 0                  // this device already reset it
        mine.longestStreak = 9
        mine.streakFreezeAvailable = false
        mine.lastCompletedDate = day(5)

        var theirs = StreakStats()
        theirs.currentStreak = 9                // stale, and no freeze left to rescue it
        theirs.longestStreak = 9
        theirs.streakFreezeAvailable = false
        theirs.lastCompletedDate = day(5)

        XCTAssertEqual(mine.merging(theirs).currentStreak, 0)
        XCTAssertEqual(theirs.merging(mine).currentStreak, 0)
        XCTAssertEqual(mine.merging(theirs).longestStreak, 9,
                       "The record still stands even though the run is over")
    }

    func testMerging_SameDayTakesTheHigherLiveCount() {
        let today = calendar.startOfDay(for: Date())

        var freshInstall = StreakStats()
        freshInstall.currentStreak = 0
        freshInstall.lastCompletedDate = today

        var established = StreakStats()
        established.currentStreak = 11
        established.longestStreak = 11
        established.lastCompletedDate = today

        XCTAssertEqual(freshInstall.merging(established).currentStreak, 11)
        XCTAssertEqual(established.merging(freshInstall).currentStreak, 11)
    }

    /// The reported two-phone bug, at the merge layer.
    ///
    /// A freeze bridges lastCompletedDate forward to yesterday. That bridged
    /// date is a placeholder, not a day the user completed — so when it lands
    /// on the same day as another device's REAL completion, the real one owns
    /// the count. Without this, the drawer phone's resurrected 8 beat the
    /// active phone's honest 1 and the streak jumped with no explanation.
    func testMerging_FreezeBridgeNeverOutranksARealCompletion() {
        var active = StreakStats()
        active.currentStreak = 1
        active.longestStreak = 8
        active.lastCompletedDate = day(1)       // really completed yesterday

        var stale = StreakStats()
        stale.currentStreak = 8
        stale.longestStreak = 8
        stale.lastCompletedDate = day(1)        // only bridged onto yesterday
        stale.streakFreezeAvailable = false
        stale.streakFreezeUsedDate = Date()
        stale.streakFreezeCoveredDay = day(8)

        XCTAssertEqual(active.merging(stale).currentStreak, 1,
                       "A bridge is not evidence of a completed day")
        XCTAssertEqual(stale.merging(active).currentStreak, 1,
                       "Both devices pick the same side, so this converges")
        XCTAssertNil(active.merging(stale).streakFreezeCoveredDay,
                     "The winning side completed that day for real — no bridge outstanding")
        XCTAssertFalse(active.merging(stale).streakFreezeAvailable,
                       "A freeze spent anywhere stays spent")
    }

    func testMerging_IsOrderIndependentAndIdempotent() {
        var active = StreakStats()
        active.currentStreak = 1
        active.longestStreak = 8
        active.totalDaysCompleted = 20
        active.celebratedMilestones = [1, 3, 7]
        active.lastCompletedDate = day(1)

        var stale = StreakStats()
        stale.currentStreak = 8
        stale.longestStreak = 8
        stale.totalDaysCompleted = 18
        stale.celebratedMilestones = [1, 3]
        stale.lastCompletedDate = day(1)
        stale.streakFreezeAvailable = false
        stale.streakFreezeUsedDate = day(0)
        stale.streakFreezeCoveredDay = day(8)

        let oneWay = active.merging(stale)
        let otherWay = stale.merging(active)

        XCTAssertEqual(oneWay, otherWay, "Both devices must compute the same merged state")
        XCTAssertEqual(oneWay.merging(otherWay), oneWay, "Re-merging a settled state changes nothing")
    }
}