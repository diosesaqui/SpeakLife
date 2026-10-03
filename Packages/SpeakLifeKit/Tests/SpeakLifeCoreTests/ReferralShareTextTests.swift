//
//  ReferralShareTextTests.swift
//  SpeakLifeCoreTests
//
//  Spec §9.4: the share text carries the link exactly once, whatever the
//  Remote Config template looks like. Supports FE-VM-03, whose share-sheet
//  half is tested in the app target.
//

import XCTest
@testable import SpeakLifeCore

final class ReferralShareTextTests: XCTestCase {

    private let link = URL(string: "https://speaklife.app.link/r/K7MQ2XPA")!

    private func occurrences(of needle: String, in haystack: String) -> Int {
        haystack.components(separatedBy: needle).count - 1
    }

    func test_shareText_replacesPlaceholder() {
        let text = ReferralShareText.render(template: ReferralShareText.defaultTemplate, link: link)
        XCTAssertEqual(text, "I've been speaking God's promises out loud every morning with SpeakLife. Try it free: https://speaklife.app.link/r/K7MQ2XPA")
        XCTAssertEqual(occurrences(of: link.absoluteString, in: text), 1)
    }

    func test_shareText_appendsLinkWhenPlaceholderMissing() {
        let text = ReferralShareText.render(template: "Try SpeakLife with me.", link: link)
        XCTAssertEqual(text, "Try SpeakLife with me. https://speaklife.app.link/r/K7MQ2XPA")
    }

    func test_shareText_exactlyOneLinkWithRepeatedPlaceholders() {
        let text = ReferralShareText.render(template: "{link} Try it {link}", link: link)
        XCTAssertEqual(occurrences(of: link.absoluteString, in: text), 1)
        XCTAssertFalse(text.contains("{link}"))
    }

    func test_shareText_emptyTemplateIsJustTheLink() {
        XCTAssertEqual(ReferralShareText.render(template: "   ", link: link), link.absoluteString)
    }
}
