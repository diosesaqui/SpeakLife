//
//  ReferralSnapshotTests.swift
//  SpeakLifeCoreTests
//
//  FE-SNP rows from docs/REFERRAL_FE_TDD.md §7. The server record and its
//  UserDefaults cache decode leniently and never crash.
//

import XCTest
@testable import SpeakLifeCore

final class ReferralSnapshotTests: XCTestCase {

    private let expiry = Date(timeIntervalSince1970: 1_806_000_000)

    private func fullDocument() -> [String: Any] {
        [
            "uid": "referrer-uid",
            "code": "K7MQ2XPA",
            "target": 5,
            "count": 5,
            "status": "unlocked",
            "createdAt": Date(timeIntervalSince1970: 1_790_000_000),
            "updatedAt": Date(timeIntervalSince1970: 1_790_500_000),
            "unlockedAt": Date(timeIntervalSince1970: 1_790_500_000),
            "reward": [
                "code": "ABCD1234EFGH",
                "assignedAt": Date(timeIntervalSince1970: 1_790_500_000),
                "expiresAt": expiry,
                "reissueCount": 0,
            ] as [String: Any],
        ]
    }

    func test_FE_SNP_01_fullServerDocumentDecodes() {
        let snapshot = ReferralSnapshot(dictionary: fullDocument())
        XCTAssertEqual(snapshot, ReferralSnapshot(
            code: "K7MQ2XPA", count: 5, target: 5, status: .unlocked,
            reward: ReferralReward(code: "ABCD1234EFGH", expiresAt: expiry, reissueCount: 0)))
    }

    func test_FE_SNP_01_firestoreNumbersAsNSNumber() {
        var doc = fullDocument()
        doc["count"] = NSNumber(value: Int64(3))
        doc["target"] = NSNumber(value: Int64(5))
        doc["status"] = "active"
        doc["reward"] = nil
        let snapshot = ReferralSnapshot(dictionary: doc)
        XCTAssertEqual(snapshot?.count, 3)
        XCTAssertEqual(snapshot?.target, 5)
        XCTAssertEqual(snapshot?.status, .active)
    }

    func test_FE_SNP_02_missingRewardIsNil() {
        var doc = fullDocument()
        doc.removeValue(forKey: "reward")
        XCTAssertNil(ReferralSnapshot(dictionary: doc)?.reward)
        doc["reward"] = NSNull()
        XCTAssertNil(ReferralSnapshot(dictionary: doc)?.reward)
        XCTAssertNotNil(ReferralSnapshot(dictionary: doc))
    }

    func test_FE_SNP_03_unknownStatusReadsAsActive() {
        var doc = fullDocument()
        doc["status"] = "paused_by_a_newer_server"
        XCTAssertEqual(ReferralSnapshot(dictionary: doc)?.status, .active)
        doc.removeValue(forKey: "status")
        XCTAssertEqual(ReferralSnapshot(dictionary: doc)?.status, .active)

        // The cached copy is just as lenient.
        let json = #"{"code":"K7MQ2XPA","count":1,"target":5,"status":"something_new"}"#
        let cached = ReferralSnapshot.fromCache(Data(json.utf8))
        XCTAssertEqual(cached?.status, .active)
        XCTAssertEqual(cached?.count, 1)
        XCTAssertNil(cached?.reward)
    }

    func test_FE_SNP_03_pendingCodeStatus() {
        var doc = fullDocument()
        doc["status"] = "unlocked_pending_code"
        doc.removeValue(forKey: "reward")
        XCTAssertEqual(ReferralSnapshot(dictionary: doc)?.status, .unlockedPendingCode)
    }

    func test_FE_SNP_04_extraFieldsIgnored() {
        var doc = fullDocument()
        doc["someFutureField"] = ["nested": true]
        doc["leaderboardRank"] = 7
        XCTAssertEqual(ReferralSnapshot(dictionary: doc), ReferralSnapshot(dictionary: fullDocument()))
    }

    func test_FE_SNP_05_cacheRoundTrip() {
        let original = ReferralSnapshot(
            code: "K7MQ2XPA", count: 2, target: 5, status: .unlocked,
            reward: ReferralReward(code: "ABCD1234EFGH", expiresAt: expiry, reissueCount: 1))
        XCTAssertEqual(ReferralSnapshot.fromCache(original.cacheData()), original)

        let noReward = ReferralSnapshot(code: "K7MQ2XPA", count: 0, target: 5, status: .active, reward: nil)
        XCTAssertEqual(ReferralSnapshot.fromCache(noReward.cacheData()), noReward)

        let pendingCode = ReferralSnapshot(code: "K7MQ2XPA", count: 5, target: 5, status: .unlockedPendingCode, reward: nil)
        XCTAssertEqual(ReferralSnapshot.fromCache(pendingCode.cacheData()), pendingCode)
    }

    func test_FE_SNP_06_corruptCacheIsNil() {
        XCTAssertNil(ReferralSnapshot.fromCache(nil))
        XCTAssertNil(ReferralSnapshot.fromCache(Data()))
        XCTAssertNil(ReferralSnapshot.fromCache(Data("garbage".utf8)))
        XCTAssertNil(ReferralSnapshot.fromCache(Data(#"{"code": 12, "count": "two"}"#.utf8)))
        XCTAssertNil(ReferralSnapshot(dictionary: [:]))
        XCTAssertNil(ReferralSnapshot(dictionary: ["code": 42]))
        XCTAssertNil(ReferralSnapshot(dictionary: ["code": "   "]))
    }

    func test_targetAndCountClamping() {
        XCTAssertEqual(ReferralSnapshot(code: "K7MQ2XPA", count: 3, target: 0, status: .active, reward: nil).effectiveTarget, 5)
        XCTAssertEqual(ReferralSnapshot(code: "K7MQ2XPA", count: 12, target: 5, status: .active, reward: nil).displayCount, 5)
        XCTAssertEqual(ReferralSnapshot(code: "K7MQ2XPA", count: -2, target: 5, status: .active, reward: nil).displayCount, 0)
        XCTAssertEqual(ReferralSnapshot(code: "K7MQ2XPA", count: 2, target: 3, status: .active, reward: nil).effectiveTarget, 3)
    }

    func test_rewardWithoutCodeIsNil() {
        var doc = fullDocument()
        doc["reward"] = ["expiresAt": expiry] as [String: Any]
        XCTAssertNil(ReferralSnapshot(dictionary: doc)?.reward)
    }
}
