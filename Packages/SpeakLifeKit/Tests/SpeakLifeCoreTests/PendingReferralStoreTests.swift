//
//  PendingReferralStoreTests.swift
//  SpeakLifeCoreTests
//
//  FE-PND rows from docs/REFERRAL_FE_TDD.md §3. In-memory storage and a
//  controllable clock: first capture wins, the window cannot be stretched,
//  and corrupt data never crashes.
//

import XCTest
@testable import SpeakLifeCore

final class ReferralTestClock {
    var now: Date
    init(_ now: Date) { self.now = now }
    func advance(_ seconds: TimeInterval) { now = now.addingTimeInterval(seconds) }
}

final class PendingReferralStoreTests: XCTestCase {

    private let start = Date(timeIntervalSince1970: 1_790_000_000)
    private let day: TimeInterval = 86_400

    private var kv: InMemoryReferralKeyValueStore!
    private var clock: ReferralTestClock!
    private var store: PendingReferralStore!

    override func setUp() {
        super.setUp()
        kv = InMemoryReferralKeyValueStore()
        clock = ReferralTestClock(start)
        store = makeStore()
    }

    private func makeStore() -> PendingReferralStore {
        let clock = self.clock!
        let storage: ReferralKeyValueStore = kv!
        return PendingReferralStore(store: storage, windowDays: 14, now: { clock.now })
    }

    func test_FE_PND_01_captureWithNothingPending() {
        XCTAssertEqual(store.capture(code: "k7mq-2xpa", source: .deferred), .captured)
        let pending = store.pending
        XCTAssertEqual(pending?.code, "K7MQ2XPA")
        XCTAssertEqual(pending?.capturedAt, start)
        XCTAssertEqual(pending?.source, .deferred)
        XCTAssertEqual(pending?.attempts, 0)
        XCTAssertNil(pending?.lastAttemptAt)
    }

    func test_FE_PND_02_secondCaptureDifferentCodeIgnored() {
        store.capture(code: "K7MQ2XPA", source: .deferred)
        clock.advance(60)
        XCTAssertEqual(store.capture(code: "ABCD2345", source: .universalLink), .alreadyPending)
        XCTAssertEqual(store.pending?.code, "K7MQ2XPA")
        XCTAssertEqual(store.pending?.source, .deferred)
    }

    func test_FE_PND_03_sameCodeDoesNotRefreshCapturedAt() {
        store.capture(code: "K7MQ2XPA", source: .deferred)
        clock.advance(10 * day)
        XCTAssertEqual(store.capture(code: "K7MQ2XPA", source: .universalLink), .alreadyPending)
        XCTAssertEqual(store.pending?.capturedAt, start)
    }

    func test_FE_PND_04_captureAfterFinalIsAlreadyClaimed() {
        store.markFinal()
        XCTAssertEqual(store.capture(code: "K7MQ2XPA", source: .manual), .alreadyClaimed)
        XCTAssertNil(store.pending)
        XCTAssertNil(kv.data(forKey: PendingReferralStore.pendingKey))
    }

    func test_FE_PND_05_stillPendingAtExactlyFourteenDays() {
        store.capture(code: "K7MQ2XPA", source: .deferred)
        clock.advance(14 * day)
        XCTAssertEqual(store.pending?.code, "K7MQ2XPA")
    }

    func test_FE_PND_06_expiredOneSecondPastWindowAndCleared() {
        store.capture(code: "K7MQ2XPA", source: .deferred)
        clock.advance(14 * day + 1)
        XCTAssertNil(store.pending)
        XCTAssertNil(kv.data(forKey: PendingReferralStore.pendingKey))
        // An expired value no longer blocks a fresh capture.
        XCTAssertEqual(store.capture(code: "ABCD2345", source: .universalLink), .captured)
    }

    func test_FE_PND_07_survivesRelaunch() {
        store.capture(code: "K7MQ2XPA", source: .universalLink)
        store.recordAttempt()
        let before = store.pending

        let relaunched = makeStore()
        XCTAssertNotNil(before)
        XCTAssertEqual(relaunched.pending, before)
    }

    func test_FE_PND_08_corruptDataReadsAsNothingAndIsCleared() {
        let corrupt: [Data] = [
            Data("not json".utf8),
            Data(#"{"code": 5, "capturedAt": "yesterday", "source": "deferred", "attempts": 0}"#.utf8),
            Data(#"{"code": "K7MQ2XPA", "capturedAt": 811692800, "source": "carrier_pigeon", "attempts": 0}"#.utf8),
            Data(#"{"code": "K7MQ0XPA", "capturedAt": 811692800, "source": "deferred", "attempts": 0}"#.utf8),
            Data(#"[1, 2, 3]"#.utf8),
        ]
        for data in corrupt {
            kv.set(data, forKey: PendingReferralStore.pendingKey)
            XCTAssertNil(store.pending, String(decoding: data, as: UTF8.self))
            XCTAssertNil(kv.data(forKey: PendingReferralStore.pendingKey))
        }
        XCTAssertEqual(store.capture(code: "K7MQ2XPA", source: .deferred), .captured)
    }

    func test_FE_PND_09_markFinalClearsAndBlocksForever() {
        store.capture(code: "K7MQ2XPA", source: .deferred)
        store.markFinal()
        XCTAssertNil(store.pending)
        XCTAssertTrue(store.isFinal)
        XCTAssertEqual(store.capture(code: "ABCD2345", source: .manual), .alreadyClaimed)
        XCTAssertTrue(makeStore().isFinal, "the final flag persists across launches")
    }

    func test_FE_PND_10_recordAttemptIncrementsAndPersists() {
        store.capture(code: "K7MQ2XPA", source: .deferred)
        clock.advance(120)
        store.recordAttempt()
        XCTAssertEqual(store.pending?.attempts, 1)
        XCTAssertEqual(store.pending?.lastAttemptAt, start.addingTimeInterval(120))

        clock.advance(7200)
        store.recordAttempt()
        let relaunched = makeStore()
        XCTAssertEqual(relaunched.pending?.attempts, 2)
        XCTAssertEqual(relaunched.pending?.lastAttemptAt, start.addingTimeInterval(7320))
    }

    func test_invalidCodeIsNotCaptured() {
        XCTAssertEqual(store.capture(code: "K7MQ0XPA", source: .manual), .invalid)
        XCTAssertNil(store.pending)
    }

    func test_clearDoesNotSetFinal() {
        store.capture(code: "K7MQ2XPA", source: .deferred)
        store.clear()
        XCTAssertNil(store.pending)
        XCTAssertFalse(store.isFinal)
        XCTAssertEqual(store.capture(code: "ABCD2345", source: .manual), .captured)
    }

    func test_recordAttemptWithNothingPendingIsNoOp() {
        store.recordAttempt()
        XCTAssertNil(store.pending)
    }
}
