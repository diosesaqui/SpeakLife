//
//  WeeklyFocusRepositoryProtocol.swift
//  SpeakLife
//

import Foundation

/// Persistence for the week. Unlike `PersonalDeclarationRepositoryProtocol`,
/// which owns exactly one record, this keeps an array of the last 12 weeks —
/// history is what makes the year-end "here's what you've been carrying" recap
/// possible, and it has to exist from day one to be worth anything.
protocol WeeklyFocusRepositoryProtocol {
    /// Upserts by `weekStart`: saving a week that already exists replaces it in
    /// place rather than stacking a duplicate.
    func save(_ focus: WeeklyFocus) async throws

    /// The record for the week containing now, or nil when this week has not
    /// been built yet.
    func current() async -> WeeklyFocus?

    /// Newest first.
    func history(limit: Int) async -> [WeeklyFocus]

    /// The most recent week strictly BEFORE the one containing `date`. The
    /// carry-over rung of the ladder reads this, and it must never see the
    /// provisional week it is being asked to build.
    func previousWeek(before date: Date) async -> WeeklyFocus?

    /// Marks a day (0...6) of the current week complete. No-op when there is no
    /// current week or the day is out of range.
    func markDayComplete(_ day: Int) async throws

    /// Marks the current week's need resolved, so the carry-over rung stops
    /// carrying it into next week.
    func markResolved() async throws
}
