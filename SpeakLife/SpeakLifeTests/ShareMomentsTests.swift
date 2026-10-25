//
//  ShareMomentsTests.swift
//  SpeakLifeTests
//
//  Guards the two share moments: the feed's once-a-day nudge, and the burst
//  sent as an ordered set of story cards.
//

import XCTest
@testable import SpeakLife

final class ShareMomentsTests: XCTestCase {

    private var defaults: UserDefaults!
    private var suiteName: String!
    private var calendar: Calendar!

    override func setUp() {
        super.setUp()
        suiteName = "ShareMomentsTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    private func date(_ day: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour))!
    }

    private var policy: FeedShareNudgePolicy {
        FeedShareNudgePolicy(defaults: defaults, calendar: calendar)
    }

    // MARK: - Feed nudge

    func testNudgeShowsOnFifthDeclarationOnly() {
        let installed = date(1)
        let today = date(10)
        let answers = (1...8).map { _ in policy.recordDeclarationReached(now: today, installDate: installed) }
        XCTAssertEqual(answers, [false, false, false, false, true, false, false, false])
    }

    func testNudgeNeverShowsOnInstallDay() {
        let installed = date(10, hour: 8)
        let answers = (1...10).map { _ in policy.recordDeclarationReached(now: date(10, hour: 20), installDate: installed) }
        XCTAssertFalse(answers.contains(true))
    }

    func testCountResetsAndNudgeReturnsNextDay() {
        let installed = date(1)
        for _ in 1...5 { _ = policy.recordDeclarationReached(now: date(10), installDate: installed) }

        let nextDay = (1...5).map { _ in policy.recordDeclarationReached(now: date(11), installDate: installed) }
        XCTAssertEqual(nextDay, [false, false, false, false, true])
    }

    func testDayAfterInstallCanShow() {
        let installed = date(10, hour: 23)
        let answers = (1...5).map { _ in policy.recordDeclarationReached(now: date(11, hour: 1), installDate: installed) }
        XCTAssertEqual(answers.last, true)
    }

    // MARK: - Burst cards

    func testBurstLineBecomesDeclaration() {
        let line = BurstDeclaration(text: "I have the mind of Christ", verse: "1 Corinthians 2:16",
                                    scripture: "But we have the mind of Christ.", category: .wisdom)
        let declaration = BurstShareContent.declaration(from: line)
        XCTAssertEqual(declaration.text, "I have the mind of Christ")
        XCTAssertEqual(declaration.book, "1 Corinthians 2:16")
        XCTAssertEqual(declaration.bibleVerseText, "But we have the mind of Christ.")
        XCTAssertEqual(declaration.category, .wisdom)
    }

    func testOwnLineHasNoReferenceAndKeepsOrder() {
        let lines = [
            BurstDeclaration(text: "First", verse: "", scripture: nil, category: nil),
            BurstDeclaration(text: "   ", verse: "Psalm 1:3", scripture: nil, category: .faith),
            BurstDeclaration(text: "Third", verse: "Psalm 1:3", scripture: nil, category: .joy)
        ]
        let declarations = BurstShareContent.declarations(from: lines)
        XCTAssertEqual(declarations.map(\.text), ["First", "Third"])
        XCTAssertNil(declarations[0].book)
        XCTAssertNil(declarations[0].bibleVerseText)
        XCTAssertEqual(declarations[0].category, .faith)
    }

    func testMessageMatchesCardCount() {
        XCTAssertTrue(BurstShareContent.message(cardCount: 7).contains("7 promises"))
        XCTAssertTrue(BurstShareContent.message(cardCount: 1).contains("a promise"))
        XCTAssertFalse(BurstShareContent.message(cardCount: 0).contains("0"))
        for count in 0...7 {
            let message = BurstShareContent.message(cardCount: count)
            XCTAssertFalse(message.contains("\u{2014}") || message.contains("\u{2013}"))
        }
    }

    // MARK: - Card eyebrow

    func testEyebrowMarksPositionOnlyInASet() {
        XCTAssertEqual(DeclarationStoryCard.eyebrow(isJesusVoice: false, position: nil), "I DECLARE")
        XCTAssertEqual(DeclarationStoryCard.eyebrow(isJesusVoice: false, position: .init(number: 1, total: 7)),
                       "I DECLARE · 1 OF 7")
        XCTAssertEqual(DeclarationStoryCard.eyebrow(isJesusVoice: true, position: .init(number: 3, total: 7)),
                       "JESUS SAYS · 3 OF 7")
        XCTAssertEqual(DeclarationStoryCard.eyebrow(isJesusVoice: true, position: .init(number: 1, total: 1)),
                       "JESUS SAYS")
    }
}
