//
//  AnalyticsContext.swift
//  SpeakLife
//
//  The one place that decides what rides along on EVERY analytics event.
//
//  `AnalyticsService.dispatch` merges `AnalyticsContext.shared.properties()`
//  into every event before it fans out to Firebase / PostHog / TikTok / Meta.
//  Add a key here once and it lands on every event in every destination with
//  zero call-site changes.
//
//  Collision rule: the call site always wins. If an event passes its own
//  `subscription_status`, that value is kept and the global one is discarded.
//

import Foundation

/// Monetization state of the person generating the event.
enum AnalyticsSubscriptionStatus: String {
    case free
    case trial
    case premium
}

final class AnalyticsContext {

    static let shared = AnalyticsContext()

    /// Property names, referenced instead of string literals so a rename is a
    /// compile error rather than a silently split funnel.
    enum Key {
        static let appVersion = "app_version"
        static let appBuild = "app_build"
        static let sessionId = "session_id"
        static let subscriptionStatus = "subscription_status"
        static let daysSinceInstall = "days_since_install"
        static let timestamp = "timestamp"
    }

    // MARK: - Launch-constant properties

    /// Marketing version, e.g. "4.54". The critical one: without it a spike in
    /// errors or a drop in conversion cannot be pinned to the release that
    /// shipped it, and old-build traffic silently pollutes every funnel.
    let appVersion: String

    /// Build number, e.g. "1001". Separates TestFlight/internal builds that
    /// share a marketing version — which is where regressions are caught first.
    let appBuild: String

    /// One id per app launch, shared by every destination. Firebase and PostHog
    /// each keep their own private session notion; this is the id that lets a
    /// single session be reconstructed across all of them.
    let sessionId: String

    // MARK: - Mutable state

    private let installDate: Date
    private let lock = NSLock()
    private var subscriptionStatus: AnalyticsSubscriptionStatus = .free

    // `days_since_install` only changes at midnight, so it is cached rather
    // than recomputed through Calendar on every single event.
    private var cachedDaysSinceInstall: Int = 0
    private var daysComputedAt: Date = .distantPast

    private init(bundle: Bundle = .main, defaults: UserDefaults = .standard) {
        appVersion = bundle.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        appBuild = bundle.infoDictionary?["CFBundleVersion"] as? String ?? "unknown"
        sessionId = UUID().uuidString
        installDate = AnalyticsContext.resolveInstallDate(defaults)
    }

    // MARK: - Reading

    /// Global properties merged into every dispatched event.
    func properties() -> [String: Any] {
        let now = Date()

        lock.lock()
        let status = subscriptionStatus
        let days = daysSinceInstallLocked(now: now)
        lock.unlock()

        return [
            Key.appVersion: appVersion,
            Key.appBuild: appBuild,
            Key.sessionId: sessionId,
            Key.subscriptionStatus: status.rawValue,
            Key.daysSinceInstall: days,
            Key.timestamp: now.analyticsISO8601String
        ]
    }

    var currentSubscriptionStatus: AnalyticsSubscriptionStatus {
        lock.lock()
        defer { lock.unlock() }
        return subscriptionStatus
    }

    /// When this person first opened the app. The cohort anchor for retention,
    /// activation and payback-window questions — every "how long did it take
    /// them to X" is measured from here.
    var userInstallDate: Date { installDate }

    /// Whole days since install. Same cached value the event context uses, so a
    /// milestone event and the events around it can never disagree by a day.
    var daysSinceInstall: Int {
        let now = Date()
        lock.lock()
        defer { lock.unlock() }
        return daysSinceInstallLocked(now: now)
    }

    var hoursSinceInstall: Int {
        max(0, Int(Date().timeIntervalSince(installDate) / 3600))
    }

    // MARK: - Writing

    /// Keep the monetization dimension current. Wired to `SubscriptionStore`,
    /// which is the source of truth, so every subsequent event is segmented by
    /// free / trial / premium without any call site passing it.
    ///
    /// Returns silently when nothing changed, so this is cheap to call often.
    func updateSubscription(isPremium: Bool, isInTrial: Bool) {
        let status: AnalyticsSubscriptionStatus = isInTrial ? .trial : (isPremium ? .premium : .free)

        lock.lock()
        let changed = subscriptionStatus != status
        subscriptionStatus = status
        lock.unlock()

        guard changed else { return }

        // Mirror onto the person so cohorts ("everyone who is on trial") work
        // in PostHog / Firebase, not just event-level filtering.
        AnalyticsService.shared.setUserProperty(Key.subscriptionStatus, value: status.rawValue)
    }

    // MARK: - Helpers

    /// Caller must hold `lock`.
    private func daysSinceInstallLocked(now: Date) -> Int {
        guard now.timeIntervalSince(daysComputedAt) >= 60 else { return cachedDaysSinceInstall }

        let days = Calendar.current.dateComponents([.day], from: installDate, to: now).day ?? 0
        cachedDaysSinceInstall = max(0, days)
        daysComputedAt = now
        return cachedDaysSinceInstall
    }

    private static let installDateKey = "analytics_install_date"

    private static func resolveInstallDate(_ defaults: UserDefaults) -> Date {
        if let stored = defaults.object(forKey: installDateKey) as? Date {
            return stored
        }

        // Backfill from keys earlier builds already wrote so the existing user
        // base doesn't all read as day 0 the moment this ships.
        let backfilled: Date
        if let lifecycle = defaults.object(forKey: "lifecycle_install_date") as? Date {
            backfilled = lifecycle
        } else if let firstLaunch = defaults.object(forKey: "firstLaunchDate") as? Double, firstLaunch > 0 {
            backfilled = Date(timeIntervalSince1970: firstLaunch)
        } else {
            backfilled = Date()
        }

        defaults.set(backfilled, forKey: installDateKey)
        return backfilled
    }
}

extension Date {
    var analyticsISO8601String: String {
        ISO8601DateFormatter().string(from: self)
    }
}
