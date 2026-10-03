//
//  PendingReferral.swift
//  SpeakLifeCore
//
//  The friend side of the referral (spec J4, J5, §9.5): a code captured from a
//  link or typed in, held until onboarding finishes and the claim is sent.
//
//  Rules this file owns:
//   - First capture wins. A later link never overwrites a pending one, and a
//     second capture of the SAME code does not refresh `capturedAt`, so the
//     14-day window cannot be stretched.
//   - Once a claim is final (credited, or rejected for good), nothing is ever
//     captured again on this install.
//   - Expired or unreadable stored data reads as "nothing pending" and is
//     cleared. It never crashes and never blocks a fresh capture.
//
//  Storage goes through `ReferralKeyValueStore` so tests use an in-memory
//  store and a controllable clock. The app supplies a UserDefaults conformer.
//

import Foundation

// MARK: - Storage seam

public protocol ReferralKeyValueStore: AnyObject {
    func data(forKey key: String) -> Data?
    /// `nil` removes the value.
    func set(_ data: Data?, forKey key: String)
    func bool(forKey key: String) -> Bool
    func set(_ value: Bool, forKey key: String)
}

/// The test double, and a safe default before the app wires up UserDefaults.
public final class InMemoryReferralKeyValueStore: ReferralKeyValueStore {
    private var datas: [String: Data] = [:]
    private var bools: [String: Bool] = [:]

    public init() {}

    public func data(forKey key: String) -> Data? {
        datas[key]
    }

    public func set(_ data: Data?, forKey key: String) {
        if let data = data {
            datas[key] = data
        } else {
            datas.removeValue(forKey: key)
        }
    }

    public func bool(forKey key: String) -> Bool {
        bools[key] ?? false
    }

    public func set(_ value: Bool, forKey key: String) {
        bools[key] = value
    }
}

// MARK: - Model

public struct PendingReferral: Codable, Equatable, Sendable {
    public let code: String
    public let capturedAt: Date
    public let source: ReferralSource
    /// Claim attempts so far. Sent as `attempt` in `referral_claim_result`.
    public var attempts: Int
    public var lastAttemptAt: Date?
    /// When onboarding finished, stamped once by `markOnboarded()`. Sent with
    /// the claim: the window (D8) is capture-to-onboarding, and the claim then
    /// has `graceDays` to reach the server. Optional so values saved by an
    /// earlier build still decode.
    public var onboardedAt: Date?

    public init(code: String,
                capturedAt: Date,
                source: ReferralSource,
                attempts: Int = 0,
                lastAttemptAt: Date? = nil,
                onboardedAt: Date? = nil) {
        self.code = code
        self.capturedAt = capturedAt
        self.source = source
        self.attempts = attempts
        self.lastAttemptAt = lastAttemptAt
        self.onboardedAt = onboardedAt
    }

    /// Before onboarding: past `capturedAt` plus the window. After: onboarding
    /// finished outside the window, or the claim grace has run out. Exactly at
    /// a boundary is still inside (FE-PND-05). Mirrors `validateWindow` in
    /// functions/referral.js, so the app never drops a claim the server would
    /// still credit.
    public func isExpired(now: Date, windowDays: Int, graceDays: Int = PendingReferralStore.defaultGraceDays) -> Bool {
        let window = TimeInterval(windowDays) * 86_400
        guard let onboardedAt = onboardedAt else {
            return now.timeIntervalSince(capturedAt) > window
        }
        if onboardedAt.timeIntervalSince(capturedAt) > window { return true }
        return now.timeIntervalSince(onboardedAt) > TimeInterval(graceDays) * 86_400
    }
}

public enum ReferralCaptureResult: Equatable {
    case captured
    case alreadyPending
    case alreadyClaimed
    case invalid
}

// MARK: - Store

public final class PendingReferralStore {

    /// UserDefaults key named in spec §9.5.
    public static let pendingKey = "pendingReferral"
    /// Set once a claim is final. Stops every future capture on this install.
    public static let finalKey = "referralClaimFinal"

    /// Matches `claimGraceDays` in functions/referral.js.
    public static let defaultGraceDays = 30

    public let windowDays: Int
    public let graceDays: Int
    private let store: ReferralKeyValueStore
    private let now: () -> Date

    public init(store: ReferralKeyValueStore,
                windowDays: Int = 14,
                graceDays: Int = PendingReferralStore.defaultGraceDays,
                now: @escaping () -> Date = { Date() }) {
        self.store = store
        self.windowDays = windowDays
        self.graceDays = graceDays
        self.now = now
    }

    /// The pending referral, or nil. Reading an expired, final-blocked or
    /// corrupt value clears it.
    public var pending: PendingReferral? {
        guard let data = store.data(forKey: Self.pendingKey) else { return nil }
        if isFinal {
            clear()
            return nil
        }
        guard let decoded = try? JSONDecoder().decode(PendingReferral.self, from: data),
              ReferralLink.normalize(decoded.code) == decoded.code,
              decoded.attempts >= 0 else {
            clear()
            return nil
        }
        if decoded.isExpired(now: now(), windowDays: windowDays, graceDays: graceDays) {
            clear()
            return nil
        }
        return decoded
    }

    /// True once a claim has been credited or rejected for good.
    public var isFinal: Bool {
        store.bool(forKey: Self.finalKey)
    }

    @discardableResult
    public func capture(code: String, source: ReferralSource) -> ReferralCaptureResult {
        if isFinal { return .alreadyClaimed }
        guard let normalized = ReferralLink.normalize(code) else { return .invalid }
        if pending != nil { return .alreadyPending }
        save(PendingReferral(code: normalized, capturedAt: now(), source: source))
        return .captured
    }

    /// Counts one claim attempt and stamps its time. Persisted, so the retry
    /// throttle and the `attempt` analytics survive a relaunch.
    public func recordAttempt() {
        guard var current = pending else { return }
        current.attempts += 1
        current.lastAttemptAt = now()
        save(current)
    }

    /// Stamps when onboarding finished. Once only: a later foreground retry
    /// must not move it.
    public func markOnboarded() {
        guard var current = pending, current.onboardedAt == nil else { return }
        current.onboardedAt = now()
        save(current)
    }

    /// The claim is settled. Clears the pending value and blocks future capture.
    public func markFinal() {
        store.set(nil, forKey: Self.pendingKey)
        store.set(true, forKey: Self.finalKey)
    }

    /// Drops the pending value. Does NOT set the final flag, so a later link
    /// can still be captured.
    public func clear() {
        store.set(nil, forKey: Self.pendingKey)
    }

    private func save(_ value: PendingReferral) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        store.set(data, forKey: Self.pendingKey)
    }
}
