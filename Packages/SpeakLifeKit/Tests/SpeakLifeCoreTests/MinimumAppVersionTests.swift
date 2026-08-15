//
//  MinimumAppVersionTests.swift
//  SpeakLifeCoreTests
//
//  The forced-update gate is the one switch that can lock every user out of a
//  working app, so the fail-open rules get tested harder than the block itself.
//

import XCTest
@testable import SpeakLifeCore

final class AppVersionParsingTests: XCTestCase {

    func testParsesDottedNumericVersions() {
        XCTAssertEqual(AppVersion("2.4.1")?.components, [2, 4, 1])
        XCTAssertEqual(AppVersion("2.4")?.components, [2, 4])
        XCTAssertEqual(AppVersion("2")?.components, [2])
        XCTAssertEqual(AppVersion("10.0.12")?.components, [10, 0, 12])
    }

    func testTrimsSurroundingWhitespace() {
        // The Firebase console field is free text; a trailing space typed by
        // hand must not silently disable the gate.
        XCTAssertEqual(AppVersion(" 2.4.0 ")?.components, [2, 4, 0])
        XCTAssertEqual(AppVersion("2.4.0\n")?.components, [2, 4, 0])
    }

    func testRejectsNonNumericAndMalformedVersions() {
        XCTAssertNil(AppVersion(""))
        XCTAssertNil(AppVersion("   "))
        XCTAssertNil(AppVersion("v2.4.0"))
        XCTAssertNil(AppVersion("2.4.0-beta"))
        XCTAssertNil(AppVersion("2.4.0b"))
        XCTAssertNil(AppVersion("2..4"))
        XCTAssertNil(AppVersion("2.4."))
        XCTAssertNil(AppVersion(".2.4"))
        XCTAssertNil(AppVersion("-1.0"))
        XCTAssertNil(AppVersion("+2.0"))
        XCTAssertNil(AppVersion("latest"))
    }

    func testOrdersByComponent() {
        XCTAssertLessThan(AppVersion("2.3.9")!, AppVersion("2.4.0")!)
        XCTAssertLessThan(AppVersion("2.9.0")!, AppVersion("3.0.0")!)
        XCTAssertLessThan(AppVersion("2.4.1")!, AppVersion("2.4.10")!)
        XCTAssertGreaterThan(AppVersion("10.0.0")!, AppVersion("9.9.9")!)
    }

    func testNumericOrderingNotLexicographic() {
        // "9" > "10" as strings; the whole point of parsing is that it isn't here.
        XCTAssertLessThan(AppVersion("2.9")!, AppVersion("2.10")!)
    }

    func testTrailingZerosAreTheSameVersion() {
        XCTAssertEqual(AppVersion("2.4"), AppVersion("2.4.0"))
        XCTAssertEqual(AppVersion("2"), AppVersion("2.0.0"))
        XCTAssertEqual(AppVersion("2.4")!.hashValue, AppVersion("2.4.0")!.hashValue)
        XCTAssertFalse(AppVersion("2.4")! < AppVersion("2.4.0")!)
        XCTAssertFalse(AppVersion("2.4.0")! < AppVersion("2.4")!)
    }

    func testShorterVersionWithHigherComponentStillWins() {
        XCTAssertGreaterThan(AppVersion("2.5")!, AppVersion("2.4.99")!)
    }

    func testDescriptionRoundTrips() {
        XCTAssertEqual(AppVersion("2.4.1")?.description, "2.4.1")
    }
}

final class MinimumVersionPolicyTests: XCTestCase {

    // MARK: - Blocking

    func testBlocksWhenBelowMinimum() {
        XCTAssertEqual(
            MinimumVersionPolicy.requirement(currentVersion: "2.3.9",
                                             minimumVersion: "2.4.0",
                                             isEnabled: true),
            .forced
        )
    }

    func testAllowsWhenExactlyAtMinimum() {
        XCTAssertEqual(
            MinimumVersionPolicy.requirement(currentVersion: "2.4.0",
                                             minimumVersion: "2.4.0",
                                             isEnabled: true),
            .allowed
        )
    }

    func testAllowsWhenAboveMinimum() {
        XCTAssertEqual(
            MinimumVersionPolicy.requirement(currentVersion: "2.5.0",
                                             minimumVersion: "2.4.0",
                                             isEnabled: true),
            .allowed
        )
    }

    func testAllowsWhenMinimumOmitsTrailingZeros() {
        // Publishing "2.4" must not block the build that ships as "2.4.0".
        XCTAssertEqual(
            MinimumVersionPolicy.requirement(currentVersion: "2.4.0",
                                             minimumVersion: "2.4",
                                             isEnabled: true),
            .allowed
        )
    }

    // MARK: - Fail open

    func testKillSwitchOffAllowsEvenAncientBuilds() {
        XCTAssertEqual(
            MinimumVersionPolicy.requirement(currentVersion: "1.0.0",
                                             minimumVersion: "9.9.9",
                                             isEnabled: false),
            .allowed
        )
    }

    func testUnsetMinimumAllows() {
        // The shipped Remote Config default. The feature must be inert until an
        // operator deliberately publishes a floor.
        XCTAssertEqual(
            MinimumVersionPolicy.requirement(currentVersion: "2.4.0",
                                             minimumVersion: "",
                                             isEnabled: true),
            .allowed
        )
    }

    func testTypoInMinimumAllows() {
        // A console typo would otherwise take the app down for everyone, with
        // the fix reachable only by the users already locked out.
        for typo in ["v2.4.0", "2.4.0-beta", "latest", "2..4", "two point four"] {
            XCTAssertEqual(
                MinimumVersionPolicy.requirement(currentVersion: "2.3.0",
                                                 minimumVersion: typo,
                                                 isEnabled: true),
                .allowed,
                "minimum \"\(typo)\" should not lock users out"
            )
        }
    }

    func testUnreadableCurrentVersionAllows() {
        // A missing or odd CFBundleShortVersionString is our bug, not the
        // user's; it must not cost them the app.
        for current in ["", "unknown", "1.0.0-rc1"] {
            XCTAssertEqual(
                MinimumVersionPolicy.requirement(currentVersion: current,
                                                 minimumVersion: "2.4.0",
                                                 isEnabled: true),
                .allowed,
                "current \"\(current)\" should not lock users out"
            )
        }
    }

    func testWhitespacePaddedValuesStillCompare() {
        XCTAssertEqual(
            MinimumVersionPolicy.requirement(currentVersion: "2.3.0",
                                             minimumVersion: " 2.4.0 ",
                                             isEnabled: true),
            .forced
        )
    }
}
