//
//  AnalyticsTracking.swift
//  SpeakLifeCore
//
//  A minimal seam so the moved services (EnforcementCurator, and any others that
//  used to call the app's `AnalyticsService.shared.track`) can report telemetry
//  without the package importing Firebase/PostHog/TikTok/Facebook.
//
//  The app installs a real implementation at startup; tests leave it nil and the
//  calls no-op, which is exactly what the previous test suite already relied on.
//

import Foundation

public protocol AnalyticsTracking: AnyObject {
    func track(_ event: String, parameters: [String: Any])
}

public enum CoreAnalytics {
    /// Installed by the app at startup. Left nil in tests and in the package's own
    /// build so the moved services never reach for Firebase.
    public static var provider: AnalyticsTracking?

    public static func track(_ event: String, parameters: [String: Any] = [:]) {
        provider?.track(event, parameters: parameters)
    }
}
