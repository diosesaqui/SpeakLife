//
//  ForceUpdateGate.swift
//  SpeakLife
//
//  The blocking "you must update" screen, and the plumbing that decides when to
//  put it on screen.
//
//  Three pieces live here:
//
//  * **`ForcedUpdatePrompt`** — the resolved decision plus its copy. Published by
//    `SubscriptionStore` alongside every other Remote Config value, so the gate
//    re-evaluates on exactly the same beats the rest of the config does: the
//    launch fetch, the foreground fetch in `HomeView`, and the real-time
//    config-update listener.
//  * **`ForceUpdatePresenter`** — presentation, in its own `UIWindow` rather than
//    a `.fullScreenCover`. This mirrors `DebugFlagPanel`'s window trick, and for
//    the same reason, only more sharply: the app puts paywalls, onboarding and
//    the daily burst up as covers, and SwiftUI presents one cover per context.
//    A gate that a live paywall can sit on top of is not a gate. A window above
//    `.alert` level covers everything, always.
//  * **`ForceUpdateView`** — the screen itself. No dismiss control, no swipe, no
//    "later". The only affordance is the App Store.
//
//  The window sits at `.alert + 1`, the same level as the debug panel, so a
//  TestFlight tester can still shake past it to flip `forceUpdateEnabled` off
//  (a window added later wins the tie). On the App Store that panel does not
//  exist, so the gate there is absolute.
//
//  The decision itself is not made here — it is `MinimumVersionPolicy` in
//  SpeakLifeCore, which fails open on every ambiguity and is covered by tests.
//

import SwiftUI
import UIKit

// MARK: - Prompt

/// A resolved forced-update decision, with the copy to render.
///
/// Presence means blocked. `SubscriptionStore` publishes nil whenever the user
/// is free to keep using the app, which is the overwhelmingly common case.
struct ForcedUpdatePrompt: Equatable {
    let title: String
    let message: String
    /// The floor that triggered this, carried for analytics and the debug panel.
    let minimumVersion: String

    static let defaultTitle = "Time to update"
    static let defaultMessage = """
        You're on an older version of SpeakLife. Update to keep your \
        declarations, audio, and streak working the way they should.
        """

    /// Builds the prompt from Remote Config copy, falling back to the shipped
    /// wording when the console leaves the copy keys empty (the normal case —
    /// they exist so support can tailor the message without a release).
    init(title: String, message: String, minimumVersion: String) {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
        self.title = trimmedTitle.isEmpty ? Self.defaultTitle : trimmedTitle
        self.message = trimmedMessage.isEmpty ? Self.defaultMessage : trimmedMessage
        self.minimumVersion = minimumVersion
    }
}

// MARK: - Presentation

/// Owns the gate's window. Idempotent: syncing the same state twice does nothing.
@MainActor
final class ForceUpdatePresenter {

    static let shared = ForceUpdatePresenter()

    private var gateWindow: UIWindow?
    private var presentedPrompt: ForcedUpdatePrompt?
    private weak var previousKeyWindow: UIWindow?

    private init() {}

    /// Brings the window in, out, or updates its copy, to match `prompt`.
    ///
    /// Called on launch, on every foreground, and whenever Remote Config
    /// re-publishes — so it has to be safe to call repeatedly with no change.
    func sync(prompt: ForcedUpdatePrompt?) {
        guard let prompt else {
            dismiss()
            return
        }
        guard prompt != presentedPrompt else { return }
        present(prompt)
    }

    private func present(_ prompt: ForcedUpdatePrompt) {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive })
                ?? UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first
        else { return }

        presentedPrompt = prompt
        let root = ForceUpdateView(prompt: prompt)

        if let existing = gateWindow {
            // Only the copy changed — a Remote Config edit while the gate is
            // already up. Swap the content and leave the window where it is.
            existing.rootViewController = UIHostingController(rootView: root)
            return
        }

        previousKeyWindow = scene.keyWindow

        let window = UIWindow(windowScene: scene)
        // Same level as the debug panel, deliberately: see the file header.
        window.windowLevel = UIWindow.Level(rawValue: UIWindow.Level.alert.rawValue + 1)
        window.rootViewController = UIHostingController(rootView: root)
        window.makeKeyAndVisible()
        gateWindow = window

        AnalyticsService.shared.track("force_update_shown", parameters: [
            "current_version": APP.Version.stringNumber,
            "minimum_version": prompt.minimumVersion
        ])
    }

    /// Takes the gate down. Only reachable by Remote Config withdrawing the
    /// requirement (or a tester clearing the override) — never by the user.
    private func dismiss() {
        presentedPrompt = nil
        guard let window = gateWindow else { return }
        window.isHidden = true
        window.rootViewController = nil
        gateWindow = nil
        // Hand key status back explicitly. Dropping a key window does not
        // reliably promote the one underneath it, and a scene with no key
        // window stops routing keyboard input.
        previousKeyWindow?.makeKey()
        previousKeyWindow = nil
    }
}

// MARK: - Screen

/// The blocking update screen. Branded to match `LandingView` so the app the
/// user is locked out of still looks like the app they installed.
struct ForceUpdateView: View {

    let prompt: ForcedUpdatePrompt

    @Environment(\.openURL) private var openURL

    var body: some View {
        ZStack {
            Image("moonlight2")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .ignoresSafeArea()

            LinearGradient(
                colors: [
                    Color.black.opacity(0.35),
                    Color(red: 0.04, green: 0.06, blue: 0.15).opacity(0.85)
                ],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer()

                Image(uiImage: UIImage(named: "appIconDisplay") ?? UIImage())
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 108, height: 108)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .shadow(color: .black.opacity(0.35), radius: 18, y: 8)

                VStack(spacing: 14) {
                    Text(prompt.title)
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(Constants.SLPaper)
                        .multilineTextAlignment(.center)

                    Text(prompt.message)
                        .font(.system(size: 17, weight: .regular))
                        .foregroundStyle(Constants.SLPaper.opacity(0.85))
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 32)

                Spacer()

                VStack(spacing: 12) {
                    Button(action: openAppStore) {
                        Text("Update on the App Store")
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .foregroundStyle(Constants.SLBlue)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(
                                RoundedRectangle(cornerRadius: 28, style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: [Constants.SLAmber, Constants.SLGold],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            )
                    }
                    .accessibilityHint("Opens SpeakLife in the App Store so you can install the latest version.")

                    Text("Version \(APP.Version.stringNumber)")
                        .font(.footnote)
                        .foregroundStyle(Constants.SLMuted)
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 40)
            }
        }
    }

    private func openAppStore() {
        AnalyticsService.shared.track("force_update_cta_tapped", parameters: [
            "current_version": APP.Version.stringNumber,
            "minimum_version": prompt.minimumVersion
        ])
        guard let url = URL(string: APP.Product.urlID) else { return }
        openURL(url)
    }
}

// MARK: - Wiring

extension View {
    /// Installs the forced-update gate above this view.
    ///
    /// The store is passed in rather than read from the environment for the same
    /// reason `.debugFlagPanel` takes it: this modifier is applied above the
    /// `.environmentObject` calls that inject it, so it would never see them.
    func forceUpdateGate(subscriptionStore: SubscriptionStore) -> some View {
        modifier(ForceUpdateGateModifier(subscriptionStore: subscriptionStore))
    }
}

struct ForceUpdateGateModifier: ViewModifier {

    @ObservedObject var subscriptionStore: SubscriptionStore

    func body(content: Content) -> some View {
        content
            .onAppear { sync() }
            .onChange(of: subscriptionStore.forcedUpdatePrompt) { _ in sync() }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                // Re-decide immediately from the config already activated in a
                // previous session, so a returning user on a retired build is
                // stopped at the door rather than after the network round trip.
                // `HomeView`'s foreground fetch then re-publishes moments later
                // with anything newly published, and `sync` is idempotent.
                subscriptionStore.evaluateForcedUpdate()
                sync()
            }
            .onReceive(NotificationCenter.default.publisher(for: DebugOverrides.didChange)) { _ in
                // A tester flipping the flag or typing a minimum version in the
                // shake panel gets the gate immediately, without a relaunch.
                subscriptionStore.evaluateForcedUpdate()
                sync()
            }
    }

    private func sync() {
        ForceUpdatePresenter.shared.sync(prompt: subscriptionStore.forcedUpdatePrompt)
    }
}
