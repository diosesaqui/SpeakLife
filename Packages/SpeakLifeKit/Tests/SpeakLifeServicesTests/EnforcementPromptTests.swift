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
import SpeakLifeCore
@testable import SpeakLifeServices

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
        // Matches production: `RemoteConfig.setDefaults([enforcementEnabled: true])`
        // runs in AppDelegate at app-hosted test bundle load, so the old
        // suite implicitly saw the flag on. Under `swift test` there is no
        // AppDelegate and no Remote Config, so this must be pinned here or
        // `EnforcementPrompt.copy` returns nil straight past the eligibility
        // check.
        EnforcementService(defaults: defaults, calendar: calendar, catalog: catalog,
                           featureFlags: StaticFeatureFlags(["enforcementEnabled": true]))
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
    private func nextPromptDay(after start: Date = Date()) -> Date {
        var date = start
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
                                theme: .anxiety,
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
            // A lock-screen banner shows roughly two lines. Past this the tail
            // truncates, and the tail is where the offer lives — which is what
            // went wrong with the previous copy at 140 to 190 characters.
            XCTAssertLessThanOrEqual(copy.body.count, 90, "body too long: \(copy.body)")
            XCTAssertLessThanOrEqual(copy.title.count, 30, "title too long: \(copy.title)")
        }
    }

    /// This notification has exactly one job: make the exchange obvious. Ask for
    /// one thing, promise seven days built on it. A variant missing either half
    /// is a banner someone reads and has no reason to answer.
    func testPrompt_EveryVariantStatesTheExchange() {
        for copy in EnforcementPrompt.rotation {
            let full = (copy.title + " " + copy.body).lowercased()

            let asks = ["name", "tell us", "what are you"].contains { full.contains($0) }
            XCTAssertTrue(asks, "no ask in: \(copy.title) / \(copy.body)")

            let promises = full.contains("we'll build")
            XCTAssertTrue(promises, "no offer in: \(copy.title) / \(copy.body)")

            let namesTheWeek = ["seven days", "the week"].contains { full.contains($0) }
            XCTAssertTrue(namesTheWeek, "doesn't say what they get in: \(copy.body)")
        }
    }

    /// The old copy said "what you're walking through", which only invites a
    /// storm. Someone opening the app in a good week reads that as not for them,
    /// and the card itself was widened to admit a goal.
    func testPrompt_NoVariantAssumesAStorm() {
        let stormOnly = ["walking through", "going through", "struggling", "hard time", "suffering"]
        for copy in EnforcementPrompt.rotation {
            let full = (copy.title + " " + copy.body).lowercased()
            for phrase in stormOnly {
                XCTAssertFalse(full.contains(phrase),
                               "\"\(phrase)\" assumes a storm: \(copy.body)")
            }
        }
    }

    /// Every variant leads with the alert emoji so the banner is recognisable at
    /// a glance as the weekly campaign prompt rather than a devotional push.
    func testPrompt_EveryVariantIsFlaggedAsAnAlert() {
        for copy in EnforcementPrompt.rotation {
            XCTAssertTrue(copy.title.hasPrefix("🚨 "), "no alert flag on: \(copy.title)")
            XCTAssertFalse(copy.body.contains("🚨"), "emoji belongs in the title only: \(copy.body)")
        }
    }

    /// The first prompt a user ever sees must be one of the explanatory ones.
    ///
    /// This used to index on `weekOfYear`, so the entry point was whatever the
    /// calendar happened to land on and someone becoming eligible in week 33
    /// opened on rotation[3]. Harmless when every variant read alike, wrong now
    /// that the first three exist to explain "seven days" to someone who has
    /// never run a campaign.
    func testPrompt_FirstEverPromptStartsAtTheExplanatoryEnd() {
        seedTenure(30)
        let service = makeService()

        // A date deliberately deep in the year, where the old modulo landed mid-array.
        var date = nextPromptDay(after: calendar.date(from: DateComponents(year: 2026, month: 8, day: 1))!)
        let first = EnforcementPrompt.copy(forDayOffset: 0, now: date, calendar: calendar,
                                           service: service, defaults: defaults)
        XCTAssertEqual(first?.title, EnforcementPrompt.rotation[0].title)

        // And it advances one step per week from there, not per calendar week.
        for expected in 1..<EnforcementPrompt.rotation.count {
            date = calendar.date(byAdding: .day, value: 7, to: date)!
            let copy = EnforcementPrompt.copy(forDayOffset: 0, now: date, calendar: calendar,
                                              service: service, defaults: defaults)
            XCTAssertEqual(copy?.title, EnforcementPrompt.rotation[expected].title,
                           "week \(expected) landed on the wrong variant")
        }
    }

    /// The batch is rebuilt many times a day, and every rebuild re-reads every
    /// day offset. An anchor date survives that; a counter would race ahead by
    /// dozens per rebuild and shuffle the copy under the user.
    func testPrompt_RepeatedReadsDoNotAdvanceTheRotation() {
        seedTenure(30)
        let service = makeService()
        let sunday = nextPromptDay()

        let first = EnforcementPrompt.copy(forDayOffset: 0, now: sunday, calendar: calendar,
                                           service: service, defaults: defaults)
        for _ in 0..<25 {
            let again = EnforcementPrompt.copy(forDayOffset: 0, now: sunday, calendar: calendar,
                                               service: service, defaults: defaults)
            XCTAssertEqual(again?.title, first?.title, "copy changed on a re-read of the same week")
        }
    }

    /// Weekly send. Fewer than four and the loop is noticeable within a month.
    func testPrompt_RotationIsDeepEnoughForAWeeklySend() {
        XCTAssertGreaterThanOrEqual(EnforcementPrompt.rotation.count, 4)
        let titles = EnforcementPrompt.rotation.map(\.title)
        XCTAssertEqual(Set(titles).count, titles.count, "duplicate title in the rotation")
        let bodies = EnforcementPrompt.rotation.map(\.body)
        XCTAssertEqual(Set(bodies).count, bodies.count, "duplicate body in the rotation")
    }
}
