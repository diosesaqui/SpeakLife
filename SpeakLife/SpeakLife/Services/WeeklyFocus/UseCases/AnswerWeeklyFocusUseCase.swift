//
//  AnswerWeeklyFocusUseCase.swift
//  SpeakLife
//
//  The answer arrives at some point inside a two-day window, and the week is
//  already running by then. If it lands Monday evening, days 1–2 have been
//  consumed — throwing them away would rewrite content the user already spoke,
//  so only the REMAINING days are rebuilt and the UI says so:
//
//      "Updated for the rest of your week."
//
//  Completed days survive the rebuild for the same reason.
//

import Foundation

final class AnswerWeeklyFocusUseCase {

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

    /// - Parameters:
    ///   - surface: push | card | interstitial | overview — where the ask was seen.
    ///   - inputMethod: voice | text.
    ///   - secondsToAnswer: from the sheet appearing to submit.
    /// - Returns: the saved week, and whether any day had already been consumed
    ///   (which is what the "rest of your week" copy keys off).
    @discardableResult
    func execute(answer: String,
                 surface: String,
                 inputMethod: String,
                 secondsToAnswer: Double,
                 now: Date = Date()) async throws -> (focus: WeeklyFocus, isPartialWeek: Bool) {

        let weekStart = WeeklyFocus.weekStart(containing: now)
        let existing = await repository.current()
        let built = await builder.build(for: weekStart, answer: answer)

        let consumedDays = existing?.clampedDayIndex ?? 0
        let isPartialWeek = consumedDays > 0

        let merged = WeeklyFocus(
            // Keep the provisional week's identity so anything already keyed on
            // it (analytics, a day-completion in flight) still lines up.
            id: existing?.id ?? built.id,
            weekStart: weekStart,
            source: .userAnswered,
            angle: built.angle,
            needText: built.needText,
            needBucket: built.needBucket,
            categoryRaw: built.categoryRaw,
            declarationIDs: Self.mergeDays(existing: existing, built: built, consumedDays: consumedDays),
            audioCategoryRaw: built.audioCategoryRaw,
            carryOverCount: 0,
            completedDays: existing?.completedDays ?? [],
            answeredAt: now,
            resolvedAt: nil
        )

        try await repository.save(merged)
        scheduler.noteAnswered()

        AnalyticsService.shared.track("weekly_checkin_answered", parameters: [
            "surface": surface,
            "input_method": inputMethod,
            "seconds_to_answer": Int(secondsToAnswer.rounded()),
            "day_of_window": merged.dayOfWindow(at: now),
            "need_bucket": merged.needBucket
        ])
        AnalyticsService.shared.track("weekly_focus_built", parameters: [
            "source": merged.source.rawValue,
            "angle": merged.angle.rawValue,
            "carry_over_count": merged.carryOverCount,
            "need_bucket": merged.needBucket
        ])

        return (merged, isPartialWeek)
    }

    // MARK: - Day merge

    /// Days before `consumedDays` keep whatever the user was already given;
    /// every remaining day comes from the answered build.
    ///
    /// The two records can in principle disagree on declarations-per-day (a
    /// thin scored pool yields 14 rather than 21), and the flat array has to
    /// stay evenly sliceable or `declarationIDs(forDay:)` would hand out the
    /// wrong lines for the rest of the week. So the built record's per-day size
    /// wins and kept days are padded or trimmed to match it.
    private static func mergeDays(existing: WeeklyFocus?,
                                  built: WeeklyFocus,
                                  consumedDays: Int) -> [String] {
        guard let existing, consumedDays > 0 else { return built.declarationIDs }

        let perDay = built.declarationsPerDay
        var merged: [String] = []
        merged.reserveCapacity(built.declarationIDs.count)

        for day in 0..<7 {
            let builtSlice = built.declarationIDs(forDay: day)
            guard day < consumedDays else {
                merged.append(contentsOf: builtSlice)
                continue
            }
            var kept = existing.declarationIDs(forDay: day)
            if kept.count > perDay {
                kept = Array(kept.prefix(perDay))
            } else if kept.count < perDay {
                // Pad from the built slice rather than repeating what they
                // already spoke.
                for id in builtSlice where kept.count < perDay {
                    guard !kept.contains(id) else { continue }
                    kept.append(id)
                }
                // Still short only if the built slice was itself short; fall
                // back to repeating so the array stays evenly sliceable.
                while kept.count < perDay, let last = kept.last ?? builtSlice.last {
                    kept.append(last)
                }
            }
            merged.append(contentsOf: kept)
        }
        return merged
    }
}
