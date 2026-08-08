//
//  CompleteWeeklyDayUseCase.swift
//  SpeakLife
//

import Foundation

/// Marks a day of the current week done.
///
/// Week-completion rate split by `source` is the secondary metric that answers
/// the question the fallback ladder exists to raise: are ladder-built weeks as
/// good as answered ones? That comparison only works if the event carries the
/// source, so it is stamped here rather than at the call site.
final class CompleteWeeklyDayUseCase {

    private let repository: WeeklyFocusRepositoryProtocol

    init(repository: WeeklyFocusRepositoryProtocol) {
        self.repository = repository
    }

    func execute(day: Int) async throws {
        guard (0...6).contains(day) else { return }
        guard let focus = await repository.current() else { return }
        // Idempotent: re-tapping a completed day is not a second completion.
        guard !focus.completedDays.contains(day) else { return }

        try await repository.markDayComplete(day)

        AnalyticsService.shared.track("weekly_focus_day_completed", parameters: [
            "day_index": day,
            "source": focus.source.rawValue,
            "need_bucket": focus.needBucket
        ])
    }
}
