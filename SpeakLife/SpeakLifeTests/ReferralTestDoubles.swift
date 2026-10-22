//
//  ReferralTestDoubles.swift
//  SpeakLifeTests
//
//  Fakes for the referral app layer (docs/REFERRAL_FE_TDD.md §8). Every seam
//  `ReferralViewModel` and `ReferralClaimCoordinator` touch has one here, so
//  neither test file needs Firebase, DeviceCheck, StoreKit or UIKit presentation.
//

import XCTest
import UIKit
@testable import SpeakLife

/// The order calls happened in, across fakes. FE-VM-01 and FE-VM-11 are about
/// ORDER (account before callable), which no single fake can see.
final class ReferralCallLog {
    var entries: [String] = []
}

@MainActor
final class FakeReferralService: ReferralServicing {

    let log: ReferralCallLog

    var getOrCreateResult: Result<ReferralSnapshot, Error> = .success(
        ReferralSnapshot(code: "K7MQ2XPA", count: 0, target: 5, status: .active, reward: nil))
    private(set) var getOrCreateTokens: [String?] = []

    var claimResult: Result<ReferralClaimOutcome, Error> = .success(.credited)
    private(set) var claimRequests: [ReferralClaimRequest] = []

    var reissueResult: Result<ReferralReward, Error> = .success(
        ReferralReward(code: "NEWCODE12345", expiresAt: nil, reissueCount: 1))
    private(set) var reissueCalls = 0

    private(set) var observedUids: [String] = []
    private(set) var observer: (@MainActor (ReferralSnapshot?) -> Void)?

    init(log: ReferralCallLog = ReferralCallLog()) {
        self.log = log
    }

    func getOrCreate(deviceToken: String?, isDevelopment: Bool) async throws -> ReferralSnapshot {
        log.entries.append("getOrCreate")
        getOrCreateTokens.append(deviceToken)
        return try getOrCreateResult.get()
    }

    func claim(_ request: ReferralClaimRequest) async throws -> ReferralClaimOutcome {
        log.entries.append("claim")
        claimRequests.append(request)
        return try claimResult.get()
    }

    func reissue() async throws -> ReferralReward {
        log.entries.append("reissue")
        reissueCalls += 1
        return try reissueResult.get()
    }

    func observe(uid: String, onChange: @escaping @MainActor (ReferralSnapshot?) -> Void) -> ReferralObservation {
        observedUids.append(uid)
        observer = onChange
        return FakeReferralObservation()
    }

    /// Delivers a server snapshot, as the Firestore listener would.
    func push(_ snapshot: ReferralSnapshot?) {
        observer?(snapshot)
    }
}

@MainActor
final class FakeReferralObservation: ReferralObservation {
    private(set) var cancelled = false
    func cancel() { cancelled = true }
}

@MainActor
final class FakeReferralAccount: ReferralAccountProviding {
    let log: ReferralCallLog
    var currentUid: String?
    var error: Error?
    private(set) var ensureCount = 0

    init(log: ReferralCallLog = ReferralCallLog(), uid: String? = nil) {
        self.log = log
        self.currentUid = uid
    }

    @discardableResult
    func ensureAccount() async throws -> String {
        log.entries.append("ensureAccount")
        ensureCount += 1
        if let error { throw error }
        let uid = currentUid ?? "uid-friend-0001"
        currentUid = uid
        return uid
    }
}

@MainActor
final class FakeDeviceTokenProvider: DeviceTokenProviding {
    var tokenValue: String? = "device-token"
    var isDevelopment = true
    func token() async -> String? { tokenValue }
}

final class SpyAnalytics: AnalyticsTracking {
    private(set) var events: [(name: String, parameters: [String: Any])] = []

    func track(_ event: String, parameters: [String: Any]) {
        events.append((event, parameters))
    }

    func events(named name: String) -> [[String: Any]] {
        events.filter { $0.name == name }.map { $0.parameters }
    }

    func last(_ name: String) -> [String: Any]? {
        events(named: name).last
    }
}

@MainActor
final class FakeURLOpener: ReferralURLOpening {
    var result = true
    private(set) var opened: [URL] = []
    func open(_ url: URL) async -> Bool {
        opened.append(url)
        return result
    }
}

@MainActor
final class FakePasteboard: ReferralPasteboard {
    private(set) var copied: [String] = []
    func copy(_ string: String) { copied.append(string) }
}

@MainActor
struct StubShareCardRenderer: ReferralShareCardRendering {
    func render(formattedCode: String) -> UIImage? {
        UIGraphicsImageRenderer(size: CGSize(width: 2, height: 2)).image { _ in }
    }
}

struct FakeServiceError: Error {}

// MARK: - Fixtures

enum ReferralFixtures {
    static let code = "K7MQ2XPA"
    static let rewardCode = "ABCD1234EFGH"
    static let fixedNow = Date(timeIntervalSince1970: 1_790_000_000)

    static func active(count: Int = 0, target: Int = 5) -> ReferralSnapshot {
        ReferralSnapshot(code: code, count: count, target: target, status: .active, reward: nil)
    }

    static func unlocked() -> ReferralSnapshot {
        ReferralSnapshot(code: code, count: 5, target: 5, status: .unlocked,
                         reward: ReferralReward(code: rewardCode, expiresAt: nil, reissueCount: 0))
    }
}

extension XCTestCase {

    /// Lets the view model's `Task`s run. Polls rather than sleeping a fixed
    /// time, so a fast machine is not slowed and a slow one does not flake.
    @MainActor
    func waitUntil(timeout: TimeInterval = 2,
                   file: StaticString = #filePath, line: UInt = #line,
                   _ condition: @MainActor () -> Bool) async {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() {
            if Date() > deadline {
                XCTFail("Timed out waiting for condition", file: file, line: line)
                return
            }
            try? await Task.sleep(nanoseconds: 5_000_000)
        }
    }
}
