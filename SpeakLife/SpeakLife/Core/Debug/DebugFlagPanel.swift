//
//  DebugFlagPanel.swift
//  SpeakLife
//
//  Shake the device on a Debug or TestFlight build to open a panel that forces
//  any experiment flag on or off locally, without a Remote Config change and
//  without waiting on the fetch interval.
//
//  Two pieces live here; shake detection itself is not one of them. The app
//  already has exactly one `UIWindow.motionEnded` override, in
//  `GestureDelights.swift`, exposed as `View.onShake`. A second override would
//  be a duplicate declaration, so the panel rides that one.
//
//  * **Presentation** — the panel is hosted in its own `UIWindow` above
//    `.alert`, not in a `.sheet`. The app is full of sheets and full-screen
//    covers (paywalls, onboarding, the burst), and a sheet presented from the
//    root view while one of those is up simply never appears. A separate
//    window always does.
//  * **The panel itself** — one row per flag, three-state: Remote / On / Off.
//    "Remote" is the absence of an override, not a third value, so a tester can
//    always put a flag back exactly as it shipped.
//
//  On the App Store this whole surface is dead: `DebugOverrides.isAvailable` is
//  false, so a shake opens nothing and every override read returns nil.
//

import SwiftUI
import UIKit
import FirebaseRemoteConfig

// MARK: - Presentation

/// Owns the panel's window. A second shake closes what the first one opened.
@MainActor
final class DebugPanelPresenter {

    static let shared = DebugPanelPresenter()

    private var panelWindow: UIWindow?
    private weak var previousKeyWindow: UIWindow?

    private init() {}

    var isPresented: Bool { panelWindow != nil }

    func toggle(subscriptionStore: SubscriptionStore, appState: AppState) {
        if isPresented {
            dismiss()
        } else {
            present(subscriptionStore: subscriptionStore, appState: appState)
        }
    }

    func present(subscriptionStore: SubscriptionStore, appState: AppState) {
        guard DebugOverrides.isAvailable, panelWindow == nil else { return }
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive })
        else { return }

        previousKeyWindow = scene.keyWindow

        let root = DebugFlagPanelView(
            subscriptionStore: subscriptionStore,
            appState: appState,
            onClose: { [weak self] in self?.dismiss() }
        )

        let window = UIWindow(windowScene: scene)
        window.windowLevel = UIWindow.Level(rawValue: UIWindow.Level.alert.rawValue + 1)
        window.rootViewController = UIHostingController(rootView: root)
        window.makeKeyAndVisible()
        panelWindow = window
    }

    func dismiss() {
        panelWindow?.isHidden = true
        panelWindow?.rootViewController = nil
        panelWindow = nil
        // Hand key status back explicitly. Dropping a key window does not
        // reliably promote the one underneath it, and a scene with no key
        // window stops routing keyboard input.
        previousKeyWindow?.makeKey()
        previousKeyWindow = nil
    }
}

/// Stores its two objects rather than reading them from the environment, and
/// that is not a style choice. A modifier is applied *around* the view it
/// modifies, so `.environmentObject(store).debugFlagPanel()` puts this modifier
/// ABOVE the injection — environment flows down, never up, so both lookups
/// would resolve to nothing and SwiftUI would trap on the first shake.
/// Explicit parameters make the attachment point irrelevant.
struct DebugFlagPanelModifier: ViewModifier {
    let subscriptionStore: SubscriptionStore
    let appState: AppState

    func body(content: Content) -> some View {
        // `onShake` (GestureDelights) already owns the single UIWindow
        // motionEnded override for the whole app — a second one here would be a
        // duplicate declaration, so the panel rides the existing hook.
        content.onShake {
            DebugPanelPresenter.shared.toggle(
                subscriptionStore: subscriptionStore,
                appState: appState
            )
        }
    }
}

extension View {
    /// Enables shake-to-open on the tester debug panel. Attach once, at the root.
    func debugFlagPanel(
        subscriptionStore: SubscriptionStore,
        appState: AppState
    ) -> some View {
        modifier(DebugFlagPanelModifier(subscriptionStore: subscriptionStore, appState: appState))
    }
}

// MARK: - Catalog

/// The flags the panel exposes, in the order they appear. Every entry maps to a
/// Remote Config key registered in `AppDelegate`'s defaults.
enum DebugFlagCatalog {

    struct Flag: Identifiable {
        let key: String
        let title: String
        let blurb: String
        var id: String { key }
    }

    static let boolFlags: [Flag] = [
        Flag(key: "checklistHomeEnabled",
             title: "Checklist home tab",
             blurb: "Off reverts to the feed-as-home layout."),
        Flag(key: "enforcementEnabled",
             title: "Enforcement campaigns",
             blurb: "Off takes every Enforcement surface dark at once."),
        Flag(key: "guardEnabled",
             title: "Guarding (Take It Captive)",
             blurb: "Off removes the fifth pillar's only entry point."),
        Flag(key: "onboardingRatingEnabled",
             title: "Onboarding rating ask",
             blurb: "Off skips the rating step in every onboarding flow."),
        Flag(key: "closerPledgeEnabled",
             title: "Closer arm pledge",
             blurb: "Only the closer onboarding arm reads this."),
        Flag(key: "personalizedAudioOrderEnabled",
             title: "Personalized audio order",
             blurb: "On promotes each user's best-matching categories first."),
        Flag(key: "useQuizOnboarding",
             title: "Quiz onboarding (legacy)",
             blurb: "Fallback only; consulted when no variant is set."),
        Flag(key: MinimumVersionPolicy.enabledKey,
             title: "Forced update gate",
             blurb: "On blocks this build when it is below the minimum version below."),
    ]

    static let onboardingVariantKey = "onboardingVariant"

    static let onboardingVariants = [
        "quiz", "product", "identity", "outcomes", "warfare", "promises", "closer",
        "direct",
    ]
}

// MARK: - Panel

struct DebugFlagPanelView: View {

    // Observed, not environment: this view is the root of its own hosting
    // controller, outside the app's view tree, so there is no ancestor to
    // inherit an environment from.
    @ObservedObject var subscriptionStore: SubscriptionStore
    @ObservedObject var appState: AppState

    let onClose: () -> Void

    /// Bumped on every write purely to invalidate the view. `DebugOverrides` is
    /// a plain UserDefaults suite and publishes nothing, so without a @State
    /// change the rows would keep rendering the values they were built with.
    @State private var revision = 0
    @State private var replayConfirmed = false

    /// Draft for the forced-update floor. See `commitMinimumVersion`.
    @State private var minimumVersionDraft =
        DebugOverrides.string(MinimumVersionPolicy.minimumVersionKey) ?? ""

    private let remoteConfig = RemoteConfig.remoteConfig()

    var body: some View {
        NavigationStack {
            List {
                overridesSection
                onboardingSection
                flagsSection
                updateGateSection
                buildSection
            }
            .navigationTitle("Debug Panel")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: onClose)
                }
            }
        }
    }

    // MARK: Sections

    @ViewBuilder
    private var overridesSection: some View {
        Section {
            if DebugOverrides.hasActiveOverrides {
                Label(
                    "\(DebugOverrides.activeOverrideCount) override\(DebugOverrides.activeOverrideCount == 1 ? "" : "s") active",
                    systemImage: "exclamationmark.triangle.fill"
                )
                .foregroundStyle(.orange)

                Button("Clear all overrides", role: .destructive) {
                    DebugOverrides.clearAll()
                    subscriptionStore.applyExperimentFlags()
                    revision += 1
                }
            } else {
                Label("No overrides. This build behaves exactly as shipped.",
                      systemImage: "checkmark.circle")
                .foregroundStyle(.secondary)
            }
        } footer: {
            Text("Overrides are local to this device and beat Remote Config. Most take effect immediately; onboarding changes need a replay or a relaunch.")
        }
    }

    @ViewBuilder
    private var onboardingSection: some View {
        Section("Onboarding") {
            Picker("Variant", selection: onboardingVariantBinding) {
                Text("Remote (\(remoteVariantLabel))").tag("")
                ForEach(DebugFlagCatalog.onboardingVariants, id: \.self) { variant in
                    Text(variant.capitalized).tag(variant)
                }
            }

            LabeledContent("Showing now", value: subscriptionStore.onboardingVariantName)

            if let ad = subscriptionStore.adOnboardingVariant, !ad.isEmpty {
                LabeledContent("Ad-matched", value: ad)
                Button("Clear ad-matched variant") {
                    subscriptionStore.clearAdOnboardingVariant()
                    revision += 1
                }
            }

            // Mid-replay the only other ways out are finishing the arm or
            // force-quitting, so offer the door.
            if appState.debugReplayOnboarding {
                Button("Exit onboarding replay") {
                    appState.debugReplayOnboarding = false
                    onClose()
                }
            }

            Button(replayConfirmed ? "Tap again to confirm" : "Replay onboarding") {
                guard replayConfirmed else {
                    replayConfirmed = true
                    return
                }
                // Deliberately does NOT clear `isOnboarded`. That key syncs with
                // the `.boolOr` strategy (one-way: true everywhere once true
                // anywhere), so CloudKit reconciles a local false back to true
                // within seconds and drops the tester into the app mid-flow.
                // `debugReplayOnboarding` is in-memory and unsynced, so nothing
                // can undo it, and HomeView clears it when the arm completes.
                subscriptionStore.clearOnboardingVariantLock()
                appState.debugReplayOnboarding = true
                onClose()
            }
            .foregroundStyle(.red)
        }
    }

    @ViewBuilder
    private var flagsSection: some View {
        Section("Feature flags") {
            ForEach(DebugFlagCatalog.boolFlags) { flag in
                VStack(alignment: .leading, spacing: 6) {
                    Text(flag.title).font(.subheadline.weight(.semibold))

                    Picker(flag.title, selection: triStateBinding(for: flag.key)) {
                        Text("Remote").tag(TriState.remote)
                        Text("On").tag(TriState.on)
                        Text("Off").tag(TriState.off)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()

                    Text("\(flag.blurb) Remote says \(remoteConfig[flag.key].boolValue ? "on" : "off").")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
    }

    @ViewBuilder
    private var updateGateSection: some View {
        Section {
            LabeledContent("This build", value: APP.Version.stringNumber)

            // Held in local state and committed on Apply, not written per
            // keystroke: writing as you type would raise the gate the moment
            // the digits so far exceed this build, covering the panel you are
            // typing into. Also not .decimalPad — that keyboard permits a
            // single separator, and a version needs two dots.
            TextField("Minimum version (e.g. 99.0.0)", text: $minimumVersionDraft)
                .keyboardType(.numbersAndPunctuation)
                .autocorrectionDisabled()
                .onSubmit { commitMinimumVersion() }

            Button("Apply minimum version") { commitMinimumVersion() }

            LabeledContent("Remote minimum", value: remoteMinimumVersionLabel)

            LabeledContent("Gate", value: subscriptionStore.forcedUpdatePrompt == nil ? "open" : "blocking")
        } header: {
            Text("Forced update")
        } footer: {
            Text("Set a minimum above this build and turn \"Forced update gate\" on to see the screen. The gate window sits at the same level as this panel — shake twice to bring the panel back over it, then clear the override.")
        }
    }

    @ViewBuilder
    private var buildSection: some View {
        Section("Build") {
            LabeledContent("Channel", value: DebugOverrides.buildChannel)
            LabeledContent("Version", value: Self.versionString)
            LabeledContent("Remote Config", value: subscriptionStore.remoteConfigReady ? "activated" : "pending")
            // fetchAndActivate's completion is not guaranteed to be on main.
            Button("Fetch Remote Config now") {
                remoteConfig.fetchAndActivate { _, _ in
                    DispatchQueue.main.async {
                        subscriptionStore.applyExperimentFlags()
                        revision += 1
                    }
                }
            }
        }
    }

    // MARK: Bindings

    private enum TriState: Hashable { case remote, on, off }

    private func triStateBinding(for key: String) -> Binding<TriState> {
        Binding(
            get: {
                guard let value = DebugOverrides.bool(key) else { return .remote }
                return value ? .on : .off
            },
            set: { newValue in
                switch newValue {
                case .remote: DebugOverrides.setBool(key, nil)
                case .on: DebugOverrides.setBool(key, true)
                case .off: DebugOverrides.setBool(key, false)
                }
                subscriptionStore.applyExperimentFlags()
                revision += 1
            }
        )
    }

    /// Empty string means "no override" — the picker's Remote row.
    private var onboardingVariantBinding: Binding<String> {
        Binding(
            get: { DebugOverrides.string(DebugFlagCatalog.onboardingVariantKey) ?? "" },
            set: { newValue in
                DebugOverrides.setString(
                    DebugFlagCatalog.onboardingVariantKey,
                    newValue.isEmpty ? nil : newValue
                )
                subscriptionStore.applyExperimentFlags()
                revision += 1
            }
        )
    }

    /// Writes the typed floor as an override. Empty clears it, falling back to
    /// whatever Remote Config publishes.
    private func commitMinimumVersion() {
        let trimmed = minimumVersionDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        DebugOverrides.setString(
            MinimumVersionPolicy.minimumVersionKey,
            trimmed.isEmpty ? nil : trimmed
        )
        subscriptionStore.applyExperimentFlags()
        revision += 1
    }

    // MARK: Display helpers

    private var remoteMinimumVersionLabel: String {
        let remote = remoteConfig[MinimumVersionPolicy.minimumVersionKey].stringValue
        return remote.isEmpty ? "unset" : remote
    }

    private var remoteVariantLabel: String {
        let value = remoteConfig[DebugFlagCatalog.onboardingVariantKey].stringValue
        return value.isEmpty ? "unset" : value
    }

    private static var versionString: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(short) (\(build))"
    }
}
