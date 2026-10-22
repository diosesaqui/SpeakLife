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
        case scheduleAtRisk(Int, at: Date)
        case cancelAtRisk
        case scheduleLapsedNudge(at: Date)
        case scheduleTaskNudge(taskId: String, at: Date)
        case cancelTaskNudge
        case cancelLapsedNudge
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

    /// The at-risk push as the notification centre holds it after every call
    /// so far: its fire date, or nil when none is pending.
    var pendingAtRiskFireDate: Date? {
        for call in calls.reversed() {
            switch call {
            case .scheduleAtRisk(_, let fireDate): return fireDate
            case .cancelAtRisk: return nil
            default: continue
            }
        }
        return nil
    }

    var pendingLapsedNudgeFireDate: Date? {
        for call in calls.reversed() {
            switch call {
            case .scheduleLapsedNudge(let fireDate): return fireDate
            case .cancelLapsedNudge: return nil
            default: continue
            }
        }
        return nil
    }

    /// The task the pending evening task nudge names, or nil when none is pending.
    var pendingTaskNudge: String? {
        for call in calls.reversed() {
            switch call {
            case .scheduleTaskNudge(let taskId, _): return taskId
            case .cancelTaskNudge: return nil
            default: continue
            }
        }
        return nil
    }

    var atRiskWasEverScheduled: Bool {
        calls.contains { if case .scheduleAtRisk = $0 { return true } else { return false } }
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

    func scheduleStreakAtRiskNotification(currentStreak: Int, at fireDate: Date) {
        calls.append(.scheduleAtRisk(currentStreak, at: fireDate))
    }
    func cancelStreakAtRiskNotification() { calls.append(.cancelAtRisk) }
    func scheduleLapsedStreakNudge(at fireDate: Date) { calls.append(.scheduleLapsedNudge(at: fireDate)) }
    func cancelLapsedStreakNudge() { calls.append(.cancelLapsedNudge) }
    func scheduleEveningTaskNudge(_ nudge: EveningTaskNudge, at fireDate: Date) {
        calls.append(.scheduleTaskNudge(taskId: nudge.taskId, at: fireDate))
    }
    func cancelEveningTaskNudge() { calls.append(.cancelTaskNudge) }
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
         "streakFreezeWasUsed", "streakFreezeBannerShownFor",
         EnhancedStreakViewModel.EveningCheckInKeys.enabled,
         EnhancedStreakViewModel.EveningCheckInKeys.hour,
         EnhancedStreakViewModel.EveningCheckInKeys.minute,
         EnhancedStreakViewModel.EveningCheckInKeys.checklistEnabled]
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

    // MARK: - Evening check-in (streak at risk)

    private typealias Keys = EnhancedStreakViewModel.EveningCheckInKeys

    /// A live streak with today not yet earned: the case the evening push is for.
    private func seedStreakAtRisk(_ streak: Int = 4) throws {
        try seedDevice(streak: streak, lastCompletedDaysAgo: 1)
        BurstCompletionTracker.shared.completions = completions(streak, endingDaysAgo: 1)
    }

    /// The latest time today that is still ahead of now, so the push has a
    /// window to land in. Skips in the last minutes before midnight.
    private func lateTonight() throws -> (hour: Int, minute: Int) {
        let now = Date()
        let comps = cal.dateComponents([.hour, .minute], from: now)
        if comps.hour == 23 && (comps.minute ?? 0) >= 58 {
            throw XCTSkip("too close to midnight for a later time today")
        }
        return (23, 59)
    }

    func testEveningCheckInOffSchedulesNothingAndWithdrawsThePush() throws {
        try seedStreakAtRisk()
        UserDefaults.standard.set(false, forKey: Keys.enabled)

        _ = EnhancedStreakViewModel()

        XCTAssertFalse(spy.atRiskWasEverScheduled,
            "The user switched the evening check-in off")
        XCTAssertTrue(spy.calls.contains(.cancelAtRisk),
            "A push queued before the switch was flipped must come down too")
        XCTAssertNil(spy.pendingAtRiskFireDate)
    }

    func testMasterChecklistRemindersOffAlsoSilencesTheEveningPush() throws {
        try seedStreakAtRisk()
        UserDefaults.standard.set(false, forKey: Keys.checklistEnabled)

        _ = EnhancedStreakViewModel()

        XCTAssertFalse(spy.atRiskWasEverScheduled)
        XCTAssertNil(spy.pendingAtRiskFireDate)
    }

    func testTurningEveningCheckInOffInSettingsWithdrawsThePendingPush() throws {
        let time = try lateTonight()
        try seedStreakAtRisk()
        UserDefaults.standard.set(time.hour, forKey: Keys.hour)
        UserDefaults.standard.set(time.minute, forKey: Keys.minute)

        let viewModel = EnhancedStreakViewModel()
        XCTAssertNotNil(spy.pendingAtRiskFireDate, "precondition: tonight's push is queued")

        UserDefaults.standard.set(false, forKey: Keys.enabled)

        XCTAssertNil(spy.pendingAtRiskFireDate,
            "Flipping the toggle must withdraw the push without waiting for the next launch")
        withExtendedLifetime(viewModel) {}
    }

    func testCustomEveningTimeIsUsedForTodaysOneOffPush() throws {
        let time = try lateTonight()
        try seedStreakAtRisk(4)
        UserDefaults.standard.set(time.hour, forKey: Keys.hour)
        UserDefaults.standard.set(time.minute, forKey: Keys.minute)

        _ = EnhancedStreakViewModel()

        let expected = cal.date(bySettingHour: time.hour, minute: time.minute, second: 0, of: Date())!
        XCTAssertEqual(spy.pendingAtRiskFireDate, expected,
            "Fires today at the user's chosen time, not a hard-coded default")
        guard case .scheduleAtRisk(let streak, _)? = spy.calls.last(where: {
            if case .scheduleAtRisk = $0 { return true } else { return false }
        }) else { return XCTFail("no at-risk push scheduled") }
        XCTAssertEqual(streak, 4, "Carries the streak as it stands right now")
    }

    func testChangingTheTimeInSettingsReschedulesAtTheNewTime() throws {
        let time = try lateTonight()
        try seedStreakAtRisk()
        UserDefaults.standard.set(time.hour, forKey: Keys.hour)
        UserDefaults.standard.set(time.minute - 1, forKey: Keys.minute)

        let viewModel = EnhancedStreakViewModel()
        UserDefaults.standard.set(time.minute, forKey: Keys.minute)

        XCTAssertEqual(spy.pendingAtRiskFireDate,
                       cal.date(bySettingHour: time.hour, minute: time.minute, second: 0, of: Date())!)
        withExtendedLifetime(viewModel) {}
    }

    func testCompletingTheBurstWithdrawsTheEveningPush() throws {
        let time = try lateTonight()
        try seedStreakAtRisk()
        UserDefaults.standard.set(time.hour, forKey: Keys.hour)
        UserDefaults.standard.set(time.minute, forKey: Keys.minute)

        let viewModel = EnhancedStreakViewModel()
        XCTAssertNotNil(spy.pendingAtRiskFireDate, "precondition: tonight's push is queued")

        viewModel.completeTask(taskId: "complete_daily_burst")

        XCTAssertNil(spy.pendingAtRiskFireDate,
            "The streak is safe for today, so 'ends tonight' would be a lie")
    }

    // MARK: Fire date

    private func scratchDefaults() -> UserDefaults {
        let name = "EveningCheckInTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        addTeardownBlock { defaults.removePersistentDomain(forName: name) }
        return defaults
    }

    private func today(_ hour: Int, _ minute: Int) -> Date {
        cal.date(bySettingHour: hour, minute: minute, second: 0, of: Date())!
    }

    func testFireDateDefaultsToNinePMWhenNoTimeIsSet() {
        let fire = EnhancedStreakViewModel.eveningCheckInFireDate(now: today(9, 0),
                                                                  defaults: scratchDefaults())
        XCTAssertEqual(fire, today(21, 0))
    }

    func testFireDateUsesTheChosenTime() {
        let defaults = scratchDefaults()
        defaults.set(20, forKey: Keys.hour)
        defaults.set(15, forKey: Keys.minute)
        XCTAssertEqual(EnhancedStreakViewModel.eveningCheckInFireDate(now: today(9, 0), defaults: defaults),
                       today(20, 15))
    }

    func testNoFireDateOnceTodaysTimeHasPassed() {
        XCTAssertNil(EnhancedStreakViewModel.eveningCheckInFireDate(now: today(21, 30),
                                                                    defaults: scratchDefaults()),
            "Skip today rather than roll to tomorrow: tomorrow's push is scheduled on "
            + "tomorrow's open, with tomorrow's streak count")
    }

    func testNoFireDateWhenSwitchedOff() {
        let defaults = scratchDefaults()
        defaults.set(false, forKey: Keys.enabled)
        XCTAssertNil(EnhancedStreakViewModel.eveningCheckInFireDate(now: today(9, 0), defaults: defaults))
    }

    // MARK: - Lapsed streak nudge (3 days with no burst)

    private func day(_ offset: Int, _ hour: Int, _ minute: Int) -> Date {
        cal.date(bySettingHour: hour, minute: minute, second: 0,
                 of: cal.date(byAdding: .day, value: offset, to: Date())!)!
    }

    func testLapsedNudgeFiresOnTheEveningOfTheThirdDayWithoutABurst() {
        let fire = EnhancedStreakViewModel.lapsedStreakNudgeFireDate(lastCompleted: day(0, 8, 0),
                                                                     now: day(0, 12, 0),
                                                                     defaults: scratchDefaults())
        XCTAssertEqual(fire, day(3, 21, 0))
    }

    func testLapsedNudgeUsesTheChosenEveningTime() {
        let defaults = scratchDefaults()
        defaults.set(19, forKey: Keys.hour)
        defaults.set(45, forKey: Keys.minute)
        let fire = EnhancedStreakViewModel.lapsedStreakNudgeFireDate(lastCompleted: day(-1, 8, 0),
                                                                     now: day(0, 12, 0),
                                                                     defaults: defaults)
        XCTAssertEqual(fire, day(2, 19, 45))
    }

    func testNoLapsedNudgeOnceItsEveningHasPassedOrWhenOff() {
        XCTAssertNil(EnhancedStreakViewModel.lapsedStreakNudgeFireDate(lastCompleted: day(-4, 8, 0),
                                                                       now: day(0, 12, 0),
                                                                       defaults: scratchDefaults()),
            "One push on day 3, not a nightly nag after it")
        XCTAssertNil(EnhancedStreakViewModel.lapsedStreakNudgeFireDate(lastCompleted: nil,
                                                                       defaults: scratchDefaults()),
            "Never completed a burst: the install-day lifecycle pushes cover them")
        let off = scratchDefaults()
        off.set(false, forKey: Keys.enabled)
        XCTAssertNil(EnhancedStreakViewModel.lapsedStreakNudgeFireDate(lastCompleted: day(0, 8, 0),
                                                                       defaults: off))
    }

    func testLaunchQueuesTheLapsedNudgeThreeDaysAfterTheLastBurst() throws {
        try seedStreakAtRisk()

        _ = EnhancedStreakViewModel()

        XCTAssertEqual(spy.pendingLapsedNudgeFireDate, day(2, 21, 0),
            "Last burst was yesterday, so the third quiet day is two days from now")
    }

    func testCompletingABurstPushesTheLapsedNudgeOut() throws {
        try seedStreakAtRisk()
        let viewModel = EnhancedStreakViewModel()

        viewModel.completeTask(taskId: "complete_daily_burst")

        XCTAssertEqual(spy.pendingLapsedNudgeFireDate, day(3, 21, 0),
            "Today's burst restarts the three-day clock")
    }

    // MARK: - Evening task nudge (burst done, bonus tasks open)

    func testBurstDoneWithBonusTasksOpenNamesTheNextTaskInsteadOfTheStreak() throws {
        let time = try lateTonight()
        try seedStreakAtRisk()
        UserDefaults.standard.set(time.hour, forKey: Keys.hour)
        UserDefaults.standard.set(time.minute, forKey: Keys.minute)
        let viewModel = EnhancedStreakViewModel()
        XCTAssertNil(spy.pendingTaskNudge, "precondition: burst open, so the streak push owns the slot")

        viewModel.completeTask(taskId: "complete_daily_burst")

        XCTAssertNil(spy.pendingAtRiskFireDate)
        XCTAssertEqual(spy.pendingTaskNudge, "listen_audio",
            "Audio leads the call-outs while it is still open")

        viewModel.completeTask(taskId: "listen_audio")
        XCTAssertNotEqual(spy.pendingTaskNudge, "listen_audio",
            "Finishing a task moves the nudge on to one still open")
    }

    func testAllTasksDoneWithdrawsEveryEveningPush() throws {
        let time = try lateTonight()
        try seedStreakAtRisk()
        UserDefaults.standard.set(time.hour, forKey: Keys.hour)
        UserDefaults.standard.set(time.minute, forKey: Keys.minute)
        let viewModel = EnhancedStreakViewModel()

        for task in viewModel.todayChecklist.tasks {
            viewModel.completeTask(taskId: task.id)
        }
        guard viewModel.todayChecklist.tasks.allSatisfy(\.isCompleted) else {
            throw XCTSkip("a task on this list cannot be ticked by completeTask")
        }

        XCTAssertNil(spy.pendingTaskNudge)
        XCTAssertNil(spy.pendingAtRiskFireDate)
    }

    func testTaskNudgePrioritisesAudioThenJournal() {
        func task(_ id: String, done: Bool = false) -> DailyTask {
            DailyTask(id: id, title: id, description: "", icon: "", category: .foundation,
                      type: .speak, isCompleted: done)
        }
        var checklist = DailyChecklist(date: Date(),
                                       tasks: [task("complete_daily_burst", done: true),
                                               task("read_devotional"),
                                               task("journal_insight"),
                                               task("listen_audio")],
                                       currentPhase: .growth)
        XCTAssertEqual(EveningTaskNudge.next(for: checklist)?.taskId, "listen_audio")
        XCTAssertEqual(EveningTaskNudge.next(for: checklist)?.deepLink, "audio")

        checklist.tasks[3].isCompleted = true
        XCTAssertEqual(EveningTaskNudge.next(for: checklist)?.taskId, "journal_insight")

        checklist.tasks[0].isCompleted = false
        XCTAssertNil(EveningTaskNudge.next(for: checklist),
                     "Burst still open: the streak-at-risk push speaks, not this one")
    }

    /// Gratitude is on the evening list, right behind audio and ahead of the
    /// journal, and the tap opens Today where the row is.
    func testTaskNudgeIncludesGratitude() {
        func task(_ id: String, done: Bool = false) -> DailyTask {
            DailyTask(id: id, title: id, description: "", icon: "", category: .foundation,
                      type: .speak, isCompleted: done)
        }
        var checklist = DailyChecklist(date: Date(),
                                       tasks: [task("complete_daily_burst", done: true),
                                               task("journal_insight"),
                                               task(TaskLibrary.gratitudeTaskId),
                                               task("listen_audio")],
                                       currentPhase: .growth)
        XCTAssertEqual(EveningTaskNudge.next(for: checklist)?.taskId, "listen_audio")

        checklist.tasks[3].isCompleted = true
        let nudge = EveningTaskNudge.next(for: checklist)
        XCTAssertEqual(nudge?.taskId, TaskLibrary.gratitudeTaskId)
        XCTAssertNil(nudge?.deepLink, "opens Today, where the row is")
        XCTAssertEqual(nudge?.title, "Three things you're grateful for 🙏")
    }

    func testUnknownTaskStillGetsANudgeNamingIt() {
        let checklist = DailyChecklist(
            date: Date(),
            tasks: [DailyTask(id: "complete_daily_burst", title: "", description: "", icon: "",
                              category: .foundation, type: .speak, isCompleted: true),
                    DailyTask(id: "something_new", title: "Pray for a Friend", description: "",
                              icon: "", category: .foundation, type: .speak)],
            currentPhase: .foundation)
        XCTAssertEqual(EveningTaskNudge.next(for: checklist)?.body,
                       "One thing left on today's list. Next up: Pray for a Friend.")
    }
}
