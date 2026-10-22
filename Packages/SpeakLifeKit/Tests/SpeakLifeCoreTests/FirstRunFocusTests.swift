//
//  FirstRunFocusTests.swift
//  SpeakLifeCoreTests
//
//  A false positive hides the shortcut tiles from an existing user, and a stuck
//  true leaves a new user on a one-button screen forever, so each gate gets a case.
//

import XCTest
@testable import SpeakLifeCore

final class FirstRunFocusTests: XCTestCase {

    private let start = Date(timeIntervalSince1970: 1_780_000_000)

    private func active(
        flag: Bool = true,
        startedAt: Date?? = .none,
        burstDone: Bool = false,
        after elapsed: TimeInterval = 60
    ) -> Bool {
        FirstRunFocusRule.isActive(
            flagEnabled: flag,
            startedAt: startedAt ?? start,
            firstBurstDone: burstDone,
            now: start.addingTimeInterval(elapsed)
        )
    }

    func testNewUserRightAfterOnboardingIsFocused() {
        XCTAssertTrue(active())
    }

    func testFlagOffIsNeverFocused() {
        XCTAssertFalse(active(flag: false))
    }

    func testExistingUserWithNoStampIsNeverFocused() {
        XCTAssertFalse(active(startedAt: .some(nil)))
    }

    func testFirstBurstEndsFocus() {
        XCTAssertFalse(active(burstDone: true))
    }

    func testFocusEndsAfterMaxDuration() {
        XCTAssertTrue(active(after: FirstRunFocusRule.maxDuration - 1))
        XCTAssertFalse(active(after: FirstRunFocusRule.maxDuration))
    }

    func testClockSetBackwardsStillFocuses() {
        XCTAssertTrue(active(after: -3600))
    }
}
