//
//  WeeklyFocusDevotionalService.swift
//  SpeakLife
//
//  The bucket devotional. Phase 3.
//
//  ONE devotional per `(needBucket, weekOfYear)`, shared by every user in that
//  bucket. `WeeklyFocus.devotionalKey` has been written on every record since
//  Phase 1 for exactly this — including on weeks that shipped before this file
//  existed, which is why turning the feature on does not need a migration.
//
//  Three layers of cache, cheapest first, because the goal is that opening the
//  week on Wednesday costs nothing at all:
//
//    1. in-memory      — same launch, same key, zero work.
//    2. UserDefaults   — same device, same week, no function invocation.
//    3. Firestore      — first user in the bucket that week pays for one
//                        generation; everybody after them reads it.
//
//  LAZY, NEVER SCHEDULED. Generating all ~20 buckets on a cron would mean
//  paying for the buckets nobody is in that week, and premium gating shrinks
//  the population each bucket amortizes over — so bucket count would start
//  driving cost again. Generated on demand it does not, which is what lets the
//  bucket count be tuned on whether the writing feels specific rather than on
//  the bill.
//
//  The one per-user touch is the framing line, and that is a local string
//  template quoting words the user already gave us. Not a generation, not a
//  request, not a cost.
//

import Foundation

// MARK: - The per-user layer
//
// Deliberately a local string template and nothing else. The devotional body
// is identical for everyone in the bucket, which is the entire cost model; the
// only thing that is theirs is the line quoting them, and quoting someone costs
// nothing. Free of the service (and of its main-actor isolation) so any view
// can read it.

extension WeeklyFocus {
    /// One line naming what was heard, shown above the bucket devotional.
    ///
    /// Prefers the model's framing line when the week has one, falls back to
    /// the user's verbatim answer, and returns nil for a week nobody answered
    /// rather than inventing a claim about what they said.
    var devotionalFraming: String? {
        if let line = framingLine?.trimmingCharacters(in: .whitespacesAndNewlines),
           !line.isEmpty {
            return line
        }
        guard let need = needText?.trimmingCharacters(in: .whitespacesAndNewlines),
              !need.isEmpty else { return nil }
        return "You said: \u{201C}\(need)\u{201D}"
    }
}

struct WeeklyFocusDevotional: Codable, Equatable {
    let devotionalKey: String
    let title: String
    let body: String
    let verseText: String
    let verseReference: String
    /// When this device cached it. The record is only good for its own week.
    let fetchedAt: Date

    var hasVerse: Bool { !verseText.isEmpty && !verseReference.isEmpty }
}

/// `@MainActor` for the memo, not for the UI: `memo` and `failed` are mutable
/// state touched from an async method, and the only caller is a main-actor view
/// model. Pinning it removes the race outright instead of documenting one.
@MainActor
final class WeeklyFocusDevotionalService {

    /// Keyed by `devotionalKey`, so a key from a previous week never resolves.
    private static let cacheKeyPrefix = "weekly_focus_devotional_"

    private let session: URLSession
    private let defaults: UserDefaults

    /// Per-launch memo. `WeekOverviewView` is a struct SwiftUI rebuilds freely,
    /// so without this a scroll could fire a request per frame.
    private var memo: [String: WeeklyFocusDevotional] = [:]
    /// Keys already tried and failed this launch. One failed fetch should not
    /// become a retry loop behind a view that redraws.
    private var failed: Set<String> = []

    init(session: URLSession = .shared, defaults: UserDefaults = .standard) {
        self.session = session
        self.defaults = defaults
    }

    private static let cloudEndpoint = URL(string: "https://us-central1-speaklife-3e5c4.cloudfunctions.net/weeklyFocusDevotional")!
    private static let emulatorEndpoint = URL(string: "http://127.0.0.1:5001/speaklife-3e5c4/us-central1/weeklyFocusDevotional")!

    private var endpoint: URL {
        BibleChatLocal.usesEmulator ? Self.emulatorEndpoint : Self.cloudEndpoint
    }

    // MARK: - Fetch

    /// This week's devotional for the focus's bucket, or nil.
    ///
    /// Contract: never throws and never surfaces an error. A devotional is a
    /// bonus on top of a week that is already complete without it, so every
    /// failure path — flag off, free tier, offline, rate limited, malformed —
    /// returns nil and the overview simply does not show the section.
    func devotional(for focus: WeeklyFocus) async -> WeeklyFocusDevotional? {
        // Kill switch, defaulted off. Off, this returns nil before doing
        // anything at all, and the overview omits the section.
        guard defaults.bool(forKey: WeeklyFocusFlags.devotionals) else { return nil }

        let key = focus.devotionalKey
        if let memoized = memo[key] { return memoized }
        if failed.contains(key) { return nil }
        if let stored = cached(key: key) {
            memo[key] = stored
            return stored
        }

        let appUserId = RevenueCatManager.shared.appUserID
        guard !appUserId.isEmpty else { return nil }

        guard let fetched = await fetch(
            key: key,
            needBucket: focus.needBucket,
            weekOfYear: focus.weekOfYear,
            appUserId: appUserId
        ) else {
            failed.insert(key)
            return nil
        }

        memo[key] = fetched
        store(fetched)
        return fetched
    }

    // MARK: - Local cache

    private func cached(key: String) -> WeeklyFocusDevotional? {
        guard let data = defaults.data(forKey: Self.cacheKeyPrefix + key),
              let decoded = try? JSONDecoder().decode(WeeklyFocusDevotional.self, from: data)
        else { return nil }
        return decoded
    }

    private func store(_ devotional: WeeklyFocusDevotional) {
        guard let data = try? JSONEncoder().encode(devotional) else { return }
        defaults.set(data, forKey: Self.cacheKeyPrefix + devotional.devotionalKey)
        pruneOldCaches(keeping: devotional.devotionalKey)
    }

    /// The key carries the week number, so a stale entry can never be served —
    /// but it would sit in UserDefaults forever. Sweep the others whenever a
    /// new one lands; at one small record per week this is housekeeping, not a
    /// correctness requirement.
    private func pruneOldCaches(keeping key: String) {
        let keep = Self.cacheKeyPrefix + key
        for name in defaults.dictionaryRepresentation().keys
        where name.hasPrefix(Self.cacheKeyPrefix) && name != keep {
            defaults.removeObject(forKey: name)
        }
    }

    // MARK: - Network

    private struct RemoteDevotional: Decodable {
        let needsPaywall: Bool?
        let devotionalKey: String?
        let title: String?
        let body: String?
        let verseText: String?
        let verseReference: String?
    }

    private func fetch(key: String,
                       needBucket: String,
                       weekOfYear: Int,
                       appUserId: String) async -> WeeklyFocusDevotional? {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 45   // a cache MISS pays for a generation

        // A hint only — the function re-checks with RevenueCat server-side.
        let premiumClaim = await RevenueCatManager.shared.isPremiumActiveNow()
        let payload: [String: Any] = [
            "appUserId": appUserId,
            "isPremiumClaim": premiumClaim,
            "needBucket": needBucket,
            "weekOfYear": weekOfYear
        ]
        guard let httpBody = try? JSONSerialization.data(withJSONObject: payload) else { return nil }
        request.httpBody = httpBody

        guard let (data, response) = try? await session.data(for: request),
              let http = response as? HTTPURLResponse else { return nil }

        guard http.statusCode == 200 else {
            AnalyticsService.shared.track("weekly_focus_devotional_error", parameters: [
                "status": http.statusCode
            ])
            return nil
        }

        guard let decoded = try? JSONDecoder().decode(RemoteDevotional.self, from: data),
              decoded.needsPaywall != true,
              let title = decoded.title, !title.isEmpty,
              let body = decoded.body, !body.isEmpty else { return nil }

        AnalyticsService.shared.track("weekly_focus_devotional_served", parameters: [
            "need_bucket": needBucket
        ])

        return WeeklyFocusDevotional(
            devotionalKey: decoded.devotionalKey ?? key,
            title: title,
            body: body,
            verseText: decoded.verseText ?? "",
            verseReference: decoded.verseReference ?? "",
            fetchedAt: Date()
        )
    }
}
