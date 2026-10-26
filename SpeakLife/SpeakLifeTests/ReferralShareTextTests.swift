//
//  ReferralShareTextTests.swift
//  SpeakLifeTests
//
//  The tracked link rides along only when a share is sent as a message.
//  A post or a saved image gets the words alone.
//

import XCTest
import UIKit
@testable import SpeakLife

final class ReferralShareTextTests: XCTestCase {

    private let link = URL(string: "https://speaklife.app.link/?channel=share&feature=devotional")!

    func testMessagingAppsGetTheLink() {
        let messaging: [UIActivity.ActivityType] = [
            .message,
            .mail,
            .airDrop,
            .copyToPasteboard,
            UIActivity.ActivityType("net.whatsapp.WhatsApp.ShareExtension"),
            UIActivity.ActivityType("com.facebook.Messenger.ShareExtension"),
            UIActivity.ActivityType("ph.telegra.Telegraph.Share"),
            UIActivity.ActivityType("org.whispersystems.signal.shareextension")
        ]
        for type in messaging {
            XCTAssertEqual(ReferralShareText.message(text: "Speak it with me", link: link, for: type),
                           "Speak it with me\n\(link.absoluteString)", type.rawValue)
        }
    }

    func testPostsAndSavesGetWordsOnly() {
        let posting: [UIActivity.ActivityType] = [
            UIActivity.ActivityType("com.apple.UIKit.activity.PostToFacebook"),
            .saveToCameraRoll,
            UIActivity.ActivityType("com.burbn.instagram.shareextension"),
            UIActivity.ActivityType("com.apple.mobilenotes.SharingExtension")
        ]
        for type in posting {
            XCTAssertEqual(ReferralShareText.message(text: "Speak it with me", link: link, for: type),
                           "Speak it with me", type.rawValue)
        }
    }

    /// Facebook's own app must not be mistaken for Messenger.
    func testFacebookAppIsNotMessenger() {
        XCTAssertFalse(ReferralShareText.includesLink(
            for: UIActivity.ActivityType("com.facebook.Facebook.ShareExtension")))
    }

    func testUnknownDestinationKeepsTheLink() {
        XCTAssertTrue(ReferralShareText.includesLink(for: nil))
    }

    func testEmptyWords() {
        XCTAssertEqual(ReferralShareText.message(text: "  ", link: link, for: .message), link.absoluteString)
        XCTAssertNil(ReferralShareText.message(text: "", link: link, for: .saveToCameraRoll))
    }

    /// A "+" in link data must survive Branch, which reads a bare "+" as a space.
    func testPlusIsPercentEncodedInLinkData() {
        let url = ReferralLink.url(.speakOver, extra: [URLQueryItem(name: "so_t", value: "Grace + peace")])
        XCTAssertTrue(url.absoluteString.contains("Grace%20+%20peace") == false)
        XCTAssertTrue(url.absoluteString.contains("%2B"))
        let parsed = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?.first { $0.name == "so_t" }?.value
        XCTAssertEqual(parsed, "Grace + peace")
    }
}
