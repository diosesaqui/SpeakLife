//
//  BuildWeeklyFocusUseCase.swift
//  SpeakLife
//
//  The week is always built. Runs on launch and on every foreground; builds at
//  most once per week and returns the cached record every time after that.
//
//  The spec's Sunday-5:00-PM silent build is what this approximates without a
//  background task: content is ready before anyone is asked anything, because
//  the first open of the new week produces it locally in milliseconds. There is
//  no network on this path, so there is nothing to be slow or to fail.
//

import Foundation

final class BuildWeeklyFocusUseCase {

    private let repository: WeeklyFocusRepositoryProtocol
    private let builder: WeeklyFocusBuilderProtocol
    private let scheduler: WeeklyCheckInSchedulerProtocol

    init(repository: WeeklyFocusRepositoryProtocol,
         builder: WeeklyFocusBuilderProtocol,
         scheduler: WeeklyCheckInSchedulerProtocol) {
        self.repository = repository
        self.builder = builder
        self.scheduler = scheduler
    }

    /// Ensures a week exists for the week containing `now`. Idempotent —
    /// returns the existing record untouched when there is one.
    @discardableResult
    func execute(now: Date = Date()) async -> WeeklyFocus {
        if let existing = await repository.current() {
            return existing
        }

        let weekStart = WeeklyFocus.weekStart(containing: now)

        // The week that just closed. If it was never answered, that's a
        // deliberate signal — count it toward the push decay before building
        // the new one. Only weeks that were actually asked about count: a week
        // built before the user ever had the feature isn't an ignored ask.
        if let previous = await repository.previousWeek(before: weekStart),
           previous.answeredAt == nil,
           previous.weekStart >= weekStart.addingTimeInterval(-14 * 86_400) {
            scheduler.noteIgnoredWeek(weekStart: previous.weekStart)
        }

        let focus = await builder.build(for: weekStart, answer: nil)
        try? await repository.save(focus)

        AnalyticsService.shared.track("weekly_focus_built", parameters: [
            "source": focus.source.rawValue,
            "angle": focus.angle.rawValue,
            "carry_over_count": focus.carryOverCount,
            "need_bucket": focus.needBucket
        ])

        // Silently regenerating a fourth week on the same unmoved need is the
        // wrong response — the escalation path (Phase 4) changes the question
        // instead. Phase 1 only records that the moment arrived, so the size of
        // the cohort is known before the path is built.
        if focus.angle == .escalate {
            AnalyticsService.shared.track("weekly_focus_escalated", parameters: [
                "need_bucket": focus.needBucket,
                "carry_over_count": focus.carryOverCount
            ])
        }

        // Re-assert the repeating Sunday trigger on every new week. iOS drops
        // pending requests on force-quit, throttling, and OS state resets, and
        // the identifier is stable so this replaces in place rather than
        // queueing a duplicate.
        scheduler.schedule()

        return focus
    }
}
