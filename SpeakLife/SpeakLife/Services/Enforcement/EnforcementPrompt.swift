//
//  EnforcementPrompt.swift
//  SpeakLife
//
//  The weekly invitation to start a campaign.
//
//  Fires only when nothing is running — nagging someone mid-week is noise, and
//  slot 0 already belongs to that week's anchor when a campaign is active. The
//  two can never collide, so this costs zero net notifications against the
//  64-pending budget.
//

import Foundation

enum EnforcementPrompt {

    struct Copy {
        let title: String
        let body: String
    }

    /// Rotated so someone who ignores it three weeks running doesn't see the
    /// same words each time. Ordered by strength: the verdict frame leads.
    static let rotation: [Copy] = [
        Copy(title: "What are you enforcing this week?",
             body: "The verdict came down at the cross. Name one thing you're walking through and stand on it for seven days. \"It is finished.\" (John 19:30)"),
        Copy(title: "Start with hearing",
             body: "Whatever you're facing this week, don't speak at it first. Hear the Word on it until faith rises. Tell us what it is and we'll set your seven days. (Rom 10:17)"),
        Copy(title: "Fresh week, fresh mercies",
             body: "New mercies this morning. What do you want to stand on for the next seven days? Name it and we'll build the week around His promises. (Lam 3:22-23)")
    ]

    /// Which day of the scheduling batch carries the prompt, and the copy for it.
    ///
    /// - Parameter dayOffset: 0-based day within the pending batch.
    /// - Returns: nil on every day except the one that lands on `promptWeekday`,
    ///   and nil entirely when the user isn't eligible or is mid-campaign.
    static func copy(forDayOffset dayOffset: Int,
                     now: Date = Date(),
                     calendar: Calendar = .autoupdatingCurrent,
                     service: EnforcementService = .shared,
                     defaults: UserDefaults = .standard) -> Copy? {
        guard service.isEnabled else { return nil }
        guard !service.progressSnapshot.isActive else { return nil }

        // Same tenure gate as the card. Prompting someone who can't yet act on
        // it is a dead end.
        let totalDays = totalDaysCompleted(defaults: defaults)
        guard service.isEligible(totalDaysCompleted: totalDays) else { return nil }

        guard let date = calendar.date(byAdding: .day, value: dayOffset, to: now) else { return nil }
        guard calendar.component(.weekday, from: date) == promptWeekday else { return nil }

        // Advance the copy by ISO week so consecutive weeks differ, and it stays
        // stable within a week no matter when the batch is rebuilt.
        let week = calendar.component(.weekOfYear, from: date)
        return rotation[week % rotation.count]
    }

    /// Sunday. The week is about to turn, and it's when people take stock.
    static let promptWeekday = 1

    /// Reads the persisted streak blob rather than taking an `EnhancedStreakViewModel`
    /// dependency — this runs on the notification scheduler's queue, which has no
    /// view models.
    private static func totalDaysCompleted(defaults: UserDefaults) -> Int {
        guard let data = defaults.data(forKey: "streakStats"),
              let stats = try? JSONDecoder().decode(StreakStats.self, from: data) else {
            return 0
        }
        return stats.totalDaysCompleted
    }
}
