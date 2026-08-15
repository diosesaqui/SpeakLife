//
//  DebugOverrides.swift
//  SpeakLifeCore
//
//  Local, tester-only overrides for the remote experiment flags. The shake
//  panel in the app target writes here; every flag read path reads here first
//  and falls back to Remote Config when nothing is overridden.
//
//  Two properties matter and both are enforced in this file, not by the caller:
//
//  1. **Inert on the App Store.** `isAvailable` is false in an App Store build,
//     and every read returns nil when it is false. A value left behind by a
//     TestFlight build that later updates to the store version cannot change
//     what a paying user sees — the store build simply stops looking.
//  2. **Its own defaults suite.** Overrides live in
//     `com.speaklife.debugOverrides`, never in the app's standard defaults, so
//     a tester's flag flipping can never collide with a real product key.
//
//  Foundation-only on purpose, same as `FeatureFlags.swift` next to it: the
//  services that read flags stay free of Firebase, and the store is testable
//  under `swift test` with no simulator.
//

import Foundation

public enum DebugOverrides {

    /// Posted after any override is written or cleared, so a live surface can
    /// re-read without the tester relaunching.
    public static let didChange = Notification.Name("DebugOverridesDidChange")

    // MARK: - Availability

    /// Whether debug overrides are honored in this build at all.
    ///
    /// TestFlight builds ship with a *sandbox* App Store receipt; App Store
    /// builds ship with a production one. That receipt filename is the only
    /// signal available at runtime that distinguishes the two — the binary and
    /// the build configuration are identical.
    public static let isAvailable: Bool = {
        #if DEBUG
        return true
        #else
        return Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt"
        #endif
    }()

    /// Human-readable channel, shown in the panel header so a tester can tell
    /// at a glance which build they are holding.
    public static var buildChannel: String {
        #if DEBUG
        return "Debug"
        #else
        return isAvailable ? "TestFlight" : "App Store"
        #endif
    }

    // MARK: - Storage

    private static let suiteName = "com.speaklife.debugOverrides"
    private static let indexKey = "__overrideIndex"
    private static let boolPrefix = "b."
    private static let stringPrefix = "s."

    private static let store: UserDefaults = UserDefaults(suiteName: suiteName) ?? .standard

    // MARK: - Reads

    /// The overridden value for a boolean flag, or nil to use Remote Config.
    public static func bool(_ key: String) -> Bool? {
        guard isAvailable else { return nil }
        return store.object(forKey: boolPrefix + key) as? Bool
    }

    /// The overridden value for a string flag, or nil to use Remote Config.
    public static func string(_ key: String) -> String? {
        guard isAvailable else { return nil }
        return store.string(forKey: stringPrefix + key)
    }

    /// True when at least one override is set. Drives the panel's "overrides
    /// active" warning, which exists so nobody reports a bug against a build
    /// they have quietly forced into a non-shipping configuration.
    public static var hasActiveOverrides: Bool {
        isAvailable && !index.isEmpty
    }

    /// Count of set overrides, for the same warning.
    public static var activeOverrideCount: Int {
        isAvailable ? index.count : 0
    }

    // MARK: - Writes

    /// Sets a boolean override; pass nil to clear it and fall back to Remote Config.
    public static func setBool(_ key: String, _ value: Bool?) {
        if let value {
            write(storageKey: boolPrefix + key, value: value)
        } else {
            clear(storageKey: boolPrefix + key)
        }
    }

    /// Sets a string override; pass nil to clear it and fall back to Remote Config.
    public static func setString(_ key: String, _ value: String?) {
        if let value {
            write(storageKey: stringPrefix + key, value: value)
        } else {
            clear(storageKey: stringPrefix + key)
        }
    }

    /// Drops every override at once, returning the build to whatever Remote
    /// Config says. The index is what makes this exact: only keys this type
    /// wrote are removed.
    public static func clearAll() {
        guard isAvailable else { return }
        for storageKey in index { store.removeObject(forKey: storageKey) }
        store.removeObject(forKey: indexKey)
        NotificationCenter.default.post(name: didChange, object: nil)
    }

    // MARK: - Private

    private static func write(storageKey: String, value: Any) {
        guard isAvailable else { return }
        store.set(value, forKey: storageKey)
        if !index.contains(storageKey) { index.append(storageKey) }
        NotificationCenter.default.post(name: didChange, object: nil)
    }

    private static func clear(storageKey: String) {
        guard isAvailable else { return }
        store.removeObject(forKey: storageKey)
        index.removeAll { $0 == storageKey }
        NotificationCenter.default.post(name: didChange, object: nil)
    }

    /// Which storage keys currently hold an override. Kept explicitly rather
    /// than derived from the suite's dictionary, because a suite's
    /// `dictionaryRepresentation()` also carries the global and registration
    /// domains — clearing from that would reach outside this store.
    private static var index: [String] {
        get { store.stringArray(forKey: indexKey) ?? [] }
        set { store.set(newValue, forKey: indexKey) }
    }
}
