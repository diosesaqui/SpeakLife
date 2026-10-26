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
    private static let openedKey = "speakOverOpenedDeliveryIds"

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

    /// True the first time a delivery opens, false after.
    ///
    /// Persisted, so a gift that comes back after the app was killed with it
    /// open is not counted as a second open. Keeps the last few ids only.
    @discardableResult
    static func markOpened(_ delivery: SpeakOverDelivery,
                           defaults: UserDefaults = .standard) -> Bool {
        var ids = defaults.stringArray(forKey: openedKey) ?? []
        let id = delivery.id.uuidString
        guard !ids.contains(id) else { return false }
        ids.append(id)
        defaults.set(Array(ids.suffix(20)), forKey: openedKey)
        return true
    }

    private static func decode<T: Decodable>(_ type: T.Type, forKey key: String,
                                             defaults: UserDefaults) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}

// MARK: - Presentation gate

/// When a waiting gift may take the screen. Pure, so the budget is testable.
///
/// Two rules:
///  - The screen must be idle on two checks in a row. Several presenters
///    (the post-Burst prompt and offer, the first-run Burst) fire a beat after
///    something else closes, so one quiet instant is not proof of a quiet
///    screen. A gift that grabs that instant drops theirs, and they burn their
///    once-ever flags before presenting.
///  - While waiting, one chain of retries with a fixed budget. Anything from
///    outside (foreground, a new gift, onboarding ending) starts it afresh.
struct SpeakOverGate: Equatable {

    enum Decision: Equatable {
        case present
        case retry
        case giveUp
    }

    static let retryInterval: Double = 1.5
    /// 120 checks at 1.5s: three minutes of waiting for another screen.
    static let maxRetries = 120

    private(set) var retriesLeft = SpeakOverGate.maxRetries
    private(set) var idleChecks = 0

    mutating func reset() {
        retriesLeft = Self.maxRetries
        idleChecks = 0
    }

    mutating func check(isIdle: Bool) -> Decision {
        if isIdle {
            idleChecks += 1
            if idleChecks >= 2 {
                idleChecks = 0
                return .present
            }
        } else {
            idleChecks = 0
        }
        guard retriesLeft > 0 else { return .giveUp }
        retriesLeft -= 1
        return .retry
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
    /// For the verse of a line that is one of ours. Not observed, same reason.
    let declarationStore: DeclarationViewModel
    /// The launch animation is root content, not a presentation, so the
    /// presented-controller check cannot see it. HomeView raises its own
    /// launch sheet as it ends, and a gift already on screen would drop it.
    let isShowingLanding: Bool

    @Environment(\.scenePhase) private var scenePhase
    /// The gift on screen, kept so dismissal can mark that exact one shown.
    @State private var showing: SpeakOverDelivery?
    @State private var verse: String?
    @State private var presentedAt: Date?
    @State private var gate = SpeakOverGate()
    /// The one pending check. Every new trigger replaces it, so there is only
    /// ever one chain of retries.
    @State private var checkTask: Task<Void, Never>?
    /// When the post-Burst presenters were first seen pending. They clear
    /// their own flag on the way out, but a Burst from a stand returns before
    /// that, so their word is trusted for a bounded time only.
    @State private var yieldingSince: Date?

    func body(content: Content) -> some View {
        content
            .onAppear { trigger() }
            .onChange(of: appState.isOnboarded) { _, _ in trigger() }
            .onChange(of: isShowingLanding) { _, visible in
                // Let HomeView's own launch presentations go first.
                if !visible { trigger(after: 1.5) }
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { trigger() }
            }
            .onReceive(NotificationCenter.default.publisher(for: SpeakOverInbox.didChange)) { _ in
                trigger()
            }
            .fullScreenCover(item: $appState.pendingSpeakOver, onDismiss: {
                // Marked on the way out (and when it is spoken), not on the
                // way in: if the app is killed while the gift is open, it comes
                // back next launch instead of being lost.
                if let showing { SpeakOverInbox.markShown(showing) }
                showing = nil
                presentedAt = nil
                // A second gift may have arrived while this one was open.
                trigger()
            }) { delivery in
                SpeakOverReceivedView(delivery: delivery, verse: verse, background: backgroundImage)
            }
    }

    private var backgroundImage: UIImage? {
        if themeViewModel.showUserSelectedImage, let selected = themeViewModel.selectedImage {
            return selected
        }
        return UIImage(named: themeViewModel.selectedTheme.backgroundImageString)
    }

    /// Something from outside: a fresh budget and a fresh chain.
    @MainActor
    private func trigger(after seconds: Double = SpeakOverGate.retryInterval) {
        gate.reset()
        schedule(after: seconds)
    }

    /// Replaces any pending check with this one.
    @MainActor
    private func schedule(after seconds: Double) {
        checkTask?.cancel()
        checkTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            guard !Task.isCancelled else { return }
            evaluate()
        }
    }

    @MainActor
    private func evaluate() {
        // Never over onboarding (a fresh install resolves the link before it
        // has started), and never over the launch animation; its end triggers
        // a fresh check.
        guard appState.isOnboarded, !isShowingLanding else { return }

        if appState.pendingSpeakOver != nil {
            // Our cover is up, or SwiftUI dropped it because something else
            // was. Its dismissal triggers a fresh check, but nothing would in
            // the second case, so keep checking on the same budget.
            guard !Self.isScreenBusy else {
                if gate.check(isIdle: false) == .retry {
                    schedule(after: SpeakOverGate.retryInterval)
                }
                return
            }
            // Nothing is presented, yet the slot is set: SwiftUI dropped the
            // cover. Free the slot after a moment; the gift is still in the
            // inbox and comes straight back.
            if let presentedAt, Date().timeIntervalSince(presentedAt) > 3 {
                appState.pendingSpeakOver = nil
                showing = nil
                self.presentedAt = nil
                trigger()
            } else {
                schedule(after: SpeakOverGate.retryInterval)
            }
            return
        }

        guard let delivery = SpeakOverInbox.pending() else { return }

        // Over a hard paywall (lapsed or never-subscribed wall) is allowed on
        // purpose: those replace the root content rather than presenting, so
        // this check sees an idle screen. A gift is free, and closing it lands
        // the user back on the wall.
        let idle = !Self.isScreenBusy && !otherPresenterIsDue()
        switch gate.check(isIdle: idle) {
        case .present:
            showing = delivery
            verse = SpeakOverLink.verse(for: delivery.gift, in: declarationStore.allAvailableDeclarations)
            presentedAt = Date()
            appState.pendingSpeakOver = delivery
        case .retry:
            schedule(after: SpeakOverGate.retryInterval)
        case .giveUp:
            // Waits for the next foreground, gift or onboarding change.
            break
        }
    }

    /// Presenters that fire a beat after a Burst closes, or open the first-run
    /// Burst a beat after home appears. Raising the gift in that gap would
    /// drop theirs.
    @MainActor
    private func otherPresenterIsDue() -> Bool {
        let due = appState.pendingFirstRunBurst
            || PersonalDeclarationPrompt.shared.isPendingOrShowing
            || WelcomeOfferPresenter.shared.isPendingOrShowing
        guard due else {
            yieldingSince = nil
            return false
        }
        let since = yieldingSince ?? Date()
        yieldingSince = since
        // A real one presents within a second or two. A flag still up after
        // 10s belongs to a Burst that never reached its presenters.
        return Date().timeIntervalSince(since) < 10
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
    func speakOverPresentation(appState: AppState,
                               themeViewModel: ThemeViewModel,
                               declarationStore: DeclarationViewModel,
                               isShowingLanding: Bool) -> some View {
        modifier(SpeakOverPresentationModifier(appState: appState,
                                               themeViewModel: themeViewModel,
                                               declarationStore: declarationStore,
                                               isShowingLanding: isShowingLanding))
    }
}
