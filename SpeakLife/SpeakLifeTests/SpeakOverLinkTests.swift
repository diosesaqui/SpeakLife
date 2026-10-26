//
//  SpeakOverLinkTests.swift
//  SpeakLifeTests
//
//  "Speak it over someone" puts a stranger's text in a URL and shows it on
//  screen. These pin what a gift may contain, that the link survives the trip,
//  and that it can never be read as a Stand invite.
//

import XCTest
@testable import SpeakLife

final class SpeakOverLinkTests: XCTestCase {

    private let text = "By His wounds I am healed, and strength rises in this body every morning."

    // MARK: - Round trip

    func testBuildThenParseRoundTrips() throws {
        let url = SpeakOverLink.url(text: text, book: "Isaiah 53:5", from: "Maria", to: "Ana",
                                    campaign: "health")
        let gift = try XCTUnwrap(SpeakOverLink.parse(url))
        XCTAssertEqual(gift, SpeakOverGift(text: text, book: "Isaiah 53:5", from: "Maria", to: "Ana"))
    }

    func testLinkIsATrackedSpeakOverReferral() throws {
        let url = SpeakOverLink.url(text: text, book: nil, from: nil, to: nil, campaign: "health")
        XCTAssertEqual(url.host, ReferralLink.host)
        XCTAssertEqual(url.path, "/")
        let items = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
        XCTAssertEqual(items.first { $0.name == "feature" }?.value, "speak_over")
        XCTAssertEqual(items.first { $0.name == "campaign" }?.value, "health")
    }

    func testPunctuationSurvivesTheTrip() throws {
        let tricky = "I'm free & whole; \"no weapon\" formed = nothing? 100% His/mine #rooted + sealed"
        let url = SpeakOverLink.url(text: tricky, book: "Jesus", from: "José", to: nil, campaign: nil)
        let gift = try XCTUnwrap(SpeakOverLink.parse(url))
        XCTAssertEqual(gift.text, tricky)
        XCTAssertEqual(gift.from, "José")
        XCTAssertTrue(gift.isJesusVoice)
    }

    func testOptionalFieldsAreOmittedWhenEmpty() throws {
        let url = SpeakOverLink.url(text: text, book: "  ", from: "", to: nil, campaign: nil)
        let gift = try XCTUnwrap(SpeakOverLink.parse(url))
        XCTAssertNil(gift.book)
        XCTAssertNil(gift.from)
        XCTAssertNil(gift.to)
    }

    func testCustomSchemeParsesTheSameWay() throws {
        let url = try XCTUnwrap(URL(string: "speaklife://open?so_t=I%20am%20whole&so_from=Ana"))
        XCTAssertEqual(SpeakOverLink.parse(url), SpeakOverGift(text: "I am whole", book: nil, from: "Ana", to: nil))
    }

    // MARK: - Caps

    func testBuildCapsTextAndNames() throws {
        let long = String(repeating: "a", count: 400)
        let name = String(repeating: "n", count: 50)
        let book = String(repeating: "b", count: 60)
        let url = SpeakOverLink.url(text: long, book: book, from: name, to: name, campaign: nil)
        let gift = try XCTUnwrap(SpeakOverLink.parse(url))
        XCTAssertEqual(gift.text.count, SpeakOverLink.maxTextLength)
        XCTAssertEqual(gift.from?.count, SpeakOverLink.maxNameLength)
        XCTAssertEqual(gift.to?.count, SpeakOverLink.maxNameLength)
        XCTAssertEqual(gift.book?.count, SpeakOverLink.maxBookLength)
    }

    func testParseRejectsOversizedText() throws {
        var components = URLComponents(string: "https://speaklife.app.link/")!
        components.queryItems = [URLQueryItem(name: "so_t", value: String(repeating: "a", count: 281))]
        XCTAssertNil(SpeakOverLink.parse(try XCTUnwrap(components.url)))

        components.queryItems = [URLQueryItem(name: "so_t", value: String(repeating: "a", count: 280))]
        XCTAssertNotNil(SpeakOverLink.parse(try XCTUnwrap(components.url)))
    }

    // MARK: - Cleaning

    func testControlAndFormatCharactersAreStripped() {
        XCTAssertEqual(SpeakOverLink.clean("I am\u{0007} healed\n\tand  whole ", limit: nil),
                       "I am healed and whole")
        // Right-to-left override and zero-width space vanish without a gap.
        XCTAssertEqual(SpeakOverLink.clean("\u{202E}Ma\u{200B}ria", limit: nil), "Maria")
    }

    func testParseCleansIncomingValues() throws {
        var components = URLComponents(string: "https://speaklife.app.link/")!
        components.queryItems = [
            URLQueryItem(name: "so_t", value: "\n  I am\r\nfree  "),
            URLQueryItem(name: "so_from", value: "\u{202E}Ana\u{0000}")
        ]
        let gift = try XCTUnwrap(SpeakOverLink.parse(try XCTUnwrap(components.url)))
        XCTAssertEqual(gift.text, "I am free")
        XCTAssertEqual(gift.from, "Ana")
    }

    // MARK: - Rejection

    func testEmptyOrMissingTextIsRejected() throws {
        XCTAssertNil(SpeakOverLink.parse(try XCTUnwrap(URL(string: "https://speaklife.app.link/?so_t="))))
        XCTAssertNil(SpeakOverLink.parse(try XCTUnwrap(URL(string: "https://speaklife.app.link/?so_t=%20%0A%09"))))
        XCTAssertNil(SpeakOverLink.parse(try XCTUnwrap(URL(string: "https://speaklife.app.link/?so_from=Ana"))))
    }

    func testOrdinaryReferralLinkIsNotAGift() {
        XCTAssertNil(SpeakOverLink.parse(ReferralLink.url(.declarationCard, campaign: "faith")))
    }

    func testEmptyTextBuildsAPlainReferral() throws {
        let url = SpeakOverLink.url(text: " \n ", book: "Psalm 1:3", from: "Ana", to: nil, campaign: nil)
        XCTAssertNil(SpeakOverLink.parse(url))
        let names = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.map(\.name) ?? []
        XCTAssertFalse(names.contains("so_b"))
        XCTAssertFalse(names.contains("so_from"))
    }

    // MARK: - Branch params

    func testParsesBranchLinkData() {
        let params: [String: Any] = [
            "+clicked_branch_link": true,
            "+is_first_session": true,
            "~feature": "speak_over",
            "so_t": text,
            "so_b": "Isaiah 53:5",
            "so_from": "Maria"
        ]
        XCTAssertEqual(SpeakOverLink.parse(branchParams: params),
                       SpeakOverGift(text: text, book: "Isaiah 53:5", from: "Maria", to: nil))
    }

    func testBranchFallsBackToReferringLink() {
        let link = SpeakOverLink.url(text: text, book: nil, from: "Ana", to: nil, campaign: nil)
        let params: [String: Any] = ["~referring_link": link.absoluteString]
        XCTAssertEqual(SpeakOverLink.parse(branchParams: params)?.text, text)
    }

    func testBranchIgnoresNonGiftSessions() {
        XCTAssertNil(SpeakOverLink.parse(branchParams: ["+clicked_branch_link": false]))
        XCTAssertNil(SpeakOverLink.parse(branchParams: ["so_t": 42]))
        XCTAssertNil(SpeakOverLink.parse(branchParams: ["so_t": "   "]))
    }

    // MARK: - Not a Stand invite

    func testGiftLinkIsNeverReadAsAStandInvite() {
        // Even a line that contains the word and something shaped like a code.
        let url = SpeakOverLink.url(text: "I stand ABCD2345 on His word", book: "stand",
                                    from: "Stand", to: nil, campaign: "stand")
        XCTAssertNil(StandLink.code(from: url))
    }

    func testStandLinkIsNotAGift() throws {
        let stand = try XCTUnwrap(URL(string: "https://speaklife.app.link/stand/ABCD2345"))
        XCTAssertNil(SpeakOverLink.parse(stand))
    }

    // MARK: - Copy

    func testHeadlineNamesTheSenderOrSaysSomeone() {
        XCTAssertEqual(SpeakOverCopy.headline(from: "Maria"), "Maria is standing with you")
        XCTAssertEqual(SpeakOverCopy.headline(from: nil), "Someone is standing with you")
        XCTAssertEqual(SpeakOverCopy.headline(from: ""), "Someone is standing with you")
    }

    func testCopyHasNoDashes() {
        let lines = [SpeakOverCopy.sendTitle, SpeakOverCopy.subline(to: nil), SpeakOverCopy.subline(to: "Ana"),
                     SpeakOverCopy.shareText(to: "Ana"), SpeakOverCopy.shareText(to: nil)]
        for line in lines {
            XCTAssertFalse(line.contains("\u{2014}") || line.contains("\u{2013}"), line)
        }
        XCTAssertTrue(SpeakOverCopy.shareText(to: "Ana").hasPrefix("Ana, "))
    }

    // MARK: - Inbox

    private func makeDefaults() -> UserDefaults {
        let name = "SpeakOverLinkTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    func testInboxIgnoresTheDuplicateCallback() {
        let defaults = makeDefaults()
        let gift = SpeakOverGift(text: text, book: nil, from: "Ana", to: nil)
        XCTAssertTrue(SpeakOverInbox.deliver(gift, source: .link, defaults: defaults))
        XCTAssertFalse(SpeakOverInbox.deliver(gift, source: .deferred, defaults: defaults))
        XCTAssertEqual(SpeakOverInbox.pending(defaults: defaults)?.source, .link)
    }

    func testInboxClearsOnceShownAndSwallowsAnImmediateRepeat() throws {
        let defaults = makeDefaults()
        let now = Date()
        let gift = SpeakOverGift(text: text, book: nil, from: nil, to: nil)
        SpeakOverInbox.deliver(gift, source: .link, now: now, defaults: defaults)
        let delivery = try XCTUnwrap(SpeakOverInbox.pending(now: now, defaults: defaults))
        SpeakOverInbox.markShown(delivery, now: now, defaults: defaults)
        XCTAssertNil(SpeakOverInbox.pending(now: now, defaults: defaults))

        XCTAssertFalse(SpeakOverInbox.deliver(gift, source: .link, now: now.addingTimeInterval(60), defaults: defaults))
        XCTAssertTrue(SpeakOverInbox.deliver(gift, source: .link,
                                             now: now.addingTimeInterval(SpeakOverInbox.repeatWindow + 1),
                                             defaults: defaults))
    }

    func testInboxKeepsANewerGiftThatArrivedWhileOneWasOpen() throws {
        let defaults = makeDefaults()
        let first = SpeakOverGift(text: "I am whole.", book: nil, from: nil, to: nil)
        let second = SpeakOverGift(text: "I am free.", book: nil, from: nil, to: nil)
        SpeakOverInbox.deliver(first, source: .link, defaults: defaults)
        let shown = try XCTUnwrap(SpeakOverInbox.pending(defaults: defaults))
        SpeakOverInbox.deliver(second, source: .link, defaults: defaults)
        SpeakOverInbox.markShown(shown, defaults: defaults)
        XCTAssertEqual(SpeakOverInbox.pending(defaults: defaults)?.gift, second)
    }

    func testInboxDropsAnExpiredGift() {
        let defaults = makeDefaults()
        let then = Date()
        SpeakOverInbox.deliver(SpeakOverGift(text: text, book: nil, from: nil, to: nil),
                               source: .deferred, now: then, defaults: defaults)
        XCTAssertNil(SpeakOverInbox.pending(now: then.addingTimeInterval(SpeakOverInbox.lifetime + 1),
                                            defaults: defaults))
        XCTAssertNil(SpeakOverInbox.pending(now: then, defaults: defaults))
    }

    func testShareTextReadsCompleteWithoutTheLink() {
        // ReferralShareText drops the link outside messaging apps, so the
        // words must not end pointing at something that is not there.
        XCTAssertTrue(SpeakOverCopy.shareText(to: nil).hasSuffix("."))
        XCTAssertTrue(SpeakOverCopy.shareText(to: "Ana").hasSuffix("."))
        XCTAssertFalse(SpeakOverCopy.shareText(to: nil).contains(":"))
    }

    func testSublineUsesTheRecipientName() {
        XCTAssertEqual(SpeakOverCopy.subline(to: nil), "Speak this out loud today.")
        XCTAssertEqual(SpeakOverCopy.subline(to: ""), "Speak this out loud today.")
        XCTAssertEqual(SpeakOverCopy.subline(to: "Ana"), "Ana, speak this out loud today.")
    }

    // MARK: - Combining marks and joiners

    func testStackedCombiningMarksAreCapped() throws {
        let zalgo = "I" + String(repeating: "\u{0301}", count: 40) + " am whole"
        let cleaned = try XCTUnwrap(SpeakOverLink.clean(zalgo, limit: nil))
        XCTAssertEqual(cleaned.unicodeScalars.count,
                       1 + SpeakOverLink.maxMarksPerCharacter + " am whole".unicodeScalars.count)
        // An ordinary accent survives untouched.
        XCTAssertEqual(SpeakOverLink.clean("Jose\u{0301}", limit: nil), "Jose\u{0301}")
    }

    func testParseRejectsTextWithTooManyScalars() throws {
        // 280 characters, each a letter with three marks: within the
        // character cap, over the scalar cap.
        let heavy = String(repeating: "a\u{0301}\u{0302}\u{0303}", count: SpeakOverLink.maxTextLength)
        XCTAssertEqual(heavy.count, SpeakOverLink.maxTextLength)
        var components = URLComponents(string: "https://speaklife.app.link/")!
        components.queryItems = [URLQueryItem(name: "so_t", value: heavy)]
        XCTAssertNil(SpeakOverLink.parse(try XCTUnwrap(components.url)))
    }

    func testBuildKeepsWithinTheScalarCap() throws {
        let heavy = String(repeating: "a\u{0301}\u{0302}\u{0303}", count: SpeakOverLink.maxTextLength)
        let url = SpeakOverLink.url(text: heavy, book: nil, from: nil, to: nil, campaign: nil)
        let gift = try XCTUnwrap(SpeakOverLink.parse(url))
        XCTAssertLessThanOrEqual(gift.text.unicodeScalars.count,
                                 SpeakOverLink.maxTextLength * SpeakOverLink.maxScalarsPerCharacter)
    }

    func testJoinersSurviveCleaning() {
        let family = "\u{1F468}\u{200D}\u{1F469}\u{200D}\u{1F467}"
        XCTAssertEqual(SpeakOverLink.clean("Love \(family)", limit: nil), "Love \(family)")
        // Persian spelling that needs the zero-width non-joiner.
        let persian = "\u{0645}\u{06CC}\u{200C}\u{062E}\u{0648}\u{0627}\u{0647}\u{0645}"
        XCTAssertEqual(SpeakOverLink.clean(persian, limit: nil), persian)
    }

    // MARK: - Verse

    func testVerseOnlyForAnExactMatch() {
        let pool = [
            Declaration(text: "I am healed.", book: "Isaiah 53:5", bibleVerseText: "By his wounds we are healed.",
                        category: .health),
            Declaration(text: "Mine.", book: nil, bibleVerseText: "Should not show.", category: .myOwn)
        ]
        XCTAssertEqual(SpeakOverLink.verse(for: SpeakOverGift(text: "I am healed.", book: "Isaiah 53:5", from: nil, to: nil),
                                           in: pool), "By his wounds we are healed.")
        XCTAssertNil(SpeakOverLink.verse(for: SpeakOverGift(text: "I am healed", book: "Isaiah 53:5", from: nil, to: nil),
                                         in: pool))
        XCTAssertNil(SpeakOverLink.verse(for: SpeakOverGift(text: "I am healed.", book: "Psalm 1:3", from: nil, to: nil),
                                         in: pool))
        XCTAssertNil(SpeakOverLink.verse(for: SpeakOverGift(text: "Mine.", book: nil, from: nil, to: nil), in: pool))
    }

    // MARK: - Opened once

    func testOpenedIsCountedOncePerDelivery() {
        let defaults = makeDefaults()
        let delivery = SpeakOverDelivery(gift: SpeakOverGift(text: text, book: nil, from: nil, to: nil),
                                         source: .link, receivedAt: Date())
        XCTAssertTrue(SpeakOverInbox.markOpened(delivery, defaults: defaults))
        XCTAssertFalse(SpeakOverInbox.markOpened(delivery, defaults: defaults))
        let other = SpeakOverDelivery(gift: delivery.gift, source: .link, receivedAt: Date())
        XCTAssertTrue(SpeakOverInbox.markOpened(other, defaults: defaults))
    }

    // MARK: - Presentation gate

    func testGateNeedsTwoIdleChecksInARow() {
        var gate = SpeakOverGate()
        XCTAssertEqual(gate.check(isIdle: true), .retry)
        XCTAssertEqual(gate.check(isIdle: false), .retry)
        XCTAssertEqual(gate.check(isIdle: true), .retry)
        XCTAssertEqual(gate.check(isIdle: true), .present)
    }

    func testGateGivesUpWhenTheBudgetIsSpentAndResetRefillsIt() {
        var gate = SpeakOverGate()
        for _ in 0..<SpeakOverGate.maxRetries {
            XCTAssertEqual(gate.check(isIdle: false), .retry)
        }
        XCTAssertEqual(gate.check(isIdle: false), .giveUp)
        gate.reset()
        XCTAssertEqual(gate.retriesLeft, SpeakOverGate.maxRetries)
        XCTAssertEqual(gate.check(isIdle: true), .retry)
        XCTAssertEqual(gate.check(isIdle: true), .present)
    }

    func testResetClearsAHalfConfirmedIdle() {
        var gate = SpeakOverGate()
        _ = gate.check(isIdle: true)
        gate.reset()
        XCTAssertEqual(gate.idleChecks, 0)
        XCTAssertEqual(gate.check(isIdle: true), .retry)
    }
}
