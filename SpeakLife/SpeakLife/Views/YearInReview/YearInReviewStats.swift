//
//  YearInReviewStats.swift
//  SpeakLife
//
//  Rolls up a calendar year's worth of BurstCompletion records into the
//  numbers shown on the Year in Review slides, and holds the pure decisions
//  around them (when the recap is open, which slides show, what a share
//  says) so they can be unit tested without a view.
//
//  Every number here comes from Daily Burst completions only. Declarations
//  swiped in the feed, audio and devotionals are not counted, so the copy
//  says "Daily Burst" wherever it shows the declaration total.
//

import Foundation

struct YearInReviewStats: Identifiable {
    var id: Int { year }
    let year: Int
    let daysActive: Int
    let longestStreakInYear: Int
    let bestMonth: (name: String, count: Int)?
    /// Declarations spoken in Daily Burst sessions this year. Not every
    /// declaration the user spoke anywhere in the app.
    let totalDeclarationsSpoken: Int
    let currentStreak: Int
    /// Highest spiritual-strength level the user reached across the year.
    /// Powers the premium-only "Strength Level" bonus slide.
    let peakStrengthLevel: BurstCompletionTracker.StrengthLevel
    let peakStrengthScore: Int
    /// When the recap was built. In December the year is still running, so
    /// percentages and copy are measured against this day, not Dec 31.
    let asOf: Date
    /// The calendar every date rule here runs on. Gregorian whatever the
    /// device is set to: on a Japanese or Buddhist calendar the "year" is
    /// not 2026, and on Hebrew or Islamic month 12 is not December.
    var calendar: Calendar = YearInReviewStats.gregorian

    /// Gregorian in the device's own time zone, so "Dec 1" is the user's
    /// Dec 1.
    static var gregorian: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        calendar.locale = .current
        return calendar
    }

    /// Recap is meaningful only if the user showed up at all this year.
    var hasMeaningfulActivity: Bool { daysActive >= 1 }

    /// True while the recapped year is still running (the December window).
    var isInProgress: Bool {
        Self.isInProgress(year: year, asOf: asOf, calendar: calendar)
    }

    /// Days active as a percent of the year so far (or the whole year, once
    /// it has closed).
    var percentOfYear: Int {
        Self.percentOfYear(daysActive: daysActive, year: year, asOf: asOf, calendar: calendar)
    }

    /// The year after the recap, which the closing declaration speaks over.
    var nextYear: Int { year + 1 }

    /// Builds the stats by filtering BurstCompletionTracker.shared.completions
    /// down to a single calendar year. We pull `currentStreak` from the same
    /// source so it matches what the user sees on their streak screen.
    static func build(for year: Int, asOf: Date = Date(),
                      calendar: Calendar = YearInReviewStats.gregorian) -> YearInReviewStats {
        let components = DateComponents(year: year, month: 1, day: 1)
        let yearStart = calendar.date(from: components) ?? Date()
        let yearEnd = calendar.date(byAdding: .year, value: 1, to: yearStart) ?? Date()

        let inYear = BurstCompletionTracker.shared.completions.filter {
            $0.date >= yearStart && $0.date < yearEnd
        }

        let uniqueDayStarts = Set(inYear.map { calendar.startOfDay(for: $0.date) })
        let daysActive = uniqueDayStarts.count

        let longest = longestConsecutiveRun(in: uniqueDayStarts, calendar: calendar)

        let best: (name: String, count: Int)?
        if let top = bestMonth(in: inYear.map { $0.date }, calendar: calendar) {
            best = (name: monthName(top.month, calendar: calendar), count: top.days)
        } else {
            best = nil
        }

        let totalDeclarations = inYear.map { $0.declarationCount }.reduce(0, +)

        let peakScore = inYear.map { $0.spiritualStrengthScore }.max() ?? 0
        let peakLevel = strengthLevel(for: peakScore)

        return YearInReviewStats(
            year: year,
            daysActive: daysActive,
            longestStreakInYear: longest,
            bestMonth: best,
            totalDeclarationsSpoken: totalDeclarations,
            currentStreak: BurstCompletionTracker.shared.currentStreak,
            peakStrengthLevel: peakLevel,
            peakStrengthScore: peakScore,
            asOf: asOf,
            calendar: calendar
        )
    }

    private static func strengthLevel(for score: Int) -> BurstCompletionTracker.StrengthLevel {
        for level in BurstCompletionTracker.StrengthLevel.allCases.reversed() {
            if score >= level.minimumScore { return level }
        }
        return .warrior
    }

    private static func longestConsecutiveRun(in dayStarts: Set<Date>,
                                              calendar: Calendar) -> Int {
        guard !dayStarts.isEmpty else { return 0 }
        let sorted = dayStarts.sorted()
        var longest = 1
        var current = 1
        for i in 1..<sorted.count {
            let prev = sorted[i - 1]
            let next = sorted[i]
            if let oneDayLater = calendar.date(byAdding: .day, value: 1, to: prev),
               calendar.isDate(oneDayLater, inSameDayAs: next) {
                current += 1
                longest = max(longest, current)
            } else {
                current = 1
            }
        }
        return longest
    }

    /// The month (1 to 12) with the most distinct active days. On a tie the
    /// later month wins: it is the more recent strength, and walking the
    /// months in order gives the same answer on every run (the old
    /// `Dictionary.max` picked whichever tied month it happened to hash first).
    static func bestMonth(in dates: [Date], calendar: Calendar) -> (month: Int, days: Int)? {
        var perMonthDays: [Int: Set<Date>] = [:]
        for date in dates {
            let month = calendar.component(.month, from: date)
            perMonthDays[month, default: []].insert(calendar.startOfDay(for: date))
        }

        var best: (month: Int, days: Int)?
        for month in perMonthDays.keys.sorted() {
            let days = perMonthDays[month]?.count ?? 0
            if days > 0, days >= (best?.days ?? 0) {
                best = (month: month, days: days)
            }
        }
        return best
    }

    private static func monthName(_ month: Int, calendar: Calendar) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.dateFormat = "LLLL"
        let monthDate = calendar.date(from: DateComponents(year: 2001, month: month, day: 1)) ?? Date()
        return formatter.string(from: monthDate)
    }
}

// MARK: - Slides

/// One page of the recap. The raw value is the `slide` property on the
/// `year_in_review_slide_viewed` and `year_in_review_shared` events, so it
/// must stay stable once shipped.
enum YearInReviewSlide: String, CaseIterable, Hashable {
    case cover
    case days
    case longestStreak = "longest_streak"
    case bestMonth = "best_month"
    case totals
    case strength
    case summary
    case nextYear = "next_year"

    /// The cover is a title page; every other slide has a card worth posting.
    var isShareable: Bool { self != .cover }
}

extension YearInReviewStats {

    // MARK: Window

    /// The year the recap covers on `date`, or nil outside the window.
    ///
    /// The window opens Dec 1, while Spotify Wrapped has everyone sharing,
    /// and recaps the year still in progress. From Jan 1 to Jan 15 it recaps
    /// the year that just closed. Any other day it is shut.
    static func recapYear(for date: Date, calendar: Calendar = YearInReviewStats.gregorian) -> Int? {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        guard let year = parts.year, let month = parts.month, let day = parts.day else { return nil }
        if month == 12 { return year }
        if month == 1 && day <= 15 { return year - 1 }
        return nil
    }

    /// Whether `asOf` falls inside `year`, meaning the year has not closed.
    static func isInProgress(year: Int, asOf: Date, calendar: Calendar) -> Bool {
        calendar.component(.year, from: asOf) == year
    }

    // MARK: Percent of year

    /// Days active as a whole percent of the days available. For a year still
    /// running that is Jan 1 through `asOf` inclusive, so 300 days by Dec 1
    /// reads 90%, not 82%. For a closed year it is the full 365 or 366.
    /// Never reads 100% unless every available day was active.
    static func percentOfYear(daysActive: Int, year: Int, asOf: Date, calendar: Calendar) -> Int {
        guard daysActive > 0,
              let yearStart = calendar.date(from: DateComponents(year: year, month: 1, day: 1)),
              let nextYearStart = calendar.date(byAdding: .year, value: 1, to: yearStart) else { return 0 }

        let fullYear = calendar.dateComponents([.day], from: yearStart, to: nextYearStart).day ?? 365
        var available = fullYear
        if asOf >= yearStart && asOf < nextYearStart {
            let elapsed = (calendar.dateComponents([.day], from: yearStart,
                                                   to: calendar.startOfDay(for: asOf)).day ?? 0) + 1
            available = min(max(elapsed, 1), fullYear)
        }

        let percent = Int((Double(daysActive) / Double(available) * 100).rounded())
        let cap = daysActive >= available ? 100 : 99
        return min(max(percent, 0), cap)
    }

    // MARK: Slides

    /// The slides this recap shows, in order. A slide whose number is empty
    /// is dropped rather than shown as a zero; the Strength slide is a
    /// premium bonus. It always ends on the summary card and then the
    /// declaration for the year ahead.
    func slides(includesPremiumExtras: Bool) -> [YearInReviewSlide] {
        var slides: [YearInReviewSlide] = [.cover]
        if daysActive > 0 { slides.append(.days) }
        if longestStreakInYear > 0 { slides.append(.longestStreak) }
        if bestMonth != nil { slides.append(.bestMonth) }
        if totalDeclarationsSpoken > 0 { slides.append(.totals) }
        if includesPremiumExtras { slides.append(.strength) }
        slides.append(.summary)
        slides.append(.nextYear)
        return slides
    }

    // MARK: Copy

    /// The closing declaration, spoken over the year ahead. First person,
    /// present tense, one sentence (CLAUDE.md).
    var nextYearDeclaration: String {
        "I step into \(nextYear) rooted, unshakeable and full of His Word."
    }

    /// "in 2026", or "so far in 2026" while the year is still running, so no
    /// line claims a whole year that has not finished.
    var periodPhrase: String {
        isInProgress ? "so far in \(year)" : "in \(year)"
    }

    // MARK: Formatting

    /// A count with grouping ("12,450"), so big totals stay readable on the
    /// cards and in share text.
    static func formattedCount(_ value: Int, locale: Locale = .current) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = true
        formatter.locale = locale
        return formatter.string(from: NSNumber(value: value)) ?? String(value)
    }

    // MARK: Share text

    /// The words that ride with a shared card. Written as an invitation, not
    /// a scoreboard. Each ends on a full stop because `ReferralShareText` puts
    /// the tracked link on the next line when the share goes to a chat; for
    /// a post or a saved image the words go alone.
    func shareWords(for slide: YearInReviewSlide, locale: Locale = .current) -> String {
        let count: (Int) -> String = { Self.formattedCount($0, locale: locale) }
        let days = daysActive == 1 ? "1 day" : "\(count(daysActive)) days"

        let line: String
        switch slide {
        case .days:
            line = "I spoke God's Word over my life on \(days) \(periodPhrase). Start your year with me."
        case .longestStreak:
            line = longestStreakInYear > 1
                ? "I stood on God's Word \(count(longestStreakInYear)) days in a row \(periodPhrase). Come stand with me."
                : "I stood on God's Word \(periodPhrase), one day at a time. Come stand with me."
        case .bestMonth:
            if let best = bestMonth {
                line = "\(best.name) was my strongest month in God's Word \(periodPhrase). Come speak life with me."
            } else {
                line = summaryLine(days: days, count: count)
            }
        case .totals:
            line = "I spoke \(declarationsPhrase(count: count)) in my SpeakLife Daily Burst \(periodPhrase). Start your year with me."
        case .strength:
            line = "I grew to \(peakStrengthLevel.rawValue) strength in God's Word \(periodPhrase). Come grow with me."
        case .nextYear:
            line = "\(nextYearDeclaration) Speak it with me."
        case .cover, .summary:
            line = summaryLine(days: days, count: count)
        }
        return line
    }

    private func declarationsPhrase(count: (Int) -> String) -> String {
        totalDeclarationsSpoken == 1 ? "1 declaration" : "\(count(totalDeclarationsSpoken)) declarations"
    }

    private func summaryLine(days: String, count: (Int) -> String) -> String {
        let opener = isInProgress ? "My \(year) so far in SpeakLife" : "My \(year) in SpeakLife"
        guard totalDeclarationsSpoken > 0 else {
            return "\(opener): \(days) in God's Word. Start your year with me."
        }
        return "\(opener): \(days) in God's Word and \(declarationsPhrase(count: count)) spoken in my Daily Burst. Start your year with me."
    }
}

// MARK: - Eligibility

/// Where the recap was opened from. The raw value is the `source` property
/// on `year_in_review_opened`.
enum YearInReviewSource: String, CaseIterable {
    case auto
    case todayCard = "today_card"
    case profile
    case push
}

/// Who sees the recap, when, and how. Pure, so the rules are unit tested.
enum YearInReviewEligibility {

    /// The launch takeover is for people with a real year to look at. One or
    /// two days makes a thin recap that interrupts more than it delights.
    static let autoLaunchMinimumDays = 3

    /// The Today card and Profile row are opt-in, so one day is enough.
    static let entryPointMinimumDays = 1

    /// Push payload: `deepLink` = `yearInReview` opens the recap.
    static let pushDeepLinkKey = "deepLink"
    static let pushDeepLinkValue = "yearInReview"

    /// Whether the Today card and Profile row show.
    static func showsEntryPoint(recapYear: Int?, daysActive: Int) -> Bool {
        recapYear != nil && daysActive >= entryPointMinimumDays
    }

    /// Whether a given source may open the recap at all.
    static func canOpen(source: YearInReviewSource, recapYear: Int?, daysActive: Int) -> Bool {
        guard recapYear != nil else { return false }
        switch source {
        case .auto:
            return daysActive >= autoLaunchMinimumDays
        case .todayCard, .profile, .push:
            return daysActive >= entryPointMinimumDays
        }
    }

    /// Whether the recap takes over the screen on its own this launch. Never
    /// over another launch presentation, and never twice for the same year
    /// once it has actually been seen (from any source).
    static func shouldAutoLaunch(recapYear: Int?, daysActive: Int,
                                 alreadySeen: Bool, anotherPresentationActive: Bool) -> Bool {
        canOpen(source: .auto, recapYear: recapYear, daysActive: daysActive)
            && !alreadySeen
            && !anotherPresentationActive
    }

    /// True for a notification the founder sent to open the recap.
    static func isRecapPush(_ userInfo: [AnyHashable: Any]) -> Bool {
        (userInfo[pushDeepLinkKey] as? String) == pushDeepLinkValue
    }

    /// UserDefaults key recording that the recap for `year` was seen. Same key
    /// as earlier builds, so anyone who already saw it is not shown it again.
    static func seenKey(for year: Int) -> String {
        "yearInReview_shown_\(year)"
    }
}

#if DEBUG
extension YearInReviewStats {
    /// Sample data for previews.
    static func sample(daysActive: Int = 212,
                       totals: Int = 3_184,
                       bestMonth: (name: String, count: Int)? = (name: "September", count: 27),
                       asOf: Date = Date()) -> YearInReviewStats {
        YearInReviewStats(
            year: YearInReviewStats.gregorian.component(.year, from: asOf),
            daysActive: daysActive,
            longestStreakInYear: min(daysActive, 46),
            bestMonth: bestMonth,
            totalDeclarationsSpoken: totals,
            currentStreak: 12,
            peakStrengthLevel: .conqueror,
            peakStrengthScore: 64,
            asOf: asOf
        )
    }
}
#endif
