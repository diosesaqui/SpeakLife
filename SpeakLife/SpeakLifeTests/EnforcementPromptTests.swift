//
//  EnforcementPromptTests.swift
//  SpeakLifeTests
//
//  The weekly prompt has to stay quiet in three situations, and each one is a
//  real complaint if it leaks:
//
//  - Mid-campaign. Slot 0 already carries that day's anchor; a prompt there
//    would both collide and nag someone already doing the thing.
//  - Not yet eligible. Prompting someone who can't act on it is a dead end.
//  - Any day that isn't the prompt weekday. Otherwise it's daily, not weekly.
//

import XCTest
@testable import SpeakLife

final class EnforcementPromptTests: XCTestCase {

    private var defaults: UserDefaults!
    private var suiteName: String!
    private var calendar: Calendar!

    override func setUp() {
        super.setUp()
        suiteName = "EnforcementPromptTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        calendar = Calendar(identifier: .gregorian)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil; suiteName = nil; calendar = nil
        super.tearDown()
    }

    // MARK: - Helpers

    private func makeService(catalog: [Enforcement] = []) -> EnforcementService {
        EnforcementService(defaults: defaults, calendar: calendar, catalog: catalog)
    }

    private func seedTenure(_ days: Int) {
        var stats = StreakStats()
        stats.totalDaysCompleted = days
        if let data = try? JSONEncoder().encode(stats) {
            defaults.set(data, forKey: "streakStats")
        }
    }

    /// The next date matching the prompt weekday, so tests don't depend on when
    /// they happen to run.
    private func nextPromptDay() -> Date {
        var date = Date()
        for _ in 0..<8 {
            if calendar.component(.weekday, from: date) == EnforcementPrompt.promptWeekday {
                return date
            }
            date = calendar.date(byAdding: .day, value: 1, to: date)!
        }
        return date
    }

    private func nonPromptDay() -> Date {
        calendar.date(byAdding: .day, value: 1, to: nextPromptDay())!
    }

    // MARK: - Gating

    func testPrompt_SilentWhenNotEligible() {
        seedTenure(3)
        let copy = EnforcementPrompt.copy(forDayOffset: 0, now: nextPromptDay(),
                                          calendar: calendar, service: makeService(),
                                          defaults: defaults)
        XCTAssertNil(copy, "prompting someone who can't start a campaign is a dead end")
    }

    func testPrompt_SilentOnANonPromptWeekday() {
        seedTenure(30)
        let copy = EnforcementPrompt.copy(forDayOffset: 0, now: nonPromptDay(),
                                          calendar: calendar, service: makeService(),
                                          defaults: defaults)
        XCTAssertNil(copy, "the prompt is weekly, not daily")
    }

    func testPrompt_SilentWhileACampaignIsRunning() {
        seedTenure(30)
        let fight = Enforcement(id: "peace", title: "Enforcing Peace", tagline: "t",
                                theme: "anxiety",
                                days: (1...Enforcement.length).map {
                                    EnforcementDay(dayNumber: $0, anchorText: "a\($0)",
                                                   anchorVerse: "v", anchorBook: "b",
                                                   anchorTranslation: "ESV",
                                                   audioId: "a.mp3", audioTitle: "A", audioMinutes: 3)
                                })
        let service = makeService(catalog: [fight])
        service.startEnforcement(id: "peace", isPremium: true)

        let copy = EnforcementPrompt.copy(forDayOffset: 0, now: nextPromptDay(),
                                          calendar: calendar, service: service,
                                          defaults: defaults)
        XCTAssertNil(copy, "slot 0 already carries the day's anchor mid-campaign")
    }

    // MARK: - Copy

    func testPrompt_RotatesAcrossWeeks() {
        seedTenure(30)
        let service = makeService()
        var seen = Set<String>()
        var date = nextPromptDay()
        for _ in 0..<EnforcementPrompt.rotation.count {
            if let copy = EnforcementPrompt.copy(forDayOffset: 0, now: date,
                                                 calendar: calendar, service: service,
                                                 defaults: defaults) {
                seen.insert(copy.title)
            }
            date = calendar.date(byAdding: .day, value: 7, to: date)!
        }
        XCTAssertGreaterThan(seen.count, 1,
                             "someone who ignores it shouldn't see identical copy every week")
    }

    func testPrompt_CopyIsWellFormed() {
        for copy in EnforcementPrompt.rotation {
            XCTAssertFalse(copy.title.isEmpty)
            XCTAssertFalse(copy.body.isEmpty)
            // iOS truncates long bodies in the banner; keep them readable.
            XCTAssertLessThanOrEqual(copy.body.count, 180, "body too long: \(copy.body)")
            XCTAssertLessThanOrEqual(copy.title.count, 48, "title too long: \(copy.title)")
            // Every push carries exactly one anchor scripture.
            XCTAssertTrue(copy.body.contains("("), "no scripture reference in: \(copy.body)")
        }
    }
}
