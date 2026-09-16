//
//  FeatureFlags.swift
//  SpeakLifeCore
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
public protocol FeatureFlagProviding {
    func bool(_ key: String, default defaultValue: Bool) -> Bool
    /// Remotely-set text. Added for the stand invite domain, which has to be
    /// changeable without a build: the link host is the one part of this
    /// feature that older, already-shipped builds can silently swallow.
    func string(_ key: String, default defaultValue: String) -> String
}

public extension FeatureFlagProviding {
    /// Defaulted so existing conformers — including test doubles — compile
    /// unchanged and simply report "no remote value".
    func string(_ key: String, default defaultValue: String) -> String { defaultValue }
}

/// In-memory implementation, used by tests and as the pre-startup default.
///
/// Returning the supplied `defaultValue` when a key is absent matches
/// `RemoteConfig.setDefaults` semantics, so a service reading a flag before the
/// app has wired up Firebase falls back to the same value Firebase would
/// return.
public struct StaticFeatureFlags: FeatureFlagProviding {
    private let values: [String: Bool]
    private let strings: [String: String]

    public init(_ values: [String: Bool] = [:], strings: [String: String] = [:]) {
        self.values = values
        self.strings = strings
    }

    public func bool(_ key: String, default defaultValue: Bool) -> Bool {
        values[key] ?? defaultValue
    }

    public func string(_ key: String, default defaultValue: String) -> String {
        strings[key] ?? defaultValue
    }
}

// MARK: - Late-bound holder

/// Swappable registry read by service defaults. The forwarding indirection
/// matters: `EnforcementService.shared` and `TakeItCaptiveService.shared` are
/// `static let` singletons, so their initializers capture whatever is set here
/// at first access. Forwarding through `provider` lets the app install the
/// Firebase-backed implementation any time before Firebase is first read,
/// even after the service instance is built.
public final class DefaultFeatureFlags: FeatureFlagProviding {
    public static let shared = DefaultFeatureFlags()

    /// Replaced at app startup with `RemoteConfigFlags()`. Falls back to
    /// `StaticFeatureFlags()` so a test host that never runs `AppDelegate` sees
    /// the same "flag absent, use the caller's default" behavior as production.
    public var provider: FeatureFlagProviding = StaticFeatureFlags()

    private init() {}

    public func bool(_ key: String, default defaultValue: Bool) -> Bool {
        provider.bool(key, default: defaultValue)
    }

    public func string(_ key: String, default defaultValue: String) -> String {
        provider.string(key, default: defaultValue)
    }
}
