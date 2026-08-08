//
//  WeeklyFocus.swift
//  SpeakLife
//
//  The week, as opposed to the Anchor.
//
//  `PersonalDeclaration` is a single-record model whose whole emotional payoff
//  is one long-running commitment (`dayCount` → "Day 47 of believing" → It Came
//  to Pass → testimony). Nothing here touches it. WeeklyFocus is a second,
//  additive layer with a 7-day horizon that resets every Sunday by design:
//
//                    The Anchor                 The Week
//    Storage key     personal_declaration_v1    weekly_focus_history_v1
//    Set at          Onboarding                 Every Sunday
//    Horizon         Until it comes to pass     7 days
//    Day count       Keeps climbing             Resets weekly
//
//  The core rule of the feature lives in this file's shape: a week is ALWAYS
//  built. Input upgrades it (`source == .userAnswered`); the absence of input
//  never leaves an empty state — `WeeklyFocusBuilder` walks a fallback ladder
//  instead and stamps which rung produced the week.
//

import Foundation

// MARK: - Source

/// Which rung of the fallback ladder produced this week. Stamped on every
/// record and reported on `weekly_focus_built`, so week-completion rate can be
/// split by source (i.e. "are fallback weeks as good as answered ones?").
enum WeeklyFocusSource: String, Codable {
    /// They answered the Sunday check-in.
    case userAnswered
    /// A prior week's answer, carried forward and re-angled.
    case carryOver
    /// The Anchor — their personal declaration.
    case anchor
    /// SoulProfile, captured at onboarding completion.
    case profile
    /// Recent content interactions.
    case behavioral
    /// Declared notification categories. Always available.
    case `default`
}

// MARK: - Angle

/// How a carried-over need is approached this week. The same stated need in
/// week 2 must get a different angle, not the same declarations reshuffled —
/// this is what decides whether an unanswered week feels alive or feels like
/// the app is stuck.
enum WeeklyFocusAngle: String, Codable {
    /// carryOverCount 0 — what God says about this. Verse-forward.
    case promise
    /// 1 — who I am inside this. Identity + grace.
    case identity
    /// 2 — I speak to it. Warfare + authority.
    case authority
    /// 3+ — change the question, not the answer.
    case escalate

    /// The progression. Anything at or beyond 3 escalates.
    static func forCarryOver(_ count: Int) -> WeeklyFocusAngle {
        switch count {
        case ..<1:  return .promise
        case 1:     return .identity
        case 2:     return .authority
        default:    return .escalate
        }
    }

    /// Categories the selector layers in behind the primary one for this angle.
    /// Deliberately additive: the primary category always leads, these only
    /// shift the flavour of the supporting declarations week over week.
    var supportCategories: [DeclarationCategory] {
        switch self {
        case .promise:   return [.faith, .hope, .godsheart]
        case .identity:  return [.identity, .grace, .love]
        case .authority: return [.warfare, .confidence, .speaklife]
        case .escalate:  return [.miracles, .faith, .spiritualGrowth]
        }
    }
}

// MARK: - WeeklyFocus

struct WeeklyFocus: Codable, Equatable, Identifiable {

    let id: UUID
    /// Sunday 00:00 local, stored absolute so a mid-week timezone change can't
    /// re-anchor a week that is already running.
    let weekStart: Date
    let source: WeeklyFocusSource
    let angle: WeeklyFocusAngle

    /// Their words, verbatim. nil on every rung of the ladder that isn't
    /// derived from something the user actually typed or spoke.
    let needText: String?
    /// Clustering key — coarser than a category, ~20 of them. Drives the
    /// shared devotional cache in Phase 3 and keeps carry-over comparable
    /// across weeks even when the matched category drifts.
    let needBucket: String
    /// `DeclarationCategory` rawValue.
    let categoryRaw: String

    /// Selected from the shipped declaration set. IDs only — nothing is
    /// generated, so there is no hallucinated verse to review and every line
    /// already passes the CLAUDE.md rules.
    let declarationIDs: [String]
    /// "\(needBucket)_w\(weekOfYear)" — a cache key, not content. Unused in
    /// Phase 1; written now so Phase 3's bucket devotionals have a stable
    /// handle on weeks that already shipped.
    let devotionalKey: String
    /// Feeds the existing audio filter ordering as its highest-priority input.
    let audioCategoryRaw: String

    var carryOverCount: Int
    /// 0...6, relative to `weekStart`.
    var completedDays: Set<Int>
    var answeredAt: Date?
    /// Set when the user marks the need resolved. A resolved need is never
    /// carried into the next week.
    var resolvedAt: Date?

    var isAnswered: Bool { source == .userAnswered }

    var dayIndex: Int {
        Calendar.current.dateComponents([.day], from: weekStart, to: Date()).day ?? 0
    }

    /// `dayIndex` held inside the week. Every caller that indexes into
    /// `declarationIDs` or `completedDays` uses this one — a stale record left
    /// by an app that wasn't opened for three weeks would otherwise index past
    /// the end.
    var clampedDayIndex: Int { min(max(dayIndex, 0), 6) }

    var category: DeclarationCategory? {
        DeclarationCategory(rawValue: categoryRaw)
    }

    // MARK: - Storage

    static let storageKey = "weekly_focus_history_v1"
    /// How many weeks of history are kept. Cheap, and it's what makes a
    /// "here's what you've been carrying this year" recap possible later.
    static let historyLimit = 12

    // MARK: - Week math
    //
    // `Calendar.current.firstWeekday` is Monday in most of Europe, so the
    // stock calendar would put `weekStart` on a Monday for a large slice of
    // the user base and quietly break the Sunday-evening premise. Every week
    // boundary in the feature goes through this calendar instead.

    static var weekCalendar: Calendar {
        var calendar = Calendar.current
        calendar.firstWeekday = 1  // Sunday, regardless of locale
        return calendar
    }

    /// Sunday 00:00 local for the week containing `date`.
    static func weekStart(containing date: Date = Date()) -> Date {
        let calendar = weekCalendar
        return calendar.dateInterval(of: .weekOfYear, for: date)?.start
            ?? calendar.startOfDay(for: date)
    }

    /// True when both dates fall in the same Sunday-anchored week.
    static func isSameWeek(_ lhs: Date, _ rhs: Date) -> Bool {
        weekStart(containing: lhs) == weekStart(containing: rhs)
    }

    var weekOfYear: Int {
        WeeklyFocus.weekCalendar.component(.weekOfYear, from: weekStart)
    }

    // MARK: - The ask window
    //
    // Sunday 7:00 PM → Monday 11:59 PM local. The push is the invitation; the
    // in-app card is the real capture surface and stays up for the whole
    // window. Tuesday 00:00 the week locks — no mid-week asking.

    /// Sunday 7:00 PM local.
    var askWindowStart: Date {
        WeeklyFocus.weekCalendar.date(byAdding: .hour, value: 19, to: weekStart) ?? weekStart
    }

    /// Tuesday 00:00 local.
    var askWindowEnd: Date {
        WeeklyFocus.weekCalendar.date(byAdding: .day, value: 2, to: weekStart)
            ?? weekStart.addingTimeInterval(2 * 86_400)
    }

    func isAskWindowOpen(at date: Date = Date()) -> Bool {
        date >= askWindowStart && date < askWindowEnd
    }

    /// 0 on Sunday, 1 on Monday — reported on `weekly_checkin_answered` so a
    /// late answer is distinguishable from a Sunday-night one.
    func dayOfWindow(at date: Date = Date()) -> Int {
        WeeklyFocus.weekCalendar.dateComponents([.day], from: weekStart, to: date).day ?? 0
    }

    // MARK: - Day sequencing
    //
    // `declarationIDs` is stored flat in day order. The selector guarantees a
    // count divisible by 7 (14 or 21), so the slice below is exact — but it
    // degrades safely rather than trapping if a hand-edited or migrated record
    // ever arrives with a ragged count.

    var declarationsPerDay: Int {
        max(1, declarationIDs.count / 7)
    }

    func declarationIDs(forDay day: Int) -> [String] {
        guard !declarationIDs.isEmpty else { return [] }
        let clamped = min(max(day, 0), 6)
        let perDay = declarationIDs.count / 7
        guard perDay > 0 else {
            // Fewer than 7 total — hand out one per day, wrapping.
            return [declarationIDs[clamped % declarationIDs.count]]
        }
        let start = clamped * perDay
        // The last day absorbs any remainder so nothing is silently dropped.
        let end = (clamped == 6) ? declarationIDs.count : min(start + perDay, declarationIDs.count)
        guard start < end else { return [] }
        return Array(declarationIDs[start..<end])
    }

    /// Today's slice, using the clamped day index.
    var todaysDeclarationIDs: [String] {
        declarationIDs(forDay: clampedDayIndex)
    }

    var completedDayCount: Int {
        completedDays.filter { (0...6).contains($0) }.count
    }

    // MARK: - The ask, as policy
    //
    // The question text and the card's visibility rule live on the model, not
    // on the view model, because two surfaces need them: the pinned feed card
    // (a plain SwiftUI view reading a `@State WeeklyFocus?`) and
    // WeeklyFocusViewModel. One definition, so the card can never disagree with
    // the sheet about what is being asked.

    /// `weekStart` of the week whose card the user dismissed.
    static let cardDismissedWeekKey = "weekly_focus_card_dismissed_week"

    /// The question. Swaps at three carry-overs: silently asking the same thing
    /// a fourth time about a need that hasn't moved is what makes an app feel
    /// like it isn't listening.
    var question: String {
        angle == .escalate
            ? "You've been carrying this a while.\nWhat's actually in the way?"
            : "What do you need God's help\nwith this week?"
    }

    var isEscalating: Bool { angle == .escalate }

    /// True when the pinned card should show: the flag is on, the ask window is
    /// open, this week isn't answered, and the card wasn't dismissed for it.
    func shouldShowCard(enabled: Bool,
                        at date: Date = Date(),
                        defaults: UserDefaults = .standard) -> Bool {
        guard enabled, !isAnswered, isAskWindowOpen(at: date) else { return false }
        return defaults.double(forKey: WeeklyFocus.cardDismissedWeekKey) < weekStart.timeIntervalSince1970
    }

    /// Hides the card for the rest of THIS window only. It never disables
    /// future weeks — a "not now" is about tonight, not about the feature.
    func dismissCard(defaults: UserDefaults = .standard) {
        defaults.set(weekStart.timeIntervalSince1970, forKey: WeeklyFocus.cardDismissedWeekKey)
    }

    // MARK: - Buckets
    //
    // ~20 clusters, coarser than DeclarationCategory. Kept here rather than on
    // DeclarationCategory itself because the grouping exists for Weekly Focus
    // caching, not for content browsing, and the two should be free to drift.

    static func bucket(for category: DeclarationCategory) -> String {
        switch category {
        case .anxiety, .fear, .rest:
            return "peace"
        case .health, .wellness, .fertility, .mentalHealth:
            return "healing"
        case .wealth, .debt, .housing:
            return "provision"
        case .work, .business, .education, .favor:
            return "work"
        case .destiny, .obedience:
            return "purpose"
        case .identity, .confidence:
            return "identity"
        case .love, .relationship, .marriage, .divorce:
            return "relationships"
        case .parenting, .singleParent, .salvation:
            return "family"
        case .addiction, .purity, .anger:
            return "freedom"
        case .grief:
            return "grief"
        case .innerHealing, .forgiveness:
            return "restoration"
        case .grace:
            return "grace"
        case .warfare, .blood, .nameOfJesus:
            return "warfare"
        case .godsprotection:
            return "protection"
        case .wisdom:
            return "wisdom"
        case .hope, .newSeason:
            return "hope"
        case .joy, .praise, .gratitude:
            return "joy"
        case .friendship:
            return "belonging"
        case .hardtimes, .miracles:
            return "breakthrough"
        case .spiritualGrowth, .godsheart, .faith, .speaklife:
            return "faith"
        default:
            // Every Bible-book category and anything added later lands here.
            return "faith"
        }
    }

    // MARK: - Construction

    /// The one initializer everything goes through, so `devotionalKey` can
    /// never drift from `needBucket` and `weekStart`.
    init(
        id: UUID = UUID(),
        weekStart: Date,
        source: WeeklyFocusSource,
        angle: WeeklyFocusAngle,
        needText: String?,
        needBucket: String,
        categoryRaw: String,
        declarationIDs: [String],
        audioCategoryRaw: String,
        carryOverCount: Int = 0,
        completedDays: Set<Int> = [],
        answeredAt: Date? = nil,
        resolvedAt: Date? = nil
    ) {
        self.id = id
        self.weekStart = weekStart
        self.source = source
        self.angle = angle
        self.needText = needText
        self.needBucket = needBucket
        self.categoryRaw = categoryRaw
        self.declarationIDs = declarationIDs
        self.audioCategoryRaw = audioCategoryRaw
        self.carryOverCount = carryOverCount
        self.completedDays = completedDays
        self.answeredAt = answeredAt
        self.resolvedAt = resolvedAt

        let week = WeeklyFocus.weekCalendar.component(.weekOfYear, from: weekStart)
        self.devotionalKey = "\(needBucket)_w\(week)"
    }
}
