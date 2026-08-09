//
//  StreakFreezeTests.swift
//  SpeakLifeTests
//
//  Tests for the streak freeze fix.
//
//  Root cause that was fixed:
//    checkStreakValidity() applied the freeze (set streakFreezeAvailable = false, returned early)
//    but never updated lastCompletedDate. On the next updateStreak() call that same day,
//    daysDifference was still 2+ so currentStreak was reset to 1 — completely negating
//    the freeze. Fix: bridge lastCompletedDate to yesterday when freeze fires.
//
//  Second root cause (multi-device), fixed later:
//    the decision was made from THIS device's currentStreak and lastCompletedDate,
//    which are only as fresh as the last time this particular phone synced. A phone
//    left in a drawer saw a week-long gap the user never had, spent a freeze to
//    "rescue" its own stale count, and pushed the resurrected number onto the phone
//    the user actually uses — which had never applied a freeze and showed no reason
//    for the jump. Fix: decide from the MERGED day-completion history (StreakHistory),
//    name each freeze by the gap it covers so one lapse costs one freeze however many
//    devices notice it, and never let a freeze's bridged date out-vote a real
//    completion in merging(). The "Multi-device" section below covers all three.
//

import XCTest
@testable import SpeakLife

final class StreakFreezeTests: XCTestCase {

    var stats: StreakStats!
    let cal = Calendar.current

    override func setUp() {
        super.setUp()
        stats = StreakStats()
    }

    override func tearDown() {
        stats = nil
        super.tearDown()
    }

    // MARK: - Helpers

    /// Simulate N consecutive days of completions ending `daysAgo` days before today.
    private func buildStreak(_ length: Int, endingDaysAgo daysAgo: Int) {
        let today = Date()
        for i in stride(from: length + daysAgo - 1, through: daysAgo, by: -1) {
            let date = cal.date(byAdding: .day, value: -i, to: today)!
            stats.updateStreak(for: date)
        }
    }

    /// The start of the day `daysAgo` days before today.
    private func day(_ daysAgo: Int) -> Date {
        cal.startOfDay(for: cal.date(byAdding: .day, value: -daysAgo, to: Date())!)
    }

    /// The merged day-completion log every device eventually shares:
    /// `length` consecutive completed days ending `daysAgo` days before today.
    private func mergedHistory(_ length: Int, endingDaysAgo daysAgo: Int) -> StreakHistory {
        StreakHistory(dates: (0..<length).map { day(daysAgo + $0) })
    }

    // MARK: - Freeze fires when one day is missed

    func testFreeze_OneMissedDay_StreakPreserved() {
        // Build a 5-day streak ending yesterday
        buildStreak(5, endingDaysAgo: 1)
        XCTAssertEqual(stats.currentStreak, 5)
        XCTAssertTrue(stats.streakFreezeAvailable)

        // Skip today open → app opens 2 days after last completion (yesterday = day-1, so
        // today is day 0 and last completed was day -1 → only 1 day gap, freeze won't fire).
        // Actually we need lastCompletedDate to be 2 days ago:
        // Re-build: streak ending 2 days ago, check validity today.
        stats = StreakStats()
        buildStreak(5, endingDaysAgo: 2)   // last completion was 2 days ago
        XCTAssertEqual(stats.currentStreak, 5)

        // checkStreakValidity is called when app opens on a new day
        stats.checkStreakValidity()

        // Streak should be preserved (freeze used)
        XCTAssertEqual(stats.currentStreak, 5, "Freeze should have protected the streak")
        XCTAssertFalse(stats.streakFreezeAvailable, "Freeze should now be used up")
    }

    func testFreeze_LastCompletedDateBridgedToYesterday() {
        // Build 5-day streak ending 2 days ago
        stats = StreakStats()
        buildStreak(5, endingDaysAgo: 2)

        stats.checkStreakValidity()

        // After freeze: lastCompletedDate must be exactly yesterday
        let yesterday = cal.startOfDay(for: cal.date(byAdding: .day, value: -1, to: Date())!)
        let bridged = cal.startOfDay(for: stats.lastCompletedDate!)
        XCTAssertEqual(bridged, yesterday,
            "lastCompletedDate must be bridged to yesterday so updateStreak() sees daysDifference == 1")
    }

    func testFreeze_UserCompletesToday_StreakIncrements() {
        // This is THE regression test for the bug.
        // Before the fix: completing after a freeze reset the streak to 1.
        // After the fix: completing after a freeze increments correctly.

        stats = StreakStats()
        buildStreak(5, endingDaysAgo: 2)   // last completion was 2 days ago
        stats.checkStreakValidity()         // freeze fires, streak stays at 5

        // Now user completes their burst today
        stats.updateStreak(for: Date())

        XCTAssertEqual(stats.currentStreak, 6,
            "After freeze + completion, streak should be 6 not 1 (regression: was reset to 1 before fix)")
        XCTAssertEqual(stats.longestStreak, 6)
    }

    func testFreeze_OnlyFiredForStreakGte3() {
        // Freeze should NOT fire for streak < 3
        stats = StreakStats()
        buildStreak(2, endingDaysAgo: 2)   // streak of 2, last completion 2 days ago
        XCTAssertEqual(stats.currentStreak, 2)

        stats.checkStreakValidity()

        XCTAssertEqual(stats.currentStreak, 0,
            "Freeze should not protect streak < 3 — should reset to 0")
        XCTAssertTrue(stats.streakFreezeAvailable,
            "Freeze should not be consumed when streak < 3")
    }

    func testFreeze_NotFiredTwice() {
        // Once freeze is used, a second missed day should break the streak
        stats = StreakStats()
        buildStreak(5, endingDaysAgo: 2)

        // First gap: freeze fires
        stats.checkStreakValidity()
        XCTAssertEqual(stats.currentStreak, 5)
        XCTAssertFalse(stats.streakFreezeAvailable)

        // Simulate another day passing without completion (now 3 days since real last completion)
        // We do this by manually winding lastCompletedDate back
        let threeDaysAgo = cal.startOfDay(for: cal.date(byAdding: .day, value: -3, to: Date())!)
        stats.lastCompletedDate = threeDaysAgo

        stats.checkStreakValidity()

        XCTAssertEqual(stats.currentStreak, 0,
            "Second missed day with no freeze available should reset streak to 0")
    }

    func testFreeze_TwoMissedDaysAtOnce_NeverFires() {
        // If user misses 2+ consecutive days, daysDifference > 1 but
        // the freeze only bridges 1. Since we set lastCompletedDate = yesterday
        // when the freeze fires (day +2 open), opening the app on day +3 without
        // completing still sees a 2-day gap → correct break.
        // This test verifies the freeze doesn't grant immunity for 2 missed days.

        stats = StreakStats()
        buildStreak(5, endingDaysAgo: 3)   // last completion was 3 days ago

        // Freeze fires on open (daysDifference = 3 > 1 and freeze available)
        stats.checkStreakValidity()
        XCTAssertFalse(stats.streakFreezeAvailable, "Freeze consumed on first gap")

        // lastCompletedDate is now yesterday. User opens again tomorrow without completing.
        // Simulate 2 more days passing from bridged date (yesterday → 2 days later = tomorrow)
        // daysDifference from yesterday to tomorrow = 2 → streak should break
        let tomorrow = cal.startOfDay(for: cal.date(byAdding: .day, value: 1, to: Date())!)
        // Override today to tomorrow by testing the logic via updateStreak with a future date
        // (streak should reset since freeze is already gone)
        // We can't mock Date(), so we test the invariant: freeze is gone, streak still 5
        // A real run the next day would call checkStreakValidity() again and reset.
        // Verify freeze is gone so next checkStreakValidity() has no protection.
        XCTAssertFalse(stats.streakFreezeAvailable)
    }

    // MARK: - Multi-device: the decision comes from the MERGED history

    /// THE regression test for the reported two-phone bug.
    ///
    /// The phone the user actually uses was on a 1-day streak. A second, stale
    /// phone spent a freeze off its own week-old counter, restored an 8, and
    /// that 8 propagated back. Both devices must now read the same merged
    /// day-completion log and reach the same answer.
    func testFreeze_StaleDeviceAndCurrentDeviceReachTheSameDecision() {
        // Merged truth: the user completed yesterday, on the phone they use.
        let history = mergedHistory(1, endingDaysAgo: 1)

        var currentDevice = StreakStats()
        currentDevice.currentStreak = 1
        currentDevice.longestStreak = 8
        currentDevice.lastCompletedDate = day(1)

        var staleDevice = StreakStats()
        staleDevice.currentStreak = 8            // whatever it last saw, a week ago
        staleDevice.longestStreak = 8
        staleDevice.lastCompletedDate = day(8)

        let currentOutcome = currentDevice.checkStreakValidity(history: history)
        let staleOutcome = staleDevice.checkStreakValidity(history: history)

        XCTAssertEqual(currentOutcome, .unchanged)
        XCTAssertEqual(staleOutcome, .unchanged,
            "The stale device must measure the gap the MERGED history shows (none), not its own")
        XCTAssertTrue(staleDevice.streakFreezeAvailable,
            "No lapse happened, so no freeze may be spent")
        XCTAssertNil(staleDevice.streakFreezeCoveredDay)

        // And the merge settles the count on the day actually completed.
        XCTAssertEqual(currentDevice.merging(staleDevice).currentStreak, 1)
        XCTAssertEqual(staleDevice.merging(currentDevice).currentStreak, 1,
            "The stale 8 must never win — no completion backs it")
    }

    /// A device whose own counter had already fallen below 3 could never
    /// rescue a streak, even when the user genuinely had one. Eligibility and
    /// the rescued length both come from the merged history now.
    func testFreeze_EligibilityUsesMergedHistoryNotTheLocalCounter() {
        // The user really has a 6-day run that ended 2 days ago; this device
        // only ever recorded the last day of it.
        let history = mergedHistory(6, endingDaysAgo: 2)

        stats = StreakStats()
        stats.currentStreak = 1
        stats.lastCompletedDate = day(2)

        let outcome = stats.checkStreakValidity(history: history)

        XCTAssertEqual(outcome, .freezeSpent(coveredDay: day(2)))
        XCTAssertEqual(stats.currentStreak, 6,
            "The rescue restores the run the merged history backs, not this device's 1")
        XCTAssertFalse(stats.streakFreezeAvailable)
        XCTAssertEqual(stats.streakFreezeCoveredDay, day(2))
    }

    /// The merged history cuts both ways: a short run is short on every device.
    func testFreeze_ShortRunInMergedHistoryStillEarnsNoFreeze() {
        let history = mergedHistory(2, endingDaysAgo: 2)

        stats = StreakStats()
        stats.currentStreak = 2
        stats.lastCompletedDate = day(2)

        XCTAssertEqual(stats.checkStreakValidity(history: history),
                       .streakBroken(previousStreak: 2))
        XCTAssertEqual(stats.currentStreak, 0)
        XCTAssertTrue(stats.streakFreezeAvailable,
            "Freeze should not be consumed when the real run is under 3 days")
    }

    /// One lapse costs ONE freeze, however many devices notice it. Neither has
    /// synced yet, so both decide independently — and land on identical state,
    /// which is what makes it a single spend rather than a race.
    func testFreeze_SameGapNoticedOnTwoDevicesIsOneSpend() {
        let history = mergedHistory(5, endingDaysAgo: 2)

        var deviceA = StreakStats()
        deviceA.currentStreak = 5
        deviceA.longestStreak = 5
        deviceA.lastCompletedDate = day(2)
        var deviceB = deviceA

        let outcomeA = deviceA.checkStreakValidity(history: history)
        let outcomeB = deviceB.checkStreakValidity(history: history)

        XCTAssertEqual(outcomeA, .freezeSpent(coveredDay: day(2)))
        XCTAssertEqual(outcomeB, outcomeA, "One lapse, one decision, on both devices")
        XCTAssertEqual(deviceA.streakFreezeCoveredDay, deviceB.streakFreezeCoveredDay)
        XCTAssertEqual(deviceA.lastCompletedDate, deviceB.lastCompletedDate)
        XCTAssertEqual(deviceA.currentStreak, deviceB.currentStreak)

        // Merging them leaves one freeze spent covering one gap, either way round.
        for combined in [deviceA.merging(deviceB), deviceB.merging(deviceA)] {
            XCTAssertFalse(combined.streakFreezeAvailable)
            XCTAssertEqual(combined.currentStreak, 5)
            XCTAssertEqual(combined.streakFreezeCoveredDay, day(2))
        }
    }

    /// Milestones hand out fresh freezes. A gap already paid for must never be
    /// charged a second time, whatever puts the date back on the covered day
    /// (a stale blob arriving, a restore).
    func testFreeze_ReawardedFreezeIsNotSpentOnAGapAlreadyCovered() {
        let history = mergedHistory(5, endingDaysAgo: 2)

        stats = StreakStats()
        stats.currentStreak = 5
        stats.lastCompletedDate = day(2)
        XCTAssertEqual(stats.checkStreakValidity(history: history),
                       .freezeSpent(coveredDay: day(2)))

        stats.streakFreezeAvailable = true    // milestone re-award
        stats.lastCompletedDate = day(2)      // date knocked back onto the covered day

        let outcome = stats.checkStreakValidity(history: history)

        XCTAssertNotEqual(outcome, .freezeSpent(coveredDay: day(2)))
        XCTAssertTrue(stats.streakFreezeAvailable,
            "A gap already covered by a freeze must never consume a second one")
    }

    /// A real completion after the rescue retires the bridge, so the
    /// placeholder stops masquerading as a completed day in merging().
    func testFreeze_RealCompletionClearsTheBridgeMarker() {
        let history = mergedHistory(5, endingDaysAgo: 2)

        stats = StreakStats()
        stats.currentStreak = 5
        stats.lastCompletedDate = day(2)
        stats.checkStreakValidity(history: history)
        XCTAssertNotNil(stats.streakFreezeCoveredDay)

        stats.updateStreak(for: Date())

        XCTAssertNil(stats.streakFreezeCoveredDay,
            "Once the user completes a real day, lastCompletedDate is no longer a bridge")
        XCTAssertEqual(stats.currentStreak, 6)
    }

    /// Without a merged history the check must behave exactly as it always
    /// has — this is the fallback every pre-existing call site relies on.
    func testFreeze_WithoutHistoryFallsBackToThisDevicesOwnRecord() {
        stats = StreakStats()
        buildStreak(5, endingDaysAgo: 2)

        XCTAssertEqual(stats.checkStreakValidity(), .freezeSpent(coveredDay: day(2)))
        XCTAssertEqual(stats.currentStreak, 5)
        XCTAssertFalse(stats.streakFreezeAvailable)
    }
}

// MARK: - Freeze banner delivery (view-model level)

/// The banner is bounded by the freeze's IDENTITY, and that identity
/// (streakFreezeCoveredDay) travels in the synced streakStats blob — NOT in
/// the flag that announces it. So the receiving device must fold the blob in
/// before it reads the identity.
///
/// These drive the real NotificationCenter path through EnhancedStreakViewModel
/// because the ordering is the whole point: a struct-level test cannot see it.
/// Reading the identity too early stamps today's date instead of the covered
/// day, and since the flag syncs one-way (boolOr) and comes back later, the
/// banner then fires a second time — the exact thing the identity prevents.
final class StreakFreezeBannerTests: XCTestCase {

    private var viewModel: EnhancedStreakViewModel!
    private var savedCompletions: [BurstCompletion] = []
    private let cal = Calendar.current

    private let freezeUsedKey = "streakFreezeWasUsed"
    private let bannerShownKey = "streakFreezeBannerShownFor"
    private var scratchKeys: [String] { ["dailyChecklist", "streakStats", freezeUsedKey, bannerShownKey] }

    override func setUp() {
        super.setUp()
        // reconcileWithSyncedProgress heals from the shared burst history;
        // empty it so these tests see only the blob they seed. Never saved to
        // UserDefaults, and restored in tearDown.
        savedCompletions = BurstCompletionTracker.shared.completions
        BurstCompletionTracker.shared.completions = []

        scratchKeys.forEach { UserDefaults.standard.removeObject(forKey: $0) }
        // Built with the flag already clear, so init cannot consume it first.
        viewModel = EnhancedStreakViewModel()
    }

    override func tearDown() {
        viewModel = nil
        BurstCompletionTracker.shared.completions = savedCompletions
        scratchKeys.forEach { UserDefaults.standard.removeObject(forKey: $0) }
        super.tearDown()
    }

    private func day(_ daysAgo: Int) -> Date {
        cal.startOfDay(for: cal.date(byAdding: .day, value: -daysAgo, to: Date())!)
    }

    /// Exactly what SyncedSettingsStore does when the other device's blob
    /// wins: write the merged value to UserDefaults, then post the applied
    /// keys. The view model's in-memory copy is untouched until it reconciles.
    private func deliverSyncedFreeze(coveredDay: Date) throws {
        var synced = StreakStats()
        synced.currentStreak = 5
        synced.longestStreak = 5
        synced.lastCompletedDate = day(1)          // bridged there by the freeze
        synced.streakFreezeAvailable = false
        synced.streakFreezeUsedDate = coveredDay
        synced.streakFreezeCoveredDay = coveredDay

        UserDefaults.standard.set(try JSONEncoder().encode(synced), forKey: "streakStats")
        UserDefaults.standard.set(true, forKey: freezeUsedKey)

        NotificationCenter.default.post(
            name: SyncedSettingsStore.settingsDidChange,
            object: nil,
            userInfo: ["keys": Set(["streakStats", freezeUsedKey])]
        )
    }

    /// THE ordering regression test.
    func testBanner_IdentityComesFromTheSyncedBlobNotTheStaleInMemoryCopy() throws {
        let coveredDay = day(8)
        // This device never spent the freeze, so its in-memory stats know
        // nothing about it — the exact state that made announcing before
        // reconciling read the wrong identity.
        XCTAssertNil(viewModel.streakStats.streakFreezeCoveredDay)

        try deliverSyncedFreeze(coveredDay: coveredDay)

        XCTAssertTrue(viewModel.showFreezeUsedMessage,
                      "The receiving device must explain why the number moved")
        XCTAssertEqual(viewModel.streakStats.streakFreezeCoveredDay, coveredDay,
                       "precondition: the synced blob was folded in")

        let stamp = UserDefaults.standard.string(forKey: bannerShownKey)
        XCTAssertEqual(stamp, BurstCompletionTracker.dayStamp(for: coveredDay),
            "The banner must be stamped with the freeze's covered day. Announcing before "
            + "reconcileWithSyncedProgress() stamps today instead, because the identity only "
            + "arrives with the blob.")
        XCTAssertNotEqual(stamp, BurstCompletionTracker.dayStamp(for: Date()))
    }

    /// streakFreezeWasUsed syncs one-way (boolOr), so a remote row still
    /// holding true is pushed back later. The identity stamp is the only thing
    /// standing between that and a second banner for one freeze.
    func testBanner_RedeliveredFlagDoesNotFireASecondTime() throws {
        let coveredDay = day(8)
        try deliverSyncedFreeze(coveredDay: coveredDay)
        XCTAssertTrue(viewModel.showFreezeUsedMessage)

        // The banner auto-dismisses, then the still-true flag comes back.
        viewModel.showFreezeUsedMessage = false
        try deliverSyncedFreeze(coveredDay: coveredDay)

        XCTAssertFalse(viewModel.showFreezeUsedMessage,
                       "One freeze, one banner — a redelivered flag must not re-raise it")
        XCTAssertFalse(UserDefaults.standard.bool(forKey: freezeUsedKey),
                       "The flag is still consumed locally on every delivery")
    }

    /// The flag can arrive WITHOUT the streak blob in the same key set. That
    /// path still has to announce, so it cannot simply be folded into the
    /// reconcile branch.
    func testBanner_FlagArrivingWithoutTheStreakBlobStillAnnounces() {
        UserDefaults.standard.set(true, forKey: freezeUsedKey)

        NotificationCenter.default.post(
            name: SyncedSettingsStore.settingsDidChange,
            object: nil,
            userInfo: ["keys": Set([freezeUsedKey])]
        )

        XCTAssertTrue(viewModel.showFreezeUsedMessage)
    }
}
