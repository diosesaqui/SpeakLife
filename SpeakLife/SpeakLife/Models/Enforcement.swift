//
//  Enforcement.swift
//  SpeakLife
//
//  An Enforcement is a finite, themed seven-day campaign that rides on habits the user
//  already has. It generalizes `FoundationAudioPlan` (DailyChecklistModels.swift):
//  where that plan is welded to `currentStreak`, runs once per install, and is
//  invisible beyond retitling one task, an Enforcement is repeatable, themed, visible,
//  and completable.
//

import Foundation

// MARK: - Enforcement Day

/// One day of an Enforcement: the line the user speaks, and the audio they hear.
struct EnforcementDay: Codable, Equatable {
    let dayNumber: Int
    let anchorText: String
    let anchorVerse: String
    /// Reference only, e.g. "Isaiah 26:3".
    let anchorBook: String
    /// Kept so every quoted verse stays auditable to its source translation.
    let anchorTranslation: String
    let audioId: String
    let audioTitle: String
    let audioMinutes: Int

    /// Bridges to the shape the checklist's audio plan already speaks
    /// (`DailyChecklistModels.swift`), so the deep-link path is shared rather
    /// than duplicated.
    var audio: FoundationAudio {
        FoundationAudio(audioId: audioId, title: audioTitle, durationMinutes: audioMinutes)
    }
}

// MARK: - Enforcement

struct Enforcement: Codable, Identifiable, Equatable {
    /// Every Enforcement is seven days. Encoded once here so the UI, the progress
    /// model, and the completion check can never disagree about the finish line.
    static let length = 7

    let id: String
    let title: String
    /// One line, shown under the title on the card. Not a declaration.
    let tagline: String
    /// `DeclarationCategory` rawValue — ties the Enforcement to the user's onboarding
    /// picks and to the declaration pool the burst draws from.
    let theme: String
    let days: [EnforcementDay]

    var category: DeclarationCategory? {
        DeclarationCategory(rawValue: theme)
    }

    /// Display name for the theme, falling back to the raw value so a content
    /// typo degrades to something readable instead of an empty label.
    var themeName: String {
        category?.name ?? theme.capitalized
    }

    /// True for a campaign built at runtime rather than hand-authored in
    /// `enforcements.json`. Assembly and curation both stamp their id.
    var isGenerated: Bool {
        id.hasPrefix("assembled_") || id.hasPrefix("curated_")
    }

    /// The title as it should read today, not as it read the day the campaign
    /// started.
    ///
    /// A generated campaign is persisted whole, title included, and synced to
    /// iCloud that way. So a week begun before `enforcementTitle` shipped keeps
    /// its old name for all seven days: the card still reads ENFORCING WARFARE
    /// & VICTORY even on a build where the bug is fixed. Re-deriving on read
    /// corrects those in flight instead of waiting them out.
    ///
    /// Hand-authored campaigns are returned untouched — their titles are
    /// deliberate content, and `enforcements.json` already names them for the
    /// victory (Enforcing Peace, Provision, Healing, Victory).
    var displayTitle: String {
        guard isGenerated, let category else { return title }
        return "Enforcing " + category.enforcementTitle
    }

    func day(_ number: Int) -> EnforcementDay? {
        days.first { $0.dayNumber == number }
    }
}

/// Root of `enforcements.json`. Mirrors `WelcomeResponse` (LazyJSONLoader.swift) so
/// content ships and versions the same way declarations do.
struct EnforcementCatalog: Codable {
    let version: Int
    let enforcements: [Enforcement]
}

// MARK: - Progress

/// The user's position in an Enforcement.
///
/// **This is deliberately not derived from dates or from `StreakStats`.**
/// `currentDay` counts completed days and nothing else, so an absence never
/// advances or resets an Enforcement — day 4 stays day 4 through a two-week gap. The
/// streak is the thing you can lose; the Enforcement is the thing that waits for you.
/// That asymmetry is the entire re-entry mechanic, so any change that makes a
/// Enforcement expire on the calendar defeats the feature.
struct EnforcementProgress: Codable, Equatable {
    var activeEnforcementId: String?
    /// The campaign itself, when it was assembled from the declaration pool
    /// rather than read from `enforcements.json`.
    ///
    /// Stored whole, deliberately. Assembly needs the full 3,156-declaration
    /// pool, which loads asynchronously and is not available to the notification
    /// scheduler on a background queue. Persisting the assembled result means the
    /// campaign is built exactly once — at start, on the main thread, where the
    /// pool is in hand — and every later reader just decodes it. It also
    /// guarantees day 3 is the same line next week as it is today.
    var assembledEnforcement: Enforcement?
    var startedOn: Date?
    var completedDayNumbers: Set<Int> = []
    /// Only ever used to make advancement idempotent within a calendar day.
    /// Never used to compute which day the user is on.
    var lastAdvancedOn: Date?
    var completedEnforcementIds: [String] = []

    /// The day the user is working on now, 1...7.
    var currentDay: Int {
        min(completedDayNumbers.count + 1, Enforcement.length)
    }

    var isComplete: Bool {
        completedDayNumbers.count >= Enforcement.length
    }

    var isActive: Bool {
        activeEnforcementId != nil && !isComplete
    }

    func hasAdvancedToday(calendar: Calendar = .current, now: Date = Date()) -> Bool {
        guard let lastAdvancedOn else { return false }
        return calendar.isDate(lastAdvancedOn, inSameDayAs: now)
    }

    /// Clears the active campaign, banking it as completed. Kept here so the
    /// service can't forget to record the completion.
    mutating func finish() {
        if let activeEnforcementId, !completedEnforcementIds.contains(activeEnforcementId) {
            completedEnforcementIds.append(activeEnforcementId)
        }
        activeEnforcementId = nil
        assembledEnforcement = nil
        startedOn = nil
        completedDayNumbers = []
        lastAdvancedOn = nil
    }
}
