//
//  WeeklyCheckInSchedulerProtocol.swift
//  SpeakLife
//

import Foundation

/// The Sunday 7:00 PM local invitation. A repeating local notification — no
/// server, no cron, no timezone fan-out.
protocol WeeklyCheckInSchedulerProtocol {
    /// Schedules (or re-schedules) the check-in at whatever cadence the current
    /// ignore streak calls for. Idempotent: the identifier is stable, so iOS
    /// replaces the pending request in place.
    func schedule()

    func cancel()

    /// The user answered. Resets the ignore streak, which restores the weekly
    /// cadence if it had decayed to monthly.
    func noteAnswered()

    /// A week closed without an answer. Advances the ignore streak; at four in
    /// a row the push decays to monthly. Idempotent per week — calling it twice
    /// for the same `weekStart` counts once.
    func noteIgnoredWeek(weekStart: Date)
}
