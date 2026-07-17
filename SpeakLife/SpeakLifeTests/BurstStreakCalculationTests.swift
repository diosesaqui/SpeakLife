//
//  BurstStreakCalculationTests.swift
//  SpeakLifeTests
//
//  Regression tests for the history-derived streak. A streak whose last
//  completed day is yesterday is still alive until today ends, so it must
//  never read 0 just because today's burst isn't done yet — that morning-zero
//  defeated the streakStats heals and left the badge below the week strip.
//

import XCTest
@testable import SpeakLife

final class BurstStreakCalculationTests: XCTestCase {

    private let calendar = Calendar.current

    override func setUp() {
        super.setUp()
        // Keep BurstCompletionTracker.init from pushing history to the sync store.
        UserDefaults.standard.set(true, forKey: "sl_burstHistoryPushedToSync_v1")
        UserDefaults.standard.removeObject(forKey: "burstCompletions")
        UserDefaults.standard.removeObject(forKey: "dailyChecklist")
        UserDefaults.standard.removeObject(forKey: "streakStats")
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: "burstCompletions")
        UserDefaults.standard.removeObject(forKey: "dailyChecklist")
        UserDefaults.standard.removeObject(forKey: "streakStats")
        super.tearDown()
    }

    private func completion(daysAgo: Int) -> BurstCompletion {
        let day = calendar.startOfDay(for: calendar.date(byAdding: .day, value: -daysAgo, to: Date())!)
        return BurstCompletion(
            date: day,
            completedAt: day.addingTimeInterval(9 * 60 * 60),
            declarationCount: 7,
            timeSpent: 120,
            spiritualStrengthScore: 50
        )
    }

    private func makeTracker(daysAgo: [Int]) -> BurstCompletionTracker {
        let tracker = BurstCompletionTracker()
        tracker.completions = daysAgo.map { completion(daysAgo: $0) }
        return tracker
    }

    // MARK: - History-derived streak

    func testStreakStillAliveWhenTodayNotYetCompleted() {
        // Five consecutive days ending yesterday, today's burst not done yet.
        let tracker = makeTracker(daysAgo: [5, 4, 3, 2, 1])
        XCTAssertEqual(tracker.currentStreak, 5,
            "A streak ending yesterday is alive until midnight; it must not read 0 before today's burst")
    }

    func testStreakIncludesTodayWhenCompleted() {
        let tracker = makeTracker(daysAgo: [4, 3, 2, 1, 0])
        XCTAssertEqual(tracker.currentStreak, 5)
    }

    func testStreakBrokenWhenYesterdayWasMissed() {
        // Last completion two days ago — a full day was missed.
        let tracker = makeTracker(daysAgo: [5, 4, 3, 2])
        XCTAssertEqual(tracker.currentStreak, 0)
    }

    func testStreakZeroWithNoCompletions() {
        let tracker = makeTracker(daysAgo: [])
        XCTAssertEqual(tracker.currentStreak, 0)
    }

    func testGapFurtherBackLimitsStreak() {
        // Missed three days ago: only yesterday and the day before count.
        let tracker = makeTracker(daysAgo: [5, 4, 2, 1])
        XCTAssertEqual(tracker.currentStreak, 2)
    }

    // MARK: - Badge heal at launch

    func testViewModelHealsUndercountedBadgeOnLaunch() {
        // The field bug: streakStats fell behind (badge showed 4) while the
        // per-day burst history had 5 consecutive days ending yesterday.
        var stats = StreakStats()
        stats.currentStreak = 4
        stats.longestStreak = 4
        stats.totalDaysCompleted = 4
        stats.lastCompletedDate = calendar.startOfDay(for: calendar.date(byAdding: .day, value: -1, to: Date())!)
        UserDefaults.standard.set(try! JSONEncoder().encode(stats), forKey: "streakStats")

        let previousShared = BurstCompletionTracker.shared.completions
        defer { BurstCompletionTracker.shared.completions = previousShared }
        BurstCompletionTracker.shared.completions = [5, 4, 3, 2, 1].map { completion(daysAgo: $0) }

        let viewModel = EnhancedStreakViewModel()

        XCTAssertEqual(viewModel.streakStats.currentStreak, 5,
            "Launch reconcile must raise the badge to match the completed-day history")
        XCTAssertEqual(viewModel.streakStats.longestStreak, 5)
        XCTAssertEqual(viewModel.streakStats.totalDaysCompleted, 5)
    }
}
