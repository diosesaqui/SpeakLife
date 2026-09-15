//
//  StandDayStampTests.swift
//  SpeakLifeCoreTests
//
//  The day stamp is display-only, but it is display-only across time zones and
//  DST boundaries, which is where naive date code goes wrong. These pin the
//  cases that a divide-by-86,400 implementation gets silently wrong.
//

import XCTest
@testable import SpeakLifeCore

final class StandDayStampTests: XCTestCase {

    private func calendar(_ tz: String) -> Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: tz)!
        c.locale = Locale(identifier: "en_US_POSIX")
        return c
    }

    private func date(_ iso: String) -> Date {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f.date(from: iso)!
    }

    // MARK: - Shape

    func testStampIsZeroPadded() {
        let jan = date("2026-01-05T12:00:00Z")
        XCTAssertEqual(StandDayStamp.stamp(for: jan, calendar: calendar("UTC")), "2026-01-05")
    }

    func testWellFormedAcceptsOnlyRealStamps() {
        XCTAssertTrue(StandDayStamp.isWellFormed("2026-09-15"))
        XCTAssertFalse(StandDayStamp.isWellFormed("2026-9-15"))
        XCTAssertFalse(StandDayStamp.isWellFormed("2026-09-1"))
        XCTAssertFalse(StandDayStamp.isWellFormed(""))
        XCTAssertFalse(StandDayStamp.isWellFormed("not-a-date"))
        XCTAssertFalse(StandDayStamp.isWellFormed("20260915xx"))
    }

    // MARK: - The date line

    func testTheDateLineNeverMakesAnyoneLate() {
        // 03:00 UTC: already the 15th in Auckland, still the 14th in Los Angeles.
        // Each member reads their own calendar, so both are correct and neither
        // is behind.
        let t = date("2026-09-15T03:00:00Z")
        XCTAssertEqual(StandDayStamp.stamp(for: t, calendar: calendar("Pacific/Auckland")), "2026-09-15")
        XCTAssertEqual(StandDayStamp.stamp(for: t, calendar: calendar("America/Los_Angeles")), "2026-09-14")
        XCTAssertEqual(StandDayStamp.stamp(for: t, calendar: calendar("UTC")), "2026-09-15")
    }

    func testHalfHourOffsetZone() {
        let t = date("2026-09-14T19:00:00Z")   // 00:30 on the 15th in Kolkata
        XCTAssertEqual(StandDayStamp.stamp(for: t, calendar: calendar("Asia/Kolkata")), "2026-09-15")
    }

    // MARK: - Day boundaries

    func testLastSecondOfTheDayIsStillThatDay() {
        let cal = calendar("America/New_York")
        let end = cal.date(from: DateComponents(year: 2026, month: 9, day: 15,
                                                hour: 23, minute: 59, second: 59))!
        XCTAssertEqual(StandDayStamp.stamp(for: end, calendar: cal), "2026-09-15")

        let next = end.addingTimeInterval(1)
        XCTAssertEqual(StandDayStamp.stamp(for: next, calendar: cal), "2026-09-16")
    }

    // MARK: - DST

    func testSpringForwardDoesNotSkipADay() {
        // US DST begins 2026-03-08. That local day is 23 hours long, so an
        // implementation that walks back in 86,400-second steps lands on the
        // wrong stamp here.
        let cal = calendar("America/New_York")
        let after = cal.date(from: DateComponents(year: 2026, month: 3, day: 8, hour: 12))!
        let week = StandDayStamp.lastDays(3, endingOn: after, calendar: cal)
        XCTAssertEqual(week, ["2026-03-06", "2026-03-07", "2026-03-08"])
    }

    func testFallBackDoesNotRepeatADay() {
        // US DST ends 2026-11-01 — a 25-hour local day.
        let cal = calendar("America/New_York")
        let after = cal.date(from: DateComponents(year: 2026, month: 11, day: 2, hour: 12))!
        let week = StandDayStamp.lastDays(3, endingOn: after, calendar: cal)
        XCTAssertEqual(week, ["2026-10-31", "2026-11-01", "2026-11-02"])
    }

    // MARK: - Week strip

    func testLastDaysIsOldestFirstAndEndsToday() {
        let cal = calendar("UTC")
        let today = date("2026-09-15T12:00:00Z")
        let week = StandDayStamp.lastDays(7, endingOn: today, calendar: cal)
        XCTAssertEqual(week.count, 7)
        XCTAssertEqual(week.first, "2026-09-09")
        XCTAssertEqual(week.last, "2026-09-15")
        XCTAssertEqual(week, week.sorted(), "the strip reads left to right, oldest first")
    }

    func testLastDaysCrossesAMonthBoundary() {
        let cal = calendar("UTC")
        let today = date("2026-03-02T12:00:00Z")
        XCTAssertEqual(StandDayStamp.lastDays(4, endingOn: today, calendar: cal),
                       ["2026-02-27", "2026-02-28", "2026-03-01", "2026-03-02"])
    }

    func testLastDaysHandlesALeapDay() {
        let cal = calendar("UTC")
        let today = date("2028-03-01T12:00:00Z")
        XCTAssertEqual(StandDayStamp.lastDays(3, endingOn: today, calendar: cal),
                       ["2028-02-28", "2028-02-29", "2028-03-01"])
    }

    func testLastDaysOfZeroIsEmpty() {
        XCTAssertTrue(StandDayStamp.lastDays(0).isEmpty)
        XCTAssertTrue(StandDayStamp.lastDays(-1).isEmpty)
    }

    // MARK: - isToday

    func testIsToday() {
        let cal = calendar("UTC")
        let now = date("2026-09-15T12:00:00Z")
        XCTAssertTrue(StandDayStamp.isToday("2026-09-15", on: now, calendar: cal))
        XCTAssertFalse(StandDayStamp.isToday("2026-09-14", on: now, calendar: cal))
        XCTAssertFalse(StandDayStamp.isToday("", on: now, calendar: cal))
    }
}
