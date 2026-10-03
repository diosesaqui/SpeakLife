//
//  ReferralSnapshot.swift
//  SpeakLifeCore
//
//  The referrer's record as the client sees it (spec §6 `referrals/{uid}`,
//  §8.1 response), and the copy cached in UserDefaults so the page opens
//  instantly and offline (§9.3).
//
//  Display only. The server decides count, target and status; this type only
//  reads them, and reads them leniently: an unknown status shows as progress,
//  a missing target means the server default, and a count past the target
//  never draws an overfull bar.
//
//  Foundation only. Firestore `Timestamp`s are converted to `Date` by the app
//  before `init?(dictionary:)` sees them.
//

import Foundation

public enum ReferralStatus: String, Codable, Sendable {
    case active
    case unlocked
    case unlockedPendingCode = "unlocked_pending_code"

    /// Unknown or missing status reads as `.active`: keep showing progress.
    public init(lenient raw: String?) {
        self = ReferralStatus(rawValue: raw ?? "") ?? .active
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        self = ReferralStatus(lenient: raw)
    }
}

public struct ReferralReward: Codable, Equatable, Sendable {
    /// The App Store offer code. Never sent to analytics.
    public let code: String
    public let expiresAt: Date?
    public let reissueCount: Int

    public init(code: String, expiresAt: Date?, reissueCount: Int) {
        self.code = code
        self.expiresAt = expiresAt
        self.reissueCount = reissueCount
    }

    /// Lenient read of the `reward` map. Nil when there is no usable code.
    public init?(dictionary: [String: Any]) {
        guard let rawCode = dictionary["code"] as? String else { return nil }
        let code = rawCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !code.isEmpty else { return nil }
        self.code = code
        self.expiresAt = ReferralValueReader.date(dictionary["expiresAt"])
        self.reissueCount = max(0, ReferralValueReader.int(dictionary["reissueCount"]) ?? 0)
    }
}

public struct ReferralSnapshot: Codable, Equatable, Sendable {

    /// Matches the server's built-in default (spec §6 `referralConfig`, D3).
    public static let defaultTarget = 5

    /// UserDefaults key for the cached copy.
    public static let cacheKey = "referralSnapshotCache"

    public let code: String
    public let count: Int
    public let target: Int
    public let status: ReferralStatus
    public let reward: ReferralReward?

    public init(code: String, count: Int, target: Int, status: ReferralStatus, reward: ReferralReward?) {
        self.code = code
        self.count = count
        self.target = target
        self.status = status
        self.reward = reward
    }

    /// Reads the server record (or the callable's response). Unknown fields are
    /// ignored. Nil only when there is no code to show.
    public init?(dictionary: [String: Any]) {
        guard let rawCode = dictionary["code"] as? String else { return nil }
        let trimmed = rawCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        self.code = ReferralLink.normalize(trimmed) ?? trimmed
        self.count = ReferralValueReader.int(dictionary["count"]) ?? 0
        self.target = ReferralValueReader.int(dictionary["target"]) ?? 0
        self.status = ReferralStatus(lenient: dictionary["status"] as? String)
        if let rewardMap = dictionary["reward"] as? [String: Any] {
            self.reward = ReferralReward(dictionary: rewardMap)
        } else {
            self.reward = nil
        }
    }

    /// The target to draw against. A missing or zero target means the server
    /// default, never a divide by zero (FE-PAG-18).
    public var effectiveTarget: Int {
        target > 0 ? target : Self.defaultTarget
    }

    /// The count to draw, clamped into 0...effectiveTarget (FE-PAG-17).
    public var displayCount: Int {
        max(0, min(count, effectiveTarget))
    }

    // MARK: Cache

    /// Bytes for the UserDefaults cache.
    public func cacheData() -> Data? {
        try? JSONEncoder().encode(self)
    }

    /// Reads the cache. Nil for missing or corrupt bytes, never a crash.
    public static func fromCache(_ data: Data?) -> ReferralSnapshot? {
        guard let data = data else { return nil }
        return try? JSONDecoder().decode(ReferralSnapshot.self, from: data)
    }
}

// MARK: - Lenient value reading

/// Firestore numbers arrive as NSNumber (Int64 underneath); tests pass Swift
/// Ints. Dates arrive as `Date` once the app has converted Timestamps, or as
/// seconds since 1970 from a JSON response.
enum ReferralValueReader {

    static func int(_ value: Any?) -> Int? {
        guard let value = value else { return nil }
        if let i = value as? Int { return i }
        if let i = value as? Int64 { return Int(clamping: i) }
        if let i = value as? Int32 { return Int(i) }
        if let d = value as? Double {
            guard d.isFinite, abs(d) < 1e15 else { return nil }
            return Int(d)
        }
        if let n = value as? NSNumber {
            let d = n.doubleValue
            guard d.isFinite, abs(d) < 1e15 else { return nil }
            return Int(d)
        }
        return nil
    }

    static func date(_ value: Any?) -> Date? {
        guard let value = value else { return nil }
        if let date = value as? Date { return date }
        if let seconds = value as? Double, seconds.isFinite {
            return Date(timeIntervalSince1970: seconds)
        }
        if let seconds = value as? Int {
            return Date(timeIntervalSince1970: TimeInterval(seconds))
        }
        if let n = value as? NSNumber {
            let seconds = n.doubleValue
            guard seconds.isFinite else { return nil }
            return Date(timeIntervalSince1970: seconds)
        }
        return nil
    }
}
