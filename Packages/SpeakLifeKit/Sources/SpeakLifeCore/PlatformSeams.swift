//
//  PlatformSeams.swift
//  SpeakLifeCore
//
//  Foundation-only seams that let the Core Data stack and the sync stores
//  compile without `import UIKit`. Two dependencies are handled here:
//
//  - `LifecycleNames`: the app's foreground / background notification names,
//    passed into each store's `start(lifecycle:)` so the store observes them
//    without knowing they come from UIKit.
//
//  - `DefaultVendorIdentifier`: a swappable reader for the current device's
//    vendor identifier. `ProgressSyncStore.deviceId` pins its stored id to
//    this value so an iCloud-restored install mints a fresh id instead of
//    fighting the source device over the same counter row (see the block
//    comment on `deviceId` for why the pin is load-bearing). The default
//    returns nil, which is the correct behavior on a package boundary that
//    has no UIKit — AppDelegate installs the UIDevice-backed reader at
//    startup, before either sync store is first touched.
//

import Foundation

// MARK: - Lifecycle notification injection

/// The names a sync store watches to know when the app came to the
/// foreground or backgrounded. The stores treat these as opaque:
/// registration happens once at `start(lifecycle:)` and only ever posts
/// through NotificationCenter.
public struct LifecycleNames {
    public let didBecomeActive: Notification.Name
    public let didEnterBackground: Notification.Name

    public init(didBecomeActive: Notification.Name, didEnterBackground: Notification.Name) {
        self.didBecomeActive = didBecomeActive
        self.didEnterBackground = didEnterBackground
    }
}

// MARK: - Vendor identifier injection

/// Swappable reader for the current device's vendor identifier
/// (`UIDevice.current.identifierForVendor` on iOS). Installed by the app at
/// startup; defaults to nil so tests and Foundation-only contexts never
/// pull UIKit in through a default.
///
/// The forwarding indirection matches `DefaultFeatureFlags` — see the note
/// on that type for why late-bound holders are the shape that survives
/// `static let shared` singletons.
public final class DefaultVendorIdentifier {
    public static let shared = DefaultVendorIdentifier()

    /// Replaced by the app at startup with `{ UIDevice.current.identifierForVendor?.uuidString }`.
    /// Foundation-only default returns nil, which
    /// `ProgressSyncStore.deviceId` handles the same way it always has: if
    /// no current vendor is available, the stored id is trusted as-is.
    public var read: () -> String? = { nil }

    private init() {}
}
