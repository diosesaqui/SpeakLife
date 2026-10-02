//
//  FirebaseReferralService.swift
//  SpeakLife
//
//  The only Firebase-aware layer of the referral feature. Everything above it
//  works in `ReferralSnapshot` and `ReferralClaimOutcome` (SpeakLifeCore,
//  Foundation only); everything below it is functions/referral.js.
//
//  Shaped like `StandService` and `StandPassStore`: callables for every change,
//  and a read-only snapshot listener on the one document the client may read,
//  `referrals/{uid}` (owner only, spec §6).
//

import Foundation
import FirebaseFirestore
import FirebaseFunctions
import SpeakLifeCore

@MainActor
final class FirebaseReferralService: ReferralServicing {

    static let shared = FirebaseReferralService()

    private lazy var functions = Functions.functions()
    private let db = Firestore.firestore()

    private init() {}

    // MARK: - Callables

    func getOrCreate(deviceToken: String?, isDevelopment: Bool) async throws -> ReferralSnapshot {
        var payload: [String: Any] = ["isDevelopment": isDevelopment]
        if let deviceToken { payload["deviceToken"] = deviceToken }
        let result = try await call("getOrCreateReferral", payload)
        guard let snapshot = ReferralSnapshot(dictionary: ReferralDateBridge.normalize(result)) else {
            throw ReferralServiceError.malformedResponse
        }
        return snapshot
    }

    func claim(_ request: ReferralClaimRequest) async throws -> ReferralClaimOutcome {
        let result = try await call("claimReferral", request.payload)
        return Self.outcome(from: result)
    }

    func reissue() async throws -> ReferralReward {
        let result = try await call("reissueReferralReward", [:])
        guard let reward = Self.reward(from: result["reward"]) else {
            throw ReferralServiceError.malformedResponse
        }
        return reward
    }

    // MARK: - Listener

    func observe(uid: String, onChange: @escaping @MainActor (ReferralSnapshot?) -> Void) -> ReferralObservation {
        let registration = db.collection("referrals").document(uid)
            .addSnapshotListener { snap, error in
                // An error (rules, offline with nothing cached) says nothing
                // about the record. Leave the page on whatever it already shows
                // rather than flashing "not enrolled" at somebody at 4 of 5.
                if error != nil { return }
                let snapshot: ReferralSnapshot?
                if let data = snap?.data() {
                    snapshot = ReferralSnapshot(dictionary: ReferralDateBridge.normalize(data))
                } else {
                    snapshot = nil
                }
                Task { @MainActor in onChange(snapshot) }
            }
        return FirestoreReferralObservation(registration)
    }

    // MARK: - Decoding

    /// `{ outcome, reason? }`. An outcome string this build does not know is
    /// kept, not dropped: a newer server must never cost us a real friend
    /// (FE-CLM-11), so the policy treats `.unknown` as "keep and retry".
    static func outcome(from result: [String: Any]) -> ReferralClaimOutcome {
        ReferralClaimOutcome.parse(outcome: result["outcome"] as? String,
                                   reason: result["reason"] as? String)
    }

    /// Decoded by Core's parser, after Firebase's date shapes are converted.
    static func reward(from raw: Any?) -> ReferralReward? {
        guard let dict = raw as? [String: Any] else { return nil }
        return ReferralReward(dictionary: ReferralDateBridge.normalize(dict))
    }

    // MARK: - Calling

    private func call(_ name: String, _ payload: [String: Any]) async throws -> [String: Any] {
        do {
            let result = try await functions.httpsCallable(name).call(payload)
            return result.data as? [String: Any] ?? [:]
        } catch let error as NSError {
            throw Self.map(error)
        }
    }

    /// Callable error codes → what the app does about them. The codes are the
    /// ones functions/referral.js throws (spec §8, BE TDD).
    static func map(_ error: NSError) -> ReferralServiceError {
        if error.domain == NSURLErrorDomain { return .unavailable }
        guard error.domain == FunctionsErrorDomain,
              let code = FunctionsErrorCode(rawValue: error.code) else {
            return .other(error.domain)
        }
        switch code {
        case .failedPrecondition: return .serverDisabled
        case .resourceExhausted:  return .exhausted
        case .unauthenticated:    return .unauthenticated
        case .unavailable, .deadlineExceeded, .internal: return .unavailable
        default:                  return .other("functions_\(code.rawValue)")
        }
    }
}

// MARK: - Listener handle

@MainActor
private final class FirestoreReferralObservation: ReferralObservation {
    private var registration: ListenerRegistration?

    init(_ registration: ListenerRegistration) {
        self.registration = registration
    }

    func cancel() {
        registration?.remove()
        registration = nil
    }
}

// MARK: - Date bridge

/// SpeakLifeCore cannot name `Timestamp`, and `ReferralSnapshot(dictionary:)`
/// takes `Date`s. This is the one place Firebase's date shapes are known.
///
/// Dates reach the client in three shapes, depending on the path:
///  - Firestore listener: `Timestamp`.
///  - Callable result: a Timestamp serialised as `{_seconds, _nanoseconds}`,
///    or whatever the function chose to send (milliseconds, ISO 8601).
///  - Cache: already a `Date` (the snapshot round-trips through Codable).
enum ReferralDateBridge {

    /// Keys that hold a point in time anywhere in the record.
    static let dateKeys: Set<String> = [
        "expiresAt", "assignedAt", "createdAt", "updatedAt", "unlockedAt",
    ]

    static func normalize(_ dict: [String: Any]) -> [String: Any] {
        var out: [String: Any] = [:]
        for (key, value) in dict {
            if dateKeys.contains(key) {
                if let date = date(from: value) { out[key] = date }
                // An unreadable date is dropped rather than passed through: a
                // dictionary where a Date was expected must not fail the whole
                // snapshot decode over a field the page barely uses.
                continue
            }
            if let nested = value as? [String: Any] {
                out[key] = normalize(nested)
            } else {
                out[key] = value
            }
        }
        return out
    }

    static func date(from value: Any?) -> Date? {
        guard let value else { return nil }
        switch value {
        case let date as Date:
            return date
        case let ts as Timestamp:
            return ts.dateValue()
        case let dict as [String: Any]:
            // A Timestamp that crossed the callable boundary.
            let seconds = (dict["_seconds"] as? NSNumber) ?? (dict["seconds"] as? NSNumber)
            guard let seconds else { return nil }
            let nanos = (dict["_nanoseconds"] as? NSNumber) ?? (dict["nanoseconds"] as? NSNumber)
            return Date(timeIntervalSince1970: seconds.doubleValue + (nanos?.doubleValue ?? 0) / 1_000_000_000)
        case let number as NSNumber:
            // Milliseconds, matching `capturedAt` on the way out.
            return Date(timeIntervalSince1970: number.doubleValue / 1000)
        case let text as String:
            return ISO8601DateFormatter().date(from: text)
        default:
            return nil
        }
    }
}
