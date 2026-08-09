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

    /// Six variants, so a weekly send doesn't repeat inside a quarter.
    ///
    /// Every one states the exchange plainly: name one thing, get seven days
    /// built on it. That is the only job this notification has, and the previous
    /// copy buried it. Those ran 140 to 190 characters, which truncates on a
    /// lock screen — and the part that got cut was the second half, where the
    /// offer lived. Someone scanning the banner saw a question and no reason to
    /// answer it.
    ///
    /// No scripture references here, deliberately. Each costs about twelve
    /// characters that the offer needs more, and this is a prompt asking for
    /// input rather than a devotional. The teaching is the seven days they get
    /// afterward.
    ///
    /// Every variant admits a fight OR something they're believing for. The old
    /// copy only invited a storm ("what you're walking through"), so anyone
    /// opening the app in a good week read it as not for them.
    static let rotation: [Copy] = [
        Copy(title: "Name one thing",
             body: "A fight or a promise. We'll build seven days of Scripture on it."),
        Copy(title: "Set your week",
             body: "Tell us what you're facing or believing for. We'll build the seven days."),
        Copy(title: "What are you standing on?",
             body: "Name it, and we'll build seven days of declarations around it."),
        Copy(title: "One thing, seven days",
             body: "Tell us what you're carrying. We'll build the week's declarations on it."),
        Copy(title: "Sunday reset",
             body: "Name one thing you're up against or believing for. We'll build the week."),
        Copy(title: "Don't drift into Monday",
             body: "Name one thing. We'll build seven days of Scripture around it.")
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
