//
//  ReferralPushTests.swift
//  SpeakLifeCoreTests
//
//  FE-CON-01: the push payload the server sends (shared fixture, asserted on
//  the server side by BE-CON-01) is one the app routes to the referral page.
//

import XCTest
@testable import SpeakLifeCore

final class ReferralPushTests: XCTestCase {

    func test_FE_CON_01_serverPushPayloadIsRoutedAsReferral() throws {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "referral_push_fixture", withExtension: "json"))
        let object = try JSONSerialization.jsonObject(with: Data(contentsOf: url))
        let payload = try XCTUnwrap(object as? [String: Any])
        var userInfo: [AnyHashable: Any] = [:]
        for (key, value) in payload { userInfo[key] = value }
        XCTAssertTrue(ReferralPush.isReferral(userInfo))
        XCTAssertEqual(payload["deepLink"] as? String, ReferralPush.deepLink)
    }

    func test_FE_CON_02_otherPushesAreNotReferral() {
        XCTAssertFalse(ReferralPush.isReferral(["deepLink": "declarations"]))
        XCTAssertFalse(ReferralPush.isReferral([:]))
    }
}
