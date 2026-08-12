//
//  StreakBreakNotificationTests.swift
//  SpeakLifeTests
//
//  The reported bug, in the user's words: "my streak got restored yesterday,
//  then I completed my burst, and I see streak 9 with a notification saying I
//  lost my 10-day streak — which is double wrong."
//
//  Both halves have one cause. checkStreakValidity() decides from whatever
//  completion history THIS device has synced so far, and the first launch of a
//  new day is exactly when iCloud has not yet delivered the days earned
//  elsewhere. It saw a gap the user never had, broke a streak that was alive,
//  and scheduled a break push for the NEXT morning at 9am carrying the count it
//  believed at that instant. Moments later the merged history arrived,
//  reconcileWithSyncedProgress() healed the badge back — but nothing withdrew
//  the push. It sat pending through the restore and two completions and fired
//  anyway, which is why its number disagreed with the badge: the two were read
//  a heal and a day apart.
//
//  So the fix is not a better number. It is that a live streak revokes the
//  notice, at every point the streak can come back to life.
//

import XCTest
import SpeakLifeCore
import SpeakLifePersistence
@testable import SpeakLifeServices

/// Records the streak push side effects in order. The real service ends in
/// UNUserNotificationCenter, which a unit test can neither authorize nor read
/// back — and order against the sync heal is the whole point here.
final class StreakNotificationSpy: StreakNotifying {
    enum Call: Equatable {
        case scheduleAtRisk(Int)
        case cancelAtRisk
        case scheduleBreak(previousStreak: Int)
        case cancelBreak
        case scheduleMilestone(current: Int, previous: Int)
    }

    private(set) var calls: [Call] = []

    /// True while a break push would still be sitting in the notification
    /// centre — scheduled, and not withdrawn since. This, not the raw call
    /// list, is what the user actually experiences.
    var breakNoticeIsLive: Bool {
        guard let last = calls.last(where: { Self.isScheduleBreak($0) || $0 == .cancelBreak }) else {
            return false
        }
        return Self.isScheduleBreak(last)
    }

    var scheduledBreakStreaks: [Int] {
        calls.compactMap { call -> Int? in
            if case .scheduleBreak(let previousStreak) = call { return previousStreak }
            return nil
        }
    }

    private static func isScheduleBreak(_ call: Call) -> Bool {
        if case .scheduleBreak = call { return true }
        return false
    }

    func scheduleStreakAtRiskNotification(currentStreak: Int) { calls.append(.scheduleAtRisk(currentStreak)) }
    func cancelStreakAtRiskNotification() { calls.append(.cancelAtRisk) }
    func scheduleStreakBreakNotification(previousStreak: Int) { calls.append(.scheduleBreak(previousStreak: previousStreak)) }
    func cancelStreakBreakNotification() { calls.append(.cancelBreak) }
    @discardableResult
    func scheduleStreakMilestoneIfNeeded(currentStreak: Int, previousStreak: Int) -> Bool {
        calls.append(.scheduleMilestone(current: currentStreak, previous: previousStreak))
        return false
    }
}

final class StreakBreakNotificationTests: XCTestCase {

    private var spy: StreakNotificationSpy!
    private var realNotifications: StreakNotifying!
    private var savedCompletions: [BurstCompletion] = []
    private let cal = Calendar.current

    private var scratchKeys: [String] {
        ["dailyChecklist", "streakStats", "currentStreak",
         "streakFreezeWasUsed", "streakFreezeBannerShownFor"]
    }

    override func setUp() {
        super.setUp()
        spy = StreakNotificationSpy()
        realNotifications = EnhancedStreakViewModel.notifications
        EnhancedStreakViewModel.notifications = spy

        // The tracker is the authoritative history the heal reads from. Empty
        // it so each test seeds exactly the sync state it means to.
        savedCompletions = BurstCompletionTracker.shared.completions
        BurstCompletionTracker.shared.completions = []

        scratchKeys.forEach { UserDefaults.standard.removeObject(forKey: $0) }
    }

    override func tearDown() {
        EnhancedStreakViewModel.notifications = realNotifications
        BurstCompletionTracker.shared.completions = savedCompletions
        scratchKeys.forEach { UserDefaults.standard.removeObject(forKey: $0) }
        spy = nil
        super.tearDown()
    }

    // MARK: - Helpers

    private func day(_ daysAgo: Int) -> Date {
        cal.startOfDay(for: cal.date(byAdding: .day, value: -daysAgo, to: Date())!)
    }

    /// Seeds this device's saved streak blob, plus a checklist dated to
    /// yesterday so loadData() takes the new-day branch and runs the validity
    /// check — the launch path where the break gets decided.
    private func seedDevice(streak: Int, lastCompletedDaysAgo: Int,
                            freezeAvailable: Bool = false) throws {
        var stats = StreakStats()
        stats.currentStreak = streak
        stats.longestStreak = streak
        stats.totalDaysCompleted = streak
        stats.lastCompletedDate = day(lastCompletedDaysAgo)
        stats.streakFreezeAvailable = freezeAvailable
        UserDefaults.standard.set(try JSONEncoder().encode(stats), forKey: "streakStats")

        let checklist = DailyChecklist(date: day(1),
                                       tasks: TaskLibrary.getCoreTasksForStreak(max(1, streak)),
                                       currentPhase: .foundation)
        UserDefaults.standard.set(try JSONEncoder().encode(checklist), forKey: "dailyChecklist")
    }

    /// The days the user really completed: `length` consecutive days ending
    /// `endingDaysAgo` days back.
    private func completions(_ length: Int, endingDaysAgo: Int) -> [BurstCompletion] {
        (0..<length).map { offset in
            let date = day(endingDaysAgo + offset)
            return BurstCompletion(date: date, completedAt: date,
                                   declarationCount: 1, timeSpent: 60,
                                   spiritualStrengthScore: 50)
        }
    }

    /// CloudKit delivering the days earned on the user's other device, exactly
    /// as BurstCompletionTracker announces them after a merge.
    private func deliverSyncedHistory(_ history: [BurstCompletion]) {
        BurstCompletionTracker.shared.completions = history
        NotificationCenter.default.post(name: BurstCompletionTracker.historyMergedNotification,
                                        object: nil)
    }

    // MARK: - The reported bug

    /// THE regression, replayed in the order it actually happened: the break is
    /// decided before the history lands, and the heal that follows has to take
    /// the push down with the wrong count it carried.
    func testBreakDecidedOnStaleHistoryIsWithdrawnWhenTheRealHistoryArrives() throws {
        // This phone last recorded a completion 3 days ago and believes the run
        // was 10 long. Its own history is empty — the days earned on the user's
        // other device haven't arrived yet.
        try seedDevice(streak: 10, lastCompletedDaysAgo: 3)

        let viewModel = EnhancedStreakViewModel()

        XCTAssertEqual(spy.scheduledBreakStreaks, [10],
            "precondition: launching on stale history does schedule a break — that "
            + "decision is made before the merge lands and cannot see past it")
        XCTAssertTrue(spy.breakNoticeIsLive)

        // Now the merge arrives: the user in fact completed nine straight days
        // ending yesterday, so nothing was ever missed.
        deliverSyncedHistory(completions(9, endingDaysAgo: 1))

        XCTAssertEqual(viewModel.streakStats.currentStreak, 9,
            "precondition: the badge is healed from the authoritative history")
        XCTAssertFalse(spy.breakNoticeIsLive,
            "The merge proved the streak was never broken, so the push scheduled off the "
            + "stale read must come down. Left standing it fires the next morning quoting "
            + "10 to a user whose badge says 9 — the reported bug, both halves of it.")
    }

    /// The other half of the user's session: they came back and completed.
    /// "Restart today" is wrong once today is already earned.
    func testCompletingTheDayWithdrawsAPendingBreakNotice() throws {
        try seedDevice(streak: 8, lastCompletedDaysAgo: 4)

        let viewModel = EnhancedStreakViewModel()
        XCTAssertTrue(spy.breakNoticeIsLive, "precondition: a break was scheduled")

        // Earn today the way the app does — the burst is what carries the day.
        viewModel.completeTask(taskId: "complete_daily_burst")

        XCTAssertGreaterThan(viewModel.streakStats.currentStreak, 0)
        XCTAssertFalse(spy.breakNoticeIsLive,
            "The comeback the push asks for has already happened")
    }

    /// A freeze bridging the gap means the run never ended.
    func testFreezeSpentWithdrawsAPendingBreakNotice() throws {
        try seedDevice(streak: 6, lastCompletedDaysAgo: 2, freezeAvailable: true)

        let viewModel = EnhancedStreakViewModel()

        XCTAssertEqual(viewModel.streakStats.currentStreak, 6,
                       "precondition: the freeze rescued the run")
        XCTAssertTrue(spy.calls.contains(.cancelBreak),
            "A rescued run must actively withdraw the notice rather than merely decline to "
            + "schedule a new one — the stale one is already pending from an earlier launch "
            + "this process cannot see")
        XCTAssertFalse(spy.breakNoticeIsLive)
    }

    /// The guard rail: a real break still gets its push. Withdrawing on a live
    /// streak must not quietly become withdrawing on every launch.
    func testGenuineBreakStillSchedulesAndKeepsItsNotice() throws {
        // Nothing completed for five days, and the shared history agrees.
        try seedDevice(streak: 7, lastCompletedDaysAgo: 5)
        BurstCompletionTracker.shared.completions = completions(7, endingDaysAgo: 5)

        let viewModel = EnhancedStreakViewModel()

        XCTAssertEqual(viewModel.streakStats.currentStreak, 0,
                       "precondition: the streak really is gone")
        XCTAssertEqual(spy.scheduledBreakStreaks, [7])
        XCTAssertTrue(spy.breakNoticeIsLive,
            "A streak that is genuinely down still earns its comeback push")
    }

    /// A live streak withdraws the notice even when this launch decided
    /// nothing. The push may have been scheduled days ago by a device that was
    /// wrong, and every launch since is a chance to correct it.
    func testLaunchWithAHealthyStreakWithdrawsAnyStaleNotice() throws {
        try seedDevice(streak: 4, lastCompletedDaysAgo: 1)
        BurstCompletionTracker.shared.completions = completions(4, endingDaysAgo: 1)

        _ = EnhancedStreakViewModel()

        XCTAssertTrue(spy.scheduledBreakStreaks.isEmpty)
        XCTAssertTrue(spy.calls.contains(.cancelBreak))
        XCTAssertFalse(spy.breakNoticeIsLive)
    }
}
