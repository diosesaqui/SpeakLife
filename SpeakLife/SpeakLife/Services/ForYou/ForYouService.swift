//
//  ForYouService.swift
//  SpeakLife
//
//  Talks to the weekly For You functions (functions/weeklyForYou.js):
//  keeps the server's copy of the user's favorites current, and fetches the
//  set it writes every Sunday evening. Everything is a no-op while the
//  `weeklyForYouEnabled` Remote Config switch is off.
//

import CryptoKit
import Foundation
import SpeakLifeCore

enum ForYouError: Error { case network, server, disabled }

final class ForYouService {
    static let shared = ForYouService()

    static let flagKey = "weeklyForYouEnabled"

    private static let base = "https://us-central1-speaklife-3e5c4.cloudfunctions.net"
    private static let emulatorBase = "http://127.0.0.1:5001/speaklife-3e5c4/us-central1"

    private let session: URLSession
    private let defaults: UserDefaults
    private let flags: FeatureFlagProviding
    let log: ForYouFavoriteLog

    private let cacheKey = "forYouLatestSet"
    private let lastSyncKey = "forYouLastSyncSignature"
    private let lastSyncAtKey = "forYouLastSyncAt"
    /// Re-sent at least this often even when nothing changed, so the server's
    /// "opened the app recently" check and push token stay fresh.
    private let resyncInterval: TimeInterval = 24 * 3600

    private var latestFavorites: [Declaration] = []
    private var pendingSync: DispatchWorkItem?

    init(session: URLSession = .shared,
         defaults: UserDefaults = .standard,
         flags: FeatureFlagProviding = DefaultFeatureFlags.shared) {
        self.session = session
        self.defaults = defaults
        self.flags = flags
        self.log = ForYouFavoriteLog(defaults: defaults)
    }

    var isEnabled: Bool {
        flags.bool(Self.flagKey, default: false)
    }

    private func url(_ function: String) -> URL {
        URL(string: "\(BibleChatLocal.usesEmulator ? Self.emulatorBase : Self.base)/\(function)")!
    }

    // MARK: - Favorites

    /// Called on every favorite toggle, so the set can tell this week's
    /// favorites from older ones.
    func recordFavorite(_ text: String, isFavorite: Bool) {
        log.record(text, isFavorite: isFavorite)
    }

    /// Called whenever the favorites list changes. Debounced: a burst of taps
    /// is one request.
    func favoritesChanged(_ favorites: [Declaration]) {
        latestFavorites = favorites
        scheduleSync(after: 3)
    }

    /// Called when the app comes to the foreground.
    func appBecameActive() {
        scheduleSync(after: 1)
    }

    private func scheduleSync(after delay: TimeInterval) {
        pendingSync?.cancel()
        let work = DispatchWorkItem { [weak self] in
            Task { await self?.syncNow() }
        }
        pendingSync = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    func syncNow() async {
        guard isEnabled else { return }
        let appUserId = RevenueCatManager.shared.appUserID
        guard !appUserId.isEmpty else { return }

        let body = ForYouPayload.sync(
            appUserId: appUserId,
            favorites: latestFavorites,
            log: log,
            fcmToken: defaults.string(forKey: "fcmToken")
        )
        guard let data = try? JSONSerialization.data(withJSONObject: body, options: [.sortedKeys]) else { return }

        // Skip a request that would change nothing, unless it has been a day.
        // SHA-256 rather than hashValue, which is reseeded every launch.
        let signature = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        let lastAt = defaults.double(forKey: lastSyncAtKey)
        if defaults.string(forKey: lastSyncKey) == signature,
           Date().timeIntervalSince1970 - lastAt < resyncInterval {
            return
        }

        var request = URLRequest(url: url("syncForYouFavorites"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 20
        request.httpBody = data

        guard let (_, response) = try? await session.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200 else {
            AnalyticsService.shared.track("for_you_sync_failed")
            return
        }
        defaults.set(signature, forKey: lastSyncKey)
        defaults.set(Date().timeIntervalSince1970, forKey: lastSyncAtKey)
    }

    // MARK: - The set

    /// The newest set, from the server. Falls back to the last one seen when
    /// the network is down.
    func latestSet(isPremium: Bool) async throws -> ForYouResponse {
        guard isEnabled else { throw ForYouError.disabled }
        var request = URLRequest(url: url("getWeeklyForYou"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 20
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "appUserId": RevenueCatManager.shared.appUserID,
            "isPremiumClaim": isPremium,
        ])

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            if let cached = cachedSet() { return ForYouResponse(set: cached, isPremium: isPremium) }
            throw ForYouError.network
        }
        guard (response as? HTTPURLResponse)?.statusCode == 200,
              let decoded = try? JSONDecoder().decode(ForYouResponse.self, from: data) else {
            throw ForYouError.server
        }
        if decoded.disabled { throw ForYouError.disabled }
        if let set = decoded.set, let encoded = try? JSONEncoder().encode(set) {
            defaults.set(encoded, forKey: cacheKey)
        }
        return decoded
    }

    func cachedSet() -> ForYouSet? {
        guard let data = defaults.data(forKey: cacheKey) else { return nil }
        return try? JSONDecoder().decode(ForYouSet.self, from: data)
    }
}
