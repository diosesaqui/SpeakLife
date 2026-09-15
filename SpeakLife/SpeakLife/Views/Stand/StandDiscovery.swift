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

struct StandInviteRow: View {

    let enforcement: Enforcement
    @ObservedObject private var service = StandService.shared
    @State private var showInvite = false
    @State private var isCreating = false
    @State private var createdRoom: StandRoom?

    private var existingRoom: StandRoom? {
        service.rooms.first { $0.status == .active && $0.enforcement.id == enforcement.id }
    }

    var body: some View {
        if FeatureFlag.standTogetherEnabled {
            Button {
                if existingRoom != nil {
                    showInvite = true
                } else {
                    Task { await createStand() }
                }
            } label: {
                HStack(spacing: DS.Spacing.xs) {
                    if let room = existingRoom, room.activeMembers.count > 1 {
                        avatars(room)
                        Text(room.presenceSummary(todayStamp: StandDayStamp.stamp()))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                    } else {
                        Image(systemName: isCreating ? "hourglass" : "person.2.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(DS.Palette.gold.opacity(0.9))
                        Text(existingRoom == nil ? "Stand with me" : "Invite someone")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.85))
                    }
                    Spacer(minLength: 0)
                }
                .padding(.vertical, DS.Spacing.xxs)
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(isCreating)
            .sheet(isPresented: $showInvite) {
                if let room = existingRoom ?? createdRoom {
                    StandInviteSheet(room: room)
                }
            }
        }
    }

    private func avatars(_ room: StandRoom) -> some View {
        HStack(spacing: -6) {
            ForEach(room.activeMembers.prefix(4)) { member in
                ZStack {
                    Circle()
                        .fill(StandMemberRow.palette[member.colorIndex % StandMemberRow.palette.count])
                        .frame(width: 20, height: 20)
                    Text(member.displayInitial)
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                .overlay(Circle().stroke(Color.black.opacity(0.35), lineWidth: 1.5))
            }
        }
    }

    private func createStand() async {
        isCreating = true
        defer { isCreating = false }
        if let room = await StandInviteLauncher.createRoom(for: enforcement) {
            createdRoom = room
            showInvite = true
        }
    }
}

// MARK: - Shared launch flow

/// Creating a stand and getting to something shareable, in one place.
///
/// Both the persistent row and the day-1 prompt need it. An earlier version had
/// the row own it while the prompt set a flag the row was supposed to notice —
/// which was never wired up, so the prompt's only button would have done
/// nothing at all.
@MainActor
enum StandInviteLauncher {

    /// Mints a room and returns it once the listener has delivered it.
    ///
    /// Tapping Invite has to create the room, because there is no code to share
    /// until one exists. Somebody who taps and never sends leaves a one-member
    /// orphan, which `standSweep` collects after 14 days.
    ///
    /// Waits for the listener rather than building a local stand-in, so every
    /// surface renders the same object.
    static func createRoom(for enforcement: Enforcement) async -> StandRoom? {
        do {
            _ = try await StandAuthCoordinator.shared.ensureAccount()
            let name = UserDefaults.standard.string(forKey: "userName") ?? "Friend"
            let result = try await StandService.shared.createStand(
                enforcement: enforcement, name: name)

            for _ in 0..<20 {
                if let room = StandService.shared.rooms.first(where: { $0.id == result.roomId }) {
                    return room
                }
                try? await Task.sleep(nanoseconds: 150_000_000)
            }
            return nil
        } catch {
            print("⚠️ Stand create failed: \(error.localizedDescription)")
            return nil
        }
    }

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

    @State private var isCreating = false
    @State private var room: StandRoom?

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

                Button {
                    Task {
                        isCreating = true
                        room = StandInviteLauncher.existingRoom(for: enforcement)
                            ?? (await StandInviteLauncher.createRoom(for: enforcement))
                        isCreating = false
                    }
                } label: {
                    HStack {
                        if isCreating { ProgressView().tint(.black) }
                        Text(isCreating ? "One moment…" : "Invite someone")
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DS.Spacing.sm)
                    .background(Capsule().fill(DS.Palette.gold))
                }
                .disabled(isCreating)

                Button("Maybe later") { dismiss() }
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(DS.Palette.textSecondary)
                    .padding(.bottom, DS.Spacing.md)
            }
            .padding(DS.Spacing.md)
        }
        .presentationDetents([.medium])
        .sheet(item: $room) { StandInviteSheet(room: $0) }
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

    @EnvironmentObject var appState: AppState
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
    /// Attach once, at the root, below onboarding.
    func standRedemption() -> some View {
        modifier(StandRedemptionModifier())
    }
}
