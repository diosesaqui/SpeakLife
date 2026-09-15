//
//  StandDiscovery.swift
//  SpeakLife
//
//  How anyone finds out this feature exists. Spec §9.5.
//
//  A share feature nobody finds is dead, and the link mechanics are worthless
//  without this. The rule everything here follows:
//
//      Ask at peak emotional payoff, not at peak convenience.
//
//  That is usually a trade — asking later means partners start out of sync —
//  but not here. `dayNumber` is per member and campaigns wait rather than
//  expire, so somebody joining on day 3 is not behind, they are on their own
//  day 1. There is no sync to protect, which frees the ask to land where it has
//  the most charge. That is a direct payoff of the mirror invariant and should
//  not be traded away later for a "start together" flow.
//
//  Everything here is gated on `FeatureFlag.standTogetherEnabled` and, for the
//  one-shot prompts, on a global cap: somebody who is never going to invite
//  anyone should stop being asked.
//

import SwiftUI
import SpeakLifeCore

// MARK: - Prompt budget

// `shouldPrompt` reads `StandService.shared.rooms`, which is main-actor
// isolated, and every caller is a SwiftUI view body. Isolating the whole enum
// is simpler and more honest than making one function nonisolated and then
// hopping actors inside it.
@MainActor
enum StandDiscovery {

    private static let promptCountKey = "standInvitePromptCount"
    private static let lastPromptedDayKey = "standInvitePromptedForDay"

    /// Three, ever. The persistent row on the campaign card does not count
    /// against this — it is passive and always present, so it can never nag.
    static let maxPrompts = 3

    static var hasPromptBudget: Bool {
        UserDefaults.standard.integer(forKey: promptCountKey) < maxPrompts
    }

    static func recordPromptShown() {
        let n = UserDefaults.standard.integer(forKey: promptCountKey)
        UserDefaults.standard.set(n + 1, forKey: promptCountKey)
    }

    /// True once per campaign day, so returning to the Today tab five times
    /// after finishing day 1 does not ask five times.
    static func shouldPrompt(forDay day: Int) -> Bool {
        guard FeatureFlag.standTogetherEnabled, hasPromptBudget else { return false }
        guard !StandService.shared.rooms.contains(where: { $0.status == .active }) else { return false }
        return UserDefaults.standard.integer(forKey: lastPromptedDayKey) != day
    }

    static func markPrompted(day: Int) {
        UserDefaults.standard.set(day, forKey: lastPromptedDayKey)
        recordPromptShown()
    }
}

// MARK: - The persistent affordance
//
// Surface 2 in spec §9.5, and the most important one: it is always findable,
// and it is the ONLY way users who are already mid-campaign when this ships
// discover the feature at all.
//
// It shipped once as a 13pt line of text with no background, tucked under the
// card's full-width gold CTA. It did not read as a control, the tap target was
// only as wide as the words, and "Stand with me" is what you say TO somebody
// else — on your own card it is addressed to the wrong person. It is now a
// full-width row with a surface, a chevron and a 44pt tap target, and it says
// what tapping it does.

struct StandInviteRow: View {

    let enforcement: Enforcement

    @ObservedObject private var service = StandService.shared
    @ObservedObject private var auth = StandAuthCoordinator.shared

    @State private var showInvite = false
    @State private var showRoom = false

    private var existingRoom: StandRoom? {
        service.rooms.first { $0.status == .active && $0.enforcement.id == enforcement.id }
    }

    /// Somebody else is actually in it. A stand of one is still an invite row.
    private var companions: [StandMember] {
        guard let existingRoom else { return [] }
        return existingRoom.activeMembers.filter { $0.uid != auth.currentUid }
    }

    var body: some View {
        if FeatureFlag.standTogetherEnabled {
            Button {
                PremiumHaptics.light()
                if companions.isEmpty { showInvite = true } else { showRoom = true }
            } label: {
                HStack(spacing: DS.Spacing.sm) {
                    leading
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                        Text(subtitle)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.55))
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    }
                    Spacer(minLength: DS.Spacing.xs)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white.opacity(0.4))
                }
                .padding(.horizontal, DS.Spacing.sm)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                        .fill(Color.white.opacity(0.07))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                        .stroke(Color.white.opacity(0.14), lineWidth: 1)
                )
                // Without this the Spacer and the padding are not hit-testable,
                // so most of a full-width row ignores taps.
                .contentShape(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.top, DS.Spacing.xxs)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(title). \(subtitle)")
            .accessibilityAddTraits(.isButton)
            // Presented for a campaign, not a room: the sheet creates the stand
            // itself and shows any failure on its own face. Nothing here can
            // fail silently.
            .sheet(isPresented: $showInvite) {
                StandInviteSheet(source: .newStand(enforcement))
            }
            .sheet(isPresented: $showRoom) {
                if let existingRoom {
                    NavigationStack { StandRoomView(roomId: existingRoom.id) }
                }
            }
        }
    }

    // MARK: - Copy
    //
    // Plain, and in the right voice. The row belongs to the person running the
    // campaign, so it names what THEY are about to do.

    private var title: String {
        guard let first = companions.first else {
            return "Invite someone to stand with you"
        }
        if companions.count == 1 {
            return "\(first.displayName) is standing with you"
        }
        return "\(companions.count) people are standing with you"
    }

    private var subtitle: String {
        guard let existingRoom, !companions.isEmpty else {
            return "They speak the same words, all 7 days."
        }
        return existingRoom.presenceSummary(todayStamp: StandDayStamp.stamp())
    }

    @ViewBuilder
    private var leading: some View {
        if let existingRoom, !companions.isEmpty {
            avatars(existingRoom)
        } else {
            Image(systemName: "person.2.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(DS.Palette.gold.opacity(0.9))
                .frame(width: 28, height: 28)
                .background(Circle().fill(DS.Palette.gold.opacity(0.12)))
        }
    }

    private func avatars(_ room: StandRoom) -> some View {
        HStack(spacing: -8) {
            ForEach(room.activeMembers.prefix(3)) { member in
                ZStack {
                    Circle()
                        .fill(StandMemberRow.palette[member.colorIndex % StandMemberRow.palette.count])
                        .frame(width: 26, height: 26)
                    Text(member.displayInitial)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                .overlay(Circle().stroke(Color.black.opacity(0.35), lineWidth: 1.5))
            }
        }
    }
}

// MARK: - Shared lookup

/// Finding the stand a campaign already has, in one place.
///
/// Creating one used to live here too, behind a call that returned nil on every
/// failure after a `print`. Every caller then had a button that could silently
/// do nothing. Creation now belongs to `StandInviteSheet`, which has a screen to
/// put the failure on.
@MainActor
enum StandInviteLauncher {

    /// An existing active stand for this campaign, if there is one.
    static func existingRoom(for enforcement: Enforcement) -> StandRoom? {
        StandService.shared.rooms.first {
            $0.status == .active && $0.enforcement.id == enforcement.id
        }
    }
}

// MARK: - The day-1 prompt
//
// Surface 1 in spec §9.5, and the highest-charge moment in the loop: they just
// spoke it out loud and felt it.

struct StandInvitePromptSheet: View {

    let enforcement: Enforcement
    @Environment(\.dismiss) private var dismiss

    @State private var showInvite = false

    var body: some View {
        ZStack {
            Gradients().speakLifeCYOCell.ignoresSafeArea()
            VStack(spacing: DS.Spacing.lg) {
                Spacer()

                Text("👐").font(.system(size: 56))

                Text("Who needs this with you?")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(DS.Palette.textPrimary)
                    .multilineTextAlignment(.center)

                Text("Seven days, the same word, spoken together. They don't have to start today.")
                    .font(DS.Typography.body)
                    .foregroundColor(DS.Palette.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, DS.Spacing.md)

                Spacer()

                // Opens the invite sheet and lets it do the work. This button
                // used to create the room itself and set `room` from a call
                // that returned nil on any failure, so a bad network turned the
                // only button on this screen into a no-op.
                Button {
                    showInvite = true
                } label: {
                    Text("Invite someone")
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DS.Spacing.sm)
                        .background(Capsule().fill(DS.Palette.gold))
                }

                Button("Maybe later") { dismiss() }
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(DS.Palette.textSecondary)
                    .padding(.bottom, DS.Spacing.md)
            }
            .padding(DS.Spacing.md)
        }
        .presentationDetents([.medium])
        .sheet(isPresented: $showInvite) {
            StandInviteSheet(source: .newStand(enforcement))
        }
        .onAppear {
            AnalyticsService.shared.track("stand_invite_prompted", parameters: [
                "enforcement_id": enforcement.id,
            ])
        }
    }
}

// MARK: - Redemption
//
// A code arrives from a link (installed), a deferred link (fresh install), or
// typing. All three land in `AppState.pendingStandCode`, and this is the one
// place that turns it into a screen.

struct StandRedemptionModifier: ViewModifier {

    /// Passed in, NOT read from the environment.
    ///
    /// This modifier is applied above the `.environmentObject` calls in
    /// SpeakLifeApp, so it wraps the view those inject into and never sees
    /// them — reading `@EnvironmentObject` here crashes at launch with "No
    /// ObservableObject of type AppState found". `debugFlagPanel` right above
    /// it carries a comment saying exactly this; it is the same trap.
    @ObservedObject var appState: AppState
    @State private var showJoin = false

    func body(content: Content) -> some View {
        content
            .onChange(of: appState.pendingStandCode) { _, _ in evaluate() }
            .onAppear { evaluate() }
            .sheet(isPresented: $showJoin, onDismiss: {
                // Cleared on dismissal too, not only on success. A code left
                // sitting would re-present this sheet on every launch, which
                // is worse than losing an invite the user declined.
                appState.pendingStandCode = ""
            }) {
                NavigationStack {
                    StandJoinView(prefilledCode: appState.pendingStandCode)
                }
            }
    }

    private func evaluate() {
        guard FeatureFlag.standTogetherEnabled,
              !appState.pendingStandCode.isEmpty,
              // Never over onboarding. A deferred link resolves during
              // didFinishLaunching, which on a fresh install is before
              // onboarding has finished — and a join sheet fighting onboarding
              // is how the highest-intent install in the feature bounces.
              appState.isOnboarded else { return }
        showJoin = true
    }
}

extension View {
    /// Attach once, at the root. Takes `appState` explicitly for the reason on
    /// `StandRedemptionModifier.appState`.
    func standRedemption(appState: AppState) -> some View {
        modifier(StandRedemptionModifier(appState: appState))
    }
}

// MARK: - Completion and push routing
//
// Both of these were written and then never presented: `justCompletedRoom` was
// set by the listener and read by nothing, and `pendingStandRoomId` was written
// by the push handler and read by nothing. A day-7 celebration that never
// appears and a notification that opens nothing are worse than not having them,
// because the server still sends the push.

struct StandPresentationModifier: ViewModifier {

    @ObservedObject var appState: AppState
    @ObservedObject private var service = StandService.shared

    func body(content: Content) -> some View {
        content
            // The shared day-7 celebration. A full-screen cover rather than a
            // sheet: finishing seven days with someone is not a detail view.
            .fullScreenCover(item: $service.justCompletedRoom) { room in
                StandCompletionView(room: room) {
                    service.justCompletedRoom = nil
                }
            }
            // A stand push carries the room it is about. Opening it is the
            // entire point of the notification.
            .sheet(item: $appState.pendingStandRoomId) { roomId in
                NavigationStack {
                    StandRoomView(roomId: roomId.value)
                }
            }
    }
}

extension View {
    /// Attach once, at the root, next to `standRedemption`.
    func standPresentation(appState: AppState) -> some View {
        modifier(StandPresentationModifier(appState: appState))
    }
}

// MARK: - Save your stand

/// Offered after somebody's first day inside a stand, at most three times ever.
///
/// An anonymous account lives in this device's Keychain. It survives a
/// reinstall but does NOT move to a new phone, so without this the stand they
/// just started is one lost phone away from gone — and they would never know
/// until it was.
struct StandUpgradePromptSheet: View {

    @ObservedObject private var auth = StandAuthCoordinator.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Gradients().speakLifeCYOCell.ignoresSafeArea()
            VStack(spacing: DS.Spacing.lg) {
                Spacer()
                Text("🔒").font(.system(size: 48))
                Text("Save your stand")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundColor(DS.Palette.textPrimary)
                Text("Sign in so this follows you to any device. Right now it only lives on this phone.")
                    .font(DS.Typography.body)
                    .foregroundColor(DS.Palette.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, DS.Spacing.md)
                Spacer()

                Button {
                    // AppleSignInService routes through StandAuthCoordinator,
                    // so the anonymous uid is linked rather than abandoned.
                    AppleSignInService.shared.signIn()
                    dismiss()
                } label: {
                    Label("Sign in with Apple", systemImage: "apple.logo")
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DS.Spacing.sm)
                        .background(Capsule().fill(.white))
                }

                Button("Not now") { dismiss() }
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(DS.Palette.textSecondary)
                    .padding(.bottom, DS.Spacing.md)
            }
            .padding(DS.Spacing.md)
        }
        .presentationDetents([.medium])
    }
}
