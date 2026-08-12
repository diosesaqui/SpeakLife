//
//  FeatureFlags.swift
//  SpeakLife
//
//  A single, injectable seam for boolean feature flags. Mirrors the
//  `AnalyticsProvider` shape in `Analytics/AnalyticsService.swift`: a small
//  protocol the domain reads, a static test double, and an app-installed
//  implementation registered at composition time.
//
//  This file is Foundation-only on purpose. The Firebase-backed
//  `RemoteConfigFlags` implementation lives in the app target (see
//  `AppDelegate`) and is installed into `DefaultFeatureFlags.shared` at
//  startup, so services that read flags do not import `FirebaseRemoteConfig`.
//

import Foundation

// MARK: - Provider

/// The domain-facing feature-flag API. Everything a service needs to consult a
/// flag goes through this — Firebase, static defaults, or an in-memory fake in
/// tests, all interchangeable.
protocol FeatureFlagProviding {
    func bool(_ key: String, default defaultValue: Bool) -> Bool
}

/// In-memory implementation, used by tests and as the pre-startup default.
///
/// Returning the supplied `defaultValue` when a key is absent matches
/// `RemoteConfig.setDefaults` semantics, so a service reading a flag before the
/// app has wired up Firebase falls back to the same value Firebase would
/// return.
struct StaticFeatureFlags: FeatureFlagProviding {
    private let values: [String: Bool]

    init(_ values: [String: Bool] = [:]) {
        self.values = values
    }

    func bool(_ key: String, default defaultValue: Bool) -> Bool {
        values[key] ?? defaultValue
    }
}

// MARK: - Late-bound holder

/// Swappable registry read by service defaults. The forwarding indirection
/// matters: `EnforcementService.shared` and `TakeItCaptiveService.shared` are
/// `static let` singletons, so their initializers capture whatever is set here
/// at first access. Forwarding through `provider` lets the app install the
/// Firebase-backed implementation any time before Firebase is first read,
/// even after the service instance is built.
final class DefaultFeatureFlags: FeatureFlagProviding {
    static let shared = DefaultFeatureFlags()

    /// Replaced at app startup with `RemoteConfigFlags()`. Falls back to
    /// `StaticFeatureFlags()` so a test host that never runs `AppDelegate` sees
    /// the same "flag absent, use the caller's default" behavior as production.
    var provider: FeatureFlagProviding = StaticFeatureFlags()

    private init() {}

    func bool(_ key: String, default defaultValue: Bool) -> Bool {
        provider.bool(key, default: defaultValue)
    }
}
