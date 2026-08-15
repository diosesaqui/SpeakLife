//
//  MinimumAppVersion.swift
//  SpeakLifeCore
//
//  The decision behind the forced-update screen: given the version the user is
//  holding and the minimum version Remote Config demands, must they go to the
//  App Store before they can use the app?
//
//  It lives here, Foundation-only and away from Firebase and SwiftUI, because
//  this is the one feature in the app that can brick every install at once. A
//  wrong answer locks paying users out of a product that works. So the rule set
//  is small, explicit, and covered by tests rather than inferred at three call
//  sites.
//
//  The governing principle is **fail open**. Every uncertainty — an unset key, a
//  typo in the Firebase console, a bundle version we can't parse — resolves to
//  "let them in". The only path to a locked screen is an operator deliberately
//  turning the gate on AND publishing a parseable minimum that is genuinely
//  newer than the build in hand.
//

import Foundation

// MARK: - Version

/// A dot-separated numeric version ("2", "2.1", "2.1.4"), comparable to another.
///
/// Deliberately narrower than semver: no pre-release tags, no build metadata, no
/// letters. `CFBundleShortVersionString` is numeric-and-dots by App Store rule,
/// and the Firebase value is typed by hand into a console field. Anything else
/// is a mistake, and a mistake must not be silently coerced into a comparison
/// that locks users out — so it fails to parse and the gate stays open.
public struct AppVersion: Comparable, Hashable, CustomStringConvertible, Sendable {

    /// Numeric components, most significant first. Never empty.
    public let components: [Int]

    /// Parses a version string, or returns nil if it isn't purely numeric-and-dots.
    ///
    /// Surrounding whitespace is trimmed: the Firebase console field is free
    /// text and an invisible trailing space is the classic way to break this.
    public init?(_ string: String) {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let parts = trimmed.split(separator: ".", omittingEmptySubsequences: false)
        var parsed: [Int] = []
        parsed.reserveCapacity(parts.count)

        for part in parts {
            // `Int(...)` alone would accept "+3" and "-1"; digits-only keeps the
            // ordering total and rules out a negative component that would sort
            // below every real release.
            guard !part.isEmpty,
                  part.allSatisfy({ $0.isASCII && $0.isNumber }),
                  let value = Int(part)
            else { return nil }
            parsed.append(value)
        }

        components = parsed
    }

    public var description: String {
        components.map(String.init).joined(separator: ".")
    }

    /// Compares component by component, treating a missing trailing component as
    /// zero, so "2.1" and "2.1.0" are the same version rather than adjacent ones.
    public static func < (lhs: AppVersion, rhs: AppVersion) -> Bool {
        let count = max(lhs.components.count, rhs.components.count)
        for index in 0..<count {
            let left = index < lhs.components.count ? lhs.components[index] : 0
            let right = index < rhs.components.count ? rhs.components[index] : 0
            if left != right { return left < right }
        }
        return false
    }

    public static func == (lhs: AppVersion, rhs: AppVersion) -> Bool {
        !(lhs < rhs) && !(rhs < lhs)
    }

    public func hash(into hasher: inout Hasher) {
        // Must agree with `==`, which ignores trailing zeros.
        var significant = components
        while significant.count > 1, significant.last == 0 { significant.removeLast() }
        hasher.combine(significant)
    }
}

// MARK: - Requirement

/// What the app must do about the version the user is holding.
public enum AppUpdateRequirement: Equatable, Sendable {
    /// Nothing to do. The build is current enough, or the gate is off, or we
    /// could not answer confidently and chose to let the user through.
    ///
    /// Named `allowed` rather than `none` so it can never be confused with
    /// `Optional.none` at a call site that switches on it.
    case allowed
    /// The user is below the published minimum: show the blocking update screen.
    case forced
}

// MARK: - Policy

/// Resolves the forced-update decision from Remote Config and the running build.
public enum MinimumVersionPolicy {

    // MARK: Remote Config keys

    /// Master switch. False (the shipped default) makes the whole feature inert
    /// regardless of what `minimumVersionKey` says, so a bad minimum can be
    /// undone with one boolean instead of a new release.
    public static let enabledKey = "forceUpdateEnabled"

    /// The oldest version allowed to keep running, e.g. "2.4.0". Empty (the
    /// shipped default) means no floor.
    public static let minimumVersionKey = "minimumAppVersion"

    /// Optional headline override for the update screen.
    public static let titleKey = "forceUpdateTitle"

    /// Optional body copy override for the update screen.
    public static let messageKey = "forceUpdateMessage"

    // MARK: Decision

    /// The requirement for a build, given the published floor.
    ///
    /// - Parameters:
    ///   - currentVersion: this build's `CFBundleShortVersionString`.
    ///   - minimumVersion: the Remote Config floor; empty when unset.
    ///   - isEnabled: the Remote Config master switch.
    ///
    /// Returns `.forced` only when the switch is on, both versions parse, and
    /// the current one is strictly older. Every other combination is `.allowed`.
    public static func requirement(
        currentVersion: String,
        minimumVersion: String,
        isEnabled: Bool
    ) -> AppUpdateRequirement {
        guard isEnabled else { return .allowed }

        // An unparseable floor is an operator typo. Blocking on it would take
        // the app down for everyone with no way back except a console fix that
        // the locked-out users still have to fetch — so it is ignored.
        guard let minimum = AppVersion(minimumVersion) else { return .allowed }

        // An unparseable current version means we cannot honestly say the user
        // is behind. Same reasoning: let them in.
        guard let current = AppVersion(currentVersion) else { return .allowed }

        return current < minimum ? .forced : .allowed
    }
}
