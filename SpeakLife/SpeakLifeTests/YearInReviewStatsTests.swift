//
//  YearInReviewStatsTests.swift
//  SpeakLifeTests
//
//  Guards the Year in Review rules that fail silently: the Dec 1 to Jan 15
//  window across the year boundary, the percent of an unfinished year, the
//  best-month tie, which slides show, who gets the launch takeover, and the
//  share words (no dashes, no full-year claim in December).
//

import XCTest
@testable import SpeakLife

final class YearInReviewStatsTests: XCTestCase {

    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
        return calendar
    }()

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour)) ?? Date()
    }

    private func stats(daysActive: Int = 212,
                       longest: Int = 46,
                       bestMonth: (name: String, count: Int)? = (name: "September", count: 27),
                       totals: Int = 3_184,
                       asOf: Date? = nil) -> YearInReviewStats {
        YearInReviewStats(
            year: 2026,
            daysActive: daysActive,
            longestStreakInYear: longest,
            bestMonth: bestMonth,
            totalDeclarationsSpoken: totals,
            currentStreak: 0,
            peakStrengthLevel: .champion,
            peakStrengthScore: 31,
            asOf: asOf ?? date(2027, 1, 5)
        )
    }

    // MARK: - Window

    func testWindowIsShutTheDayBeforeDecemberFirst() {
        XCTAssertNil(YearInReviewStats.recapYear(for: date(2026, 11, 30), calendar: calendar))
    }

    func testWindowOpensDecemberFirstForTheYearInProgress() {
        XCTAssertEqual(YearInReviewStats.recapYear(for: date(2026, 12, 1, hour: 0), calendar: calendar), 2026)
        XCTAssertEqual(YearInReviewStats.recapYear(for: date(2026, 12, 31, hour: 23), calendar: calendar), 2026)
    }

    func testJanuaryRecapsThePreviousYearThroughTheFifteenth() {
        XCTAssertEqual(YearInReviewStats.recapYear(for: date(2027, 1, 1, hour: 0), calendar: calendar), 2026)
        XCTAssertEqual(YearInReviewStats.recapYear(for: date(2027, 1, 15, hour: 23), calendar: calendar), 2026)
    }

    func testWindowIsShutFromJanuarySixteenth() {
        XCTAssertNil(YearInReviewStats.recapYear(for: date(2027, 1, 16, hour: 0), calendar: calendar))
        XCTAssertNil(YearInReviewStats.recapYear(for: date(2026, 6, 15), calendar: calendar))
    }

    func testRulesRunOnTheGregorianCalendarWhateverTheDevice() {
        // A Japanese or Buddhist device calendar would call 2026 something
        // else, and Hebrew or Islamic month 12 is not December.
        XCTAssertEqual(YearInReviewStats.gregorian.identifier, .gregorian)
        XCTAssertEqual(YearInReviewStats.gregorian.timeZone, TimeZone.current)
        XCTAssertEqual(stats().calendar.identifier, .gregorian)
    }

    // MARK: - Percent of year

    func testInProgressYearDividesByDaysElapsed() {
        // Jan 1 to Dec 1 inclusive is 335 days in 2026: 300 / 335 = 89.6%.
        let percent = YearInReviewStats.percentOfYear(daysActive: 300, year: 2026,
                                                      asOf: date(2026, 12, 1), calendar: calendar)
        XCTAssertEqual(percent, 90)
    }

    func testClosedYearDividesByTheWholeYear() {
        let percent = YearInReviewStats.percentOfYear(daysActive: 300, year: 2026,
                                                      asOf: date(2027, 1, 5), calendar: calendar)
        XCTAssertEqual(percent, 82)
    }

    func testPercentNeverRoundsUpToAFullYearItDidNotEarn() {
        let percent = YearInReviewStats.percentOfYear(daysActive: 364, year: 2026,
                                                      asOf: date(2027, 1, 5), calendar: calendar)
        XCTAssertEqual(percent, 99)
        XCTAssertEqual(YearInReviewStats.percentOfYear(daysActive: 365, year: 2026,
                                                       asOf: date(2027, 1, 5), calendar: calendar), 100)
    }

    func testZeroDaysIsZeroPercent() {
        XCTAssertEqual(YearInReviewStats.percentOfYear(daysActive: 0, year: 2026,
                                                       asOf: date(2026, 12, 1), calendar: calendar), 0)
    }

    func testInProgressFollowsTheAsOfYear() {
        XCTAssertTrue(YearInReviewStats.isInProgress(year: 2026, asOf: date(2026, 12, 1), calendar: calendar))
        XCTAssertFalse(YearInReviewStats.isInProgress(year: 2026, asOf: date(2027, 1, 2), calendar: calendar))
    }

    // MARK: - Best month

    func testBestMonthCountsDistinctDaysNotSessions() {
        let dates = [date(2026, 3, 1, hour: 8), date(2026, 3, 1, hour: 20), date(2026, 3, 2),
                     date(2026, 4, 1), date(2026, 4, 2), date(2026, 4, 3)]
        let best = YearInReviewStats.bestMonth(in: dates, calendar: calendar)
        XCTAssertEqual(best?.month, 4)
        XCTAssertEqual(best?.days, 3)
    }

    func testBestMonthTieGoesToTheLaterMonth() {
        let dates = [date(2026, 9, 1), date(2026, 9, 2), date(2026, 2, 1), date(2026, 2, 2),
                     date(2026, 6, 1), date(2026, 6, 2)]
        for _ in 0..<20 {
            XCTAssertEqual(YearInReviewStats.bestMonth(in: dates.shuffled(), calendar: calendar)?.month, 9)
        }
    }

    func testNoDatesMeansNoBestMonth() {
        XCTAssertNil(YearInReviewStats.bestMonth(in: [], calendar: calendar))
    }

    // MARK: - Slides

    func testFreeUsersDoNotGetTheStrengthSlide() {
        let slides = stats().slides(includesPremiumExtras: false)
        XCTAssertEqual(slides, [.cover, .days, .longestStreak, .bestMonth, .totals, .summary, .nextYear])
    }

    func testPremiumUsersGetStrengthBeforeTheSummary() {
        let slides = stats().slides(includesPremiumExtras: true)
        XCTAssertEqual(slides, [.cover, .days, .longestStreak, .bestMonth, .totals, .strength, .summary, .nextYear])
    }

    func testEmptyNumbersDropTheirSlides() {
        let slides = stats(daysActive: 1, longest: 1, bestMonth: nil, totals: 0)
            .slides(includesPremiumExtras: false)
        XCTAssertEqual(slides, [.cover, .days, .longestStreak, .summary, .nextYear])
    }

    // MARK: - Eligibility

    func testAutoLaunchNeedsThreeDays() {
        XCTAssertFalse(YearInReviewEligibility.shouldAutoLaunch(recapYear: 2026, daysActive: 2,
                                                                alreadySeen: false, anotherPresentationActive: false))
        XCTAssertTrue(YearInReviewEligibility.shouldAutoLaunch(recapYear: 2026, daysActive: 3,
                                                               alreadySeen: false, anotherPresentationActive: false))
    }

    func testAutoLaunchNeverRepeatsOrStacks() {
        XCTAssertFalse(YearInReviewEligibility.shouldAutoLaunch(recapYear: 2026, daysActive: 200,
                                                                alreadySeen: true, anotherPresentationActive: false))
        XCTAssertFalse(YearInReviewEligibility.shouldAutoLaunch(recapYear: 2026, daysActive: 200,
                                                                alreadySeen: false, anotherPresentationActive: true))
        XCTAssertFalse(YearInReviewEligibility.shouldAutoLaunch(recapYear: nil, daysActive: 200,
                                                                alreadySeen: false, anotherPresentationActive: false))
    }

    func testEntryPointsShowFromOneDayInsideTheWindow() {
        XCTAssertTrue(YearInReviewEligibility.showsEntryPoint(recapYear: 2026, daysActive: 1))
        XCTAssertFalse(YearInReviewEligibility.showsEntryPoint(recapYear: 2026, daysActive: 0))
        XCTAssertFalse(YearInReviewEligibility.showsEntryPoint(recapYear: nil, daysActive: 50))
    }

    func testManualSourcesOpenFromOneDayButAutoNeedsThree() {
        for source in [YearInReviewSource.todayCard, .profile, .push] {
            XCTAssertTrue(YearInReviewEligibility.canOpen(source: source, recapYear: 2026, daysActive: 1))
            XCTAssertFalse(YearInReviewEligibility.canOpen(source: source, recapYear: nil, daysActive: 100))
        }
        XCTAssertFalse(YearInReviewEligibility.canOpen(source: .auto, recapYear: 2026, daysActive: 2))
    }

    func testSourceAnalyticsValues() {
        XCTAssertEqual(YearInReviewSource.allCases.map(\.rawValue), ["auto", "today_card", "profile", "push"])
    }

    func testRecapPushIsRecognisedByItsDeepLink() {
        XCTAssertTrue(YearInReviewEligibility.isRecapPush(["deepLink": "yearInReview"]))
        XCTAssertFalse(YearInReviewEligibility.isRecapPush(["deepLink": "message"]))
        XCTAssertFalse(YearInReviewEligibility.isRecapPush([:]))
    }

    func testSeenKeyMatchesEarlierBuilds() {
        XCTAssertEqual(YearInReviewEligibility.seenKey(for: 2026), "yearInReview_shown_2026")
    }

    // MARK: - Share words

    private let enUS = Locale(identifier: "en_US")

    func testShareWordsHaveNoDashesOrLinks() {
        let recap = stats()
        for slide in YearInReviewSlide.allCases {
            let words = recap.shareWords(for: slide, locale: enUS)
            XCTAssertFalse(words.contains("\u{2014}"), "\(slide) has an em dash")
            XCTAssertFalse(words.contains("\u{2013}"), "\(slide) has an en dash")
            XCTAssertFalse(words.contains("http"), "\(slide) carries a link; ReferralShareText adds it")
        }
    }

    func testBigNumbersAreGrouped() {
        XCTAssertEqual(YearInReviewStats.formattedCount(1_234_567, locale: enUS), "1,234,567")
        XCTAssertTrue(stats().shareWords(for: .totals, locale: enUS).contains("3,184 declarations"))
    }

    func testOneDayReadsSingular() {
        let words = stats(daysActive: 1, longest: 1, totals: 1).shareWords(for: .days, locale: enUS)
        XCTAssertTrue(words.contains("on 1 day "))
        let totals = stats(daysActive: 1, longest: 1, totals: 1).shareWords(for: .totals, locale: enUS)
        XCTAssertTrue(totals.contains("1 declaration "))
    }

    func testDeclarationTotalIsLabelledAsDailyBurst() {
        XCTAssertTrue(stats().shareWords(for: .totals, locale: enUS).contains("Daily Burst"))
        XCTAssertTrue(stats().shareWords(for: .summary, locale: enUS).contains("Daily Burst"))
    }

    func testDecemberWordsDoNotClaimTheWholeYear() {
        // Built "today" for this year, so the year is in progress whatever
        // the test machine's time zone.
        let words = YearInReviewStats(
            year: YearInReviewStats.gregorian.component(.year, from: Date()),
            daysActive: 20, longestStreakInYear: 5, bestMonth: nil, totalDeclarationsSpoken: 40,
            currentStreak: 0, peakStrengthLevel: .warrior, peakStrengthScore: 5, asOf: Date()
        ).shareWords(for: .days, locale: enUS)
        XCTAssertTrue(words.contains("so far in"))
    }

    func testClosedYearWordsNameTheYear() {
        let words = stats(asOf: date(2027, 1, 5)).shareWords(for: .days, locale: enUS)
        XCTAssertTrue(words.contains("in 2026"))
        XCTAssertFalse(words.contains("so far"))
    }

    func testNextYearDeclarationIsOneFirstPersonSentence() {
        let line = stats().nextYearDeclaration
        XCTAssertEqual(line, "I step into 2027 rooted, unshakeable and full of His Word.")
        XCTAssertTrue(line.hasPrefix("I "))
        XCTAssertEqual(line.filter { $0 == "." }.count, 1)
    }
}
