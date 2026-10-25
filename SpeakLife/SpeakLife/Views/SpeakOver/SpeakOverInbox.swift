//
//  SpeakOverInbox.swift
//  SpeakLife
//
//  Where a received gift waits until it can be shown.
//
//  A gift arrives two ways, and both land here:
//   1. App installed  → `onOpenURL` in SpeakLifeApp (source "link").
//   2. Fresh install  → `BranchAttribution.apply` resolves the deferred link
//                       during didFinishLaunching (source "deferred").
//
//  Neither path presents anything. The second one runs before onboarding has
//  even started, and a gift fighting onboarding is how the warmest install we
//  get bounces. So the gift is persisted, survives the app being killed
//  mid-onboarding, and `SpeakOverPresentationModifier` shows it once the user
//  is onboarded and nothing else is on screen.
//
//  Branch also calls back for an installed open of the same link, so the same
//  gift can arrive twice within a second. Delivery is idempotent: a gift equal
//  to the one waiting, or to the one shown in the last few minutes, is ignored.
//

import SwiftUI
import UIKit

/// A gift plus how it got here.
struct SpeakOverDelivery: Codable, Identifiable, Equatable {
    enum Source: String, Codable {
        case link
        case deferred
    }

    var id = UUID()
    let gift: SpeakOverGift
    let source: Source
    let receivedAt: Date
}

enum SpeakOverInbox {

    static let didChange = Notification.Name("SpeakOverInboxDidChange")

    private static let pendingKey = "speakOverPendingGift"
    private static let lastShownKey = "speakOverLastShownGift"

    /// A gift nobody opened in two weeks is stale; showing it then would be odd.
    static let lifetime: TimeInterval = 14 * 24 * 60 * 60
    /// How long a shown gift is remembered, to swallow the duplicate callback.
    static let repeatWindow: TimeInterval = 10 * 60

    private struct Shown: Codable {
        let gift: SpeakOverGift
        let at: Date
    }

    /// Queues a gift. Returns false when it was a duplicate.
    @discardableResult
    static func deliver(_ gift: SpeakOverGift,
                        source: SpeakOverDelivery.Source,
                        now: Date = Date(),
                        defaults: UserDefaults = .standard) -> Bool {
        if let waiting = pending(now: now, defaults: defaults), waiting.gift == gift {
            return false
        }
        if let shown = decode(Shown.self, forKey: lastShownKey, defaults: defaults),
           shown.gift == gift,
           now.timeIntervalSince(shown.at) < repeatWindow {
            return false
        }
        let delivery = SpeakOverDelivery(gift: gift, source: source, receivedAt: now)
        guard let data = try? JSONEncoder().encode(delivery) else { return false }
        defaults.set(data, forKey: pendingKey)
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: didChange, object: nil)
        }
        return true
    }

    /// The gift waiting to be shown, if any. Drops it once it has expired, so
    /// a stale one can never sit there forever.
    static func pending(now: Date = Date(), defaults: UserDefaults = .standard) -> SpeakOverDelivery? {
        guard let delivery = decode(SpeakOverDelivery.self, forKey: pendingKey, defaults: defaults) else {
            // Unreadable data (a future format, a corrupt write) is cleared
            // rather than retried on every launch.
            if defaults.object(forKey: pendingKey) != nil {
                defaults.removeObject(forKey: pendingKey)
            }
            return nil
        }
        guard now.timeIntervalSince(delivery.receivedAt) < lifetime else {
            defaults.removeObject(forKey: pendingKey)
            return nil
        }
        return delivery
    }

    /// Called once the gift has been on screen. Removes it only if it is still
    /// the one waiting: a different gift that arrived while this one was open
    /// stays queued and is shown next.
    static func markShown(_ delivery: SpeakOverDelivery,
                          now: Date = Date(),
                          defaults: UserDefaults = .standard) {
        if let waiting = decode(SpeakOverDelivery.self, forKey: pendingKey, defaults: defaults),
           waiting.id == delivery.id {
            defaults.removeObject(forKey: pendingKey)
        }
        if let data = try? JSONEncoder().encode(Shown(gift: delivery.gift, at: now)) {
            defaults.set(data, forKey: lastShownKey)
        }
    }

    private static func decode<T: Decodable>(_ type: T.Type, forKey key: String,
                                             defaults: UserDefaults) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}

// MARK: - Presentation

struct SpeakOverPresentationModifier: ViewModifier {

    /// Passed in, NOT read from the environment: this modifier sits above the
    /// `.environmentObject` calls in SpeakLifeApp, exactly like
    /// `StandRedemptionModifier`, and would crash looking for them.
    @ObservedObject var appState: AppState
    /// Read once per presentation for the background photo. Not observed, so a
    /// theme change does not re-render the whole app root.
    let themeViewModel: ThemeViewModel

    @Environment(\.scenePhase) private var scenePhase
    /// The gift on screen, kept so dismissal can mark that exact one shown.
    @State private var showing: SpeakOverDelivery?
    @State private var presentedAt: Date?
    @State private var busyRetries = 0

    /// About three minutes of waiting for another screen to close.
    private let maxBusyRetries = 90

    func body(content: Content) -> some View {
        content
            .onAppear { schedule() }
            .onChange(of: appState.isOnboarded) { _, _ in schedule() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { schedule() }
            }
            .onReceive(NotificationCenter.default.publisher(for: SpeakOverInbox.didChange)) { _ in
                schedule()
            }
            .fullScreenCover(item: $appState.pendingSpeakOver, onDismiss: {
                // Marked on the way out, not on the way in: if the app is
                // killed while the gift is open, it comes back next launch
                // instead of being lost.
                if let showing { SpeakOverInbox.markShown(showing) }
                showing = nil
                presentedAt = nil
                // A second gift may have arrived while this one was open.
                schedule()
            }) { delivery in
                SpeakOverReceivedView(delivery: delivery, background: backgroundImage)
            }
    }

    private var backgroundImage: UIImage? {
        if themeViewModel.showUserSelectedImage, let selected = themeViewModel.selectedImage {
            return selected
        }
        return UIImage(named: themeViewModel.selectedTheme.backgroundImageString)
    }

    /// A short settle before every check, so a cold launch from a link lets the
    /// landing animation and launch routing finish first.
    @MainActor
    private func schedule(after seconds: Double = 0.9) {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            evaluate()
        }
    }

    @MainActor
    private func evaluate() {
        // Never over onboarding: a fresh install resolves the link before it
        // has even started.
        guard appState.isOnboarded else { return }

        if appState.pendingSpeakOver != nil {
            // A cover SwiftUI could not present (something else was up after
            // all) leaves the slot set with nothing on screen, which would
            // block every later gift. If nothing is presented a few seconds on,
            // free the slot; the gift is still in the inbox and comes straight
            // back.
            if !Self.isScreenBusy, let presentedAt, Date().timeIntervalSince(presentedAt) > 3 {
                appState.pendingSpeakOver = nil
                showing = nil
                self.presentedAt = nil
                schedule()
            }
            return
        }

        guard let delivery = SpeakOverInbox.pending() else { return }

        // A sheet or cover is already up, most often the paywall right after
        // onboarding. SwiftUI silently drops a second cover, so wait for it.
        if Self.isScreenBusy {
            guard busyRetries < maxBusyRetries else { return }
            busyRetries += 1
            schedule(after: 2)
            return
        }

        busyRetries = 0
        showing = delivery
        presentedAt = Date()
        appState.pendingSpeakOver = delivery
    }

    /// Whether the key window already has something presented over it.
    @MainActor
    private static var isScreenBusy: Bool {
        let windows = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
        guard let window = windows.first(where: { $0.isKeyWindow }) ?? windows.first,
              let root = window.rootViewController else { return false }
        return root.presentedViewController != nil
    }
}

extension View {
    /// Attach once, at the root, next to `standRedemption`.
    func speakOverPresentation(appState: AppState, themeViewModel: ThemeViewModel) -> some View {
        modifier(SpeakOverPresentationModifier(appState: appState, themeViewModel: themeViewModel))
    }
}
