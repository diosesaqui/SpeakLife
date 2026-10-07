//
//  ReferralLinkTests.swift
//  SpeakLifeCoreTests
//
//  FE-LNK rows from docs/REFERRAL_FE_TDD.md §2. A Stand code must never read
//  as a referral code, and the client must normalise exactly as the server
//  does (FE-LNK-14 reads the same fixture as the backend's BE-HLP tests).
//
//  FE-LNK-07 (StandLink refuses `/r/`) lives with `StandLink` in the app
//  target and is not testable from this package.
//

import XCTest
@testable import SpeakLifeCore

final class ReferralLinkTests: XCTestCase {

    private func url(_ string: String) -> URL {
        guard let u = URL(string: string) else {
            XCTFail("bad test URL \(string)")
            return URL(string: "https://invalid.example")!
        }
        return u
    }

    // MARK: - URLs

    func test_FE_LNK_01_branchPathLink() {
        XCTAssertEqual(ReferralLink.code(from: url("https://speaklife.app.link/r/K7MQ2XPA")), "K7MQ2XPA")
    }

    func test_FE_LNK_02_anyHostAndNormalised() {
        XCTAssertEqual(ReferralLink.code(from: url("https://any.host/r/k7mq-2xpa")), "K7MQ2XPA")
    }

    func test_FE_LNK_03_customSchemePutsMarkerInHost() {
        XCTAssertEqual(ReferralLink.code(from: url("speaklife://r/K7MQ2XPA")), "K7MQ2XPA")
    }

    func test_FE_LNK_04_refQueryItem() {
        XCTAssertEqual(ReferralLink.code(from: url("https://speaklife.app.link/?ref=K7MQ2XPA")), "K7MQ2XPA")
    }

    func test_FE_LNK_05_upperCaseSegment() {
        XCTAssertEqual(ReferralLink.code(from: url("https://speaklife.app.link/R/K7MQ2XPA")), "K7MQ2XPA")
    }

    func test_FE_LNK_06_standPathIsNotReferral() {
        XCTAssertNil(ReferralLink.code(from: url("https://speaklife.app.link/stand/K7MQ2XPA")))
        XCTAssertNil(ReferralLink.code(from: url("speaklife://stand/K7MQ2XPA")))
        // Even a stray ?ref= on a Stand link is not a referral.
        XCTAssertNil(ReferralLink.code(from: url("https://speaklife.app.link/stand/ABCD2345?ref=K7MQ2XPA")))
    }

    func test_FE_LNK_08_malformedCodesAreRejected() {
        XCTAssertNil(ReferralLink.code(from: url("https://speaklife.app.link/r/")))
        XCTAssertNil(ReferralLink.code(from: url("https://speaklife.app.link/r/TOOSHORT1")))
        XCTAssertNil(ReferralLink.code(from: url("https://speaklife.app.link/r/K7MQ0XPA")))
        XCTAssertNil(ReferralLink.code(from: url("speaklife://r/")))
        XCTAssertNil(ReferralLink.code(from: url("https://speaklife.app.link/")))
    }

    func test_FE_LNK_09_extraPathSegmentsIgnored() {
        XCTAssertEqual(ReferralLink.code(from: url("https://speaklife.app.link/r/K7MQ2XPA/extra")), "K7MQ2XPA")
    }

    // MARK: - Branch params

    func test_FE_LNK_10_branchRefParam() {
        XCTAssertEqual(ReferralLink.code(fromBranchParams: ["ref": "k7mq2xpa"]), "K7MQ2XPA")
    }

    func test_FE_LNK_11_branchReferringLink() {
        let params: [String: Any] = ["~referring_link": "https://speaklife.app.link/r/K7MQ2XPA"]
        XCTAssertEqual(ReferralLink.code(fromBranchParams: params), "K7MQ2XPA")
    }

    func test_FE_LNK_12_refWinsOverReferringLink() {
        let params: [String: Any] = [
            "ref": "ABCD2345",
            "~referring_link": "https://speaklife.app.link/r/K7MQ2XPA",
        ]
        XCTAssertEqual(ReferralLink.code(fromBranchParams: params), "ABCD2345")
    }

    func test_FE_LNK_13_standParamsAreNotReferral() {
        let params: [String: Any] = [
            "stand": "K7MQ2XPA",
            "~referring_link": "https://speaklife.app.link/stand/K7MQ2XPA",
            "+clicked_branch_link": true,
        ]
        XCTAssertNil(ReferralLink.code(fromBranchParams: params))
        XCTAssertNil(ReferralLink.code(fromBranchParams: ["stand": "K7MQ2XPA"]))
    }

    // MARK: - Normalise, share, format

    private struct FixtureRow: Decodable {
        let input: String
        let expected: String?
    }

    func test_FE_LNK_14_normaliseMatchesServerFixture() throws {
        guard let fixtureURL = Bundle.module.url(forResource: "referral_codes_fixture", withExtension: "json") else {
            XCTFail("referral_codes_fixture.json is missing from the test bundle")
            return
        }
        let rows = try JSONDecoder().decode([FixtureRow].self, from: Data(contentsOf: fixtureURL))
        XCTAssertFalse(rows.isEmpty)
        for row in rows {
            XCTAssertEqual(ReferralLink.normalize(row.input), row.expected, "input: \(row.input)")
        }
    }

    func test_FE_LNK_15_shareURLUsesConfiguredDomain() {
        XCTAssertEqual(ReferralLink.shareURL(code: "K7MQ2XPA", host: "speaklife.app.link")?.absoluteString,
                       "https://speaklife.app.link/r/K7MQ2XPA")
        XCTAssertEqual(ReferralLink.shareURL(code: "K7MQ2XPA", host: "invite.example.com")?.absoluteString,
                       "https://invite.example.com/r/K7MQ2XPA")
        XCTAssertNil(ReferralLink.shareURL(code: "K7MQ0XPA", host: "speaklife.app.link"))
        XCTAssertNil(ReferralLink.shareURL(code: "K7MQ2XPA", host: "  "))
    }

    func test_FE_LNK_16_formattedForReadingAloud() {
        XCTAssertEqual(ReferralLink.formatted("K7MQ2XPA"), "K7MQ-2XPA")
        XCTAssertEqual(ReferralLink.formatted("SHORT"), "SHORT")
    }

    func test_alphabetMatchesStandAlphabet() {
        XCTAssertEqual(ReferralLink.alphabet, "ABCDEFGHJKMNPQRSTUVWXYZ23456789")
        XCTAssertEqual(ReferralLink.codeLength, 8)
    }

    func test_shareURLRoundTripsThroughParser() {
        guard let shared = ReferralLink.shareURL(code: "K7MQ2XPA", host: "speaklife.app.link") else {
            return XCTFail("no share URL")
        }
        XCTAssertEqual(ReferralLink.code(from: shared), "K7MQ2XPA")
    }
}
