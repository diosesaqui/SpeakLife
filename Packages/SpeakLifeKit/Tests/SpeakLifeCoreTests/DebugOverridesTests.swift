//
//  DebugOverridesTests.swift
//  SpeakLifeCoreTests
//
//  The debug override store is what a tester's shake panel writes into and what
//  every flag read consults first, so the two things that must hold are: a set
//  override reads back, and clearing returns the key to "absent" so the caller
//  falls through to Remote Config.
//

import XCTest
@testable import SpeakLifeCore

final class DebugOverridesTests: XCTestCase {

    override func setUp() {
        super.setUp()
        DebugOverrides.clearAll()
    }

    override func tearDown() {
        DebugOverrides.clearAll()
        super.tearDown()
    }

    func testOverridesAreAvailableUnderTest() {
        // Tests build DEBUG, so the whole store is live. Every other assertion
        // in this file depends on that.
        XCTAssertTrue(DebugOverrides.isAvailable)
    }

    func testAbsentKeyReadsNilSoCallersFallThroughToRemoteConfig() {
        XCTAssertNil(DebugOverrides.bool("enforcementEnabled"))
        XCTAssertNil(DebugOverrides.string("onboardingVariant"))
    }

    func testBoolOverrideRoundTrips() {
        DebugOverrides.setBool("enforcementEnabled", false)
        XCTAssertEqual(DebugOverrides.bool("enforcementEnabled"), false)

        DebugOverrides.setBool("enforcementEnabled", true)
        XCTAssertEqual(DebugOverrides.bool("enforcementEnabled"), true)
    }

    func testStringOverrideRoundTrips() {
        DebugOverrides.setString("onboardingVariant", "closer")
        XCTAssertEqual(DebugOverrides.string("onboardingVariant"), "closer")
    }

    /// `false` is a real override, not an absent key. Storing it as "no value"
    /// would silently hand the flag back to Remote Config the moment a tester
    /// switched something off — the exact case the panel is for.
    func testFalseIsDistinctFromUnset() {
        DebugOverrides.setBool("guardEnabled", false)
        XCTAssertEqual(DebugOverrides.bool("guardEnabled"), false)
        XCTAssertNotNil(DebugOverrides.bool("guardEnabled"))
    }

    func testBoolAndStringNamespacesDoNotCollide() {
        DebugOverrides.setBool("sharedKey", true)
        DebugOverrides.setString("sharedKey", "warfare")

        XCTAssertEqual(DebugOverrides.bool("sharedKey"), true)
        XCTAssertEqual(DebugOverrides.string("sharedKey"), "warfare")
    }

    func testSettingNilClearsASingleOverride() {
        DebugOverrides.setBool("guardEnabled", false)
        DebugOverrides.setBool("checklistHomeEnabled", false)

        DebugOverrides.setBool("guardEnabled", nil)

        XCTAssertNil(DebugOverrides.bool("guardEnabled"))
        XCTAssertEqual(DebugOverrides.bool("checklistHomeEnabled"), false)
        XCTAssertEqual(DebugOverrides.activeOverrideCount, 1)
    }

    func testClearAllRemovesEveryOverride() {
        DebugOverrides.setBool("guardEnabled", false)
        DebugOverrides.setBool("enforcementEnabled", false)
        DebugOverrides.setString("onboardingVariant", "quiz")
        XCTAssertTrue(DebugOverrides.hasActiveOverrides)

        DebugOverrides.clearAll()

        XCTAssertFalse(DebugOverrides.hasActiveOverrides)
        XCTAssertEqual(DebugOverrides.activeOverrideCount, 0)
        XCTAssertNil(DebugOverrides.bool("guardEnabled"))
        XCTAssertNil(DebugOverrides.bool("enforcementEnabled"))
        XCTAssertNil(DebugOverrides.string("onboardingVariant"))
    }

    /// Re-setting the same key must not grow the index, or "3 overrides active"
    /// in the panel header would be a lie after a few taps.
    func testRepeatedWritesDoNotDuplicateTheIndex() {
        DebugOverrides.setBool("guardEnabled", true)
        DebugOverrides.setBool("guardEnabled", false)
        DebugOverrides.setBool("guardEnabled", true)

        XCTAssertEqual(DebugOverrides.activeOverrideCount, 1)
    }

    func testWritePostsDidChange() {
        expectation(forNotification: DebugOverrides.didChange, object: nil)
        DebugOverrides.setBool("guardEnabled", false)
        waitForExpectations(timeout: 1)
    }
}
