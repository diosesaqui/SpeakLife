//
//  StandJoinView.swift
//  SpeakLife
//
//  The receive. Where an invite link or a typed code becomes membership.
//
//  This screen is the highest-intent moment in the whole feature: somebody has
//  been asked by a person they love and has said yes. Everything here is built
//  around not squandering that.
//
//   - `alreadyMember` is a SUCCESS. Tapping the same link twice, or opening it
//     on a second device, opens the room. An error at this moment reads as
//     "you're not welcome".
//   - The account is created silently. No Sign in with Apple wall in front of
//     an invitation from your mother — that is the entire reason anonymous auth
//     exists (spec §4).
//   - A campaign already in flight is never silently discarded. See
//     `StandConflictSheet`.
//

import SwiftUI
import SpeakLifeCore

struct StandJoinView: View {

    /// Prefilled from a deep link; empty when reached from the manual entry
    /// prompt after onboarding.
    @State var prefilledCode: String = ""

    @State private var typed = ""
    @State private var name = UserDefaults.standard.string(forKey: "userName") ?? ""
    @State private var isWorking = false
    @State private var errorText: String?
    /// The BOX, not the conflict.
    ///
    /// `ConflictBox` mints a fresh `UUID` on every init, and `.sheet(item:)`
    /// re-presents whenever the item's id changes. Built as a computed
    /// `Binding` whose `get` said `conflict.map { ConflictBox(value: $0) }`,
    /// every single body evaluation handed SwiftUI a new identity for the same
    /// conflict, so the sheet dismissed and re-presented in a loop. This view
    /// lives inside `StandRedemptionModifier`'s sheet, whose closure re-runs on
    /// every `AppState` publish, so those evaluations arrive constantly. Hold
    /// the identity in state and it is minted once.
    @State private var conflict: ConflictBox?
    @State private var joinedRoomId: String?
    /// The room to open once the conflict is resolved.
    ///
    /// Navigation used to be kicked off in the same transaction that presented
    /// the sheet, which pushed `StandRoomView` over the very view the sheet was
    /// anchored to. The decision is what determines the campaign that room
    /// shows, so it waits for it.
    @State private var pendingRoomId: String?
    /// The campaign `joinStand` returned. Held because the conflict sheet
    /// resolves asynchronously, and by the time the user answers, this is still
    /// the only copy of the campaign the client has.
    @State private var joinedEnforcement: Enforcement?

    @Environment(\.dismiss) private var dismiss

    private var code: String {
        prefilledCode.isEmpty ? typed : prefilledCode
    }

    /// Mirrors `normalizeCode` in functions/standTogether.js: strip separators,
    /// uppercase, then require eight characters from the alphabet. Both halves
    /// of each confusable pair (0/O, 1/I/L) are excluded, so a typed one cannot
    /// be valid under any reading and is rejected rather than guessed — guessing
    /// is how somebody lands in the wrong family's stand.
    private var normalized: String {
        code.uppercased().filter { $0.isLetter || $0.isNumber }
    }

    private var canSubmit: Bool {
        normalized.count == 8
            && normalized.allSatisfy { "ABCDEFGHJKMNPQRSTUVWXYZ23456789".contains($0) }
            && !name.trimmingCharacters(in: .whitespaces).isEmpty
            && !isWorking
    }

    var body: some View {
        ZStack {
            Gradients().speakLifeCYOCell.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                    header
                    if prefilledCode.isEmpty { codeField }
                    nameField
                    if let errorText { errorRow(errorText) }
                    submitButton
                }
                .padding(DS.Spacing.md)
            }
        }
        .navigationTitle("Stand together")
        .navigationBarTitleDisplayMode(.inline)
        // `onDismiss` carries every exit: a decision, "Not now", and a swipe
        // down. All three end in the room — they ARE a member by this point,
        // and the only question the sheet asked was what to do with the
        // campaign they were already running.
        .sheet(item: $conflict, onDismiss: enterRoom) { box in
            StandConflictSheet(conflict: box.value) { decision in
                finishJoin(decision: decision)
                conflict = nil
            }
        }
        .navigationDestination(item: $joinedRoomId) { id in
            StandRoomView(roomId: id)
        }
        .onAppear {
            AnalyticsService.shared.track("stand_invite_opened", parameters: [
                "source": prefilledCode.isEmpty ? "manual_code" : "link",
            ])
        }
    }

    // MARK: - Pieces

    private var header: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Text("SOMEONE ASKED YOU TO STAND WITH THEM")
                .font(.system(size: 11, weight: .bold))
                .tracking(1.3)
                .foregroundColor(DS.Palette.gold.opacity(0.9))
            Text("Seven days. The same word, spoken together.")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(DS.Palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var codeField: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Text("INVITE CODE")
                .font(.system(size: 10, weight: .bold))
                .tracking(1.2)
                .foregroundColor(DS.Palette.textSecondary)
            TextField("ABCD-2345", text: $typed)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .font(.system(size: 22, weight: .bold, design: .monospaced))
                .foregroundColor(DS.Palette.textPrimary)
                .padding(DS.Spacing.sm)
                .background(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                    .fill(DS.Palette.surface))
        }
    }

    private var nameField: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Text("WHAT SHOULD THEY CALL YOU?")
                .font(.system(size: 10, weight: .bold))
                .tracking(1.2)
                .foregroundColor(DS.Palette.textSecondary)
            TextField("First name", text: $name)
                .autocorrectionDisabled()
                .font(DS.Typography.body)
                .foregroundColor(DS.Palette.textPrimary)
                .padding(DS.Spacing.sm)
                .background(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                    .fill(DS.Palette.surface))
            Text("First name only. It's shown to everyone in the stand.")
                .font(.system(size: 11))
                .foregroundColor(DS.Palette.textSecondary.opacity(0.7))
        }
    }

    private func errorRow(_ text: String) -> some View {
        Text(text)
            .font(DS.Typography.callout)
            .foregroundColor(.white)
            .padding(DS.Spacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous)
                .fill(Color.red.opacity(0.28)))
    }

    private var submitButton: some View {
        Button {
            Task { await attemptJoin() }
        } label: {
            HStack {
                if isWorking { ProgressView().tint(.black) }
                Text(isWorking ? "Joining…" : "Stand with them")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
            }
            .foregroundColor(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, DS.Spacing.sm)
            .background(Capsule().fill(canSubmit ? DS.Palette.gold : Color.gray.opacity(0.4)))
        }
        .disabled(!canSubmit)
    }

    // MARK: - Join

    private func attemptJoin() async {
        isWorking = true
        errorText = nil
        do {
            // Silent account creation. The wall never appears here.
            _ = try await StandAuthCoordinator.shared.ensureAccount()

            let outcome = try await StandService.shared.joinStand(
                code: normalized,
                name: name.trimmingCharacters(in: .whitespaces))

            // Already in it — a second tap, or a second device. Straight in.
            if outcome.alreadyMember {
                remember(outcome.roomId)
                joinedRoomId = outcome.roomId
                joinedEnforcement = outcome.enforcement
                // A rejoin still needs the campaign if they are not running it —
                // after a reinstall they are a member of a room with nothing to
                // speak. Only when it is genuinely absent: never over a campaign
                // already in flight, which is the conflict sheet's job.
                if !EnforcementService.shared.progressSnapshot.isActive,
                   let enforcement = outcome.enforcement {
                    EnforcementService.shared.startShared(enforcement)
                }
                isWorking = false
                return
            }

            let decision = StandJoinResolver.resolve(
                roomEnforcementId: outcome.enforcement?.id ?? "",
                progress: EnforcementService.shared.progressSnapshot,
                active: EnforcementService.shared.activeEnforcement,
                hasUnseenCelebration: EnforcementService.shared.justCompleted != nil)

            remember(outcome.roomId)
            pendingRoomId = outcome.roomId
            joinedEnforcement = outcome.enforcement
            if case .clear = decision {
                finishJoin(decision: .clear)
                enterRoom()
            } else if case .sameCampaign = decision {
                finishJoin(decision: .sameCampaign)
                enterRoom()
            } else {
                // Anything that would disturb a campaign in flight is the
                // user's call, never the app's.
                conflict = ConflictBox(value: decision)
            }
        } catch {
            let standError = (error as? StandError) ?? StandError.unknown(error.localizedDescription)
            errorText = standError.errorDescription
            AnalyticsService.shared.track("stand_join_failed", parameters: [
                "reason": standError.analyticsReason,
            ])
        }
        isWorking = false
    }

    /// Ties this code to the room it opened, and keeps the name.
    ///
    /// Both halves exist because of the same dead end: tapping your own link
    /// again put the form back up with an empty name field and a disabled
    /// button. The code lets `StandRedemptionModifier` skip the form entirely
    /// next time; the name means that even where the form is right to appear —
    /// a second device — it is answerable rather than a wall.
    ///
    /// `userName` is the app's one name for this person and is already read by
    /// the checklist, notifications and `StandInviteSheet`. Only written when
    /// it is empty: what they call themselves in a stand does not get to
    /// overwrite the name they gave the app.
    private func remember(_ roomId: String) {
        StandRedeemedCodes.record(code: normalized, roomId: roomId)
        let typed = name.trimmingCharacters(in: .whitespaces)
        let stored = UserDefaults.standard.string(forKey: "userName") ?? ""
        if stored.isEmpty, !typed.isEmpty {
            UserDefaults.standard.set(typed, forKey: "userName")
        }
    }

    /// Pushes the room, once. Nothing to open means the conflict sheet was
    /// dismissed after navigation already happened, and re-assigning
    /// `joinedRoomId` there would push a second copy of the room.
    private func enterRoom() {
        guard let id = pendingRoomId else { return }
        pendingRoomId = nil
        joinedRoomId = id
    }

    /// Applies whatever the user agreed to.
    ///
    /// `.sameCampaign` deliberately does nothing: they are already running this
    /// campaign, and calling `startEnforcement` would route through `begin`,
    /// which clears `completedDayNumbers` and resets them to day 1 for the
    /// crime of joining a stand running the very week they are on.
    private func finishJoin(decision: StandJoinConflict) {
        switch decision {
        case .sameCampaign, .awaitingCelebration:
            break
        case .clear, .replaceEarly, .replaceLate:
            // The campaign comes from the callable's own response, NOT from
            // StandService.rooms. The listener has not delivered the room yet
            // at this point, so looking it up there found nothing and the
            // invitee joined a stand with no campaign at all — silently, since
            // the lookup was an `if let`.
            guard let enforcement = joinedEnforcement else { return }
            EnforcementService.shared.startShared(enforcement)
        }
    }
}

// MARK: - Sheet plumbing

/// `StandJoinConflict` is an enum with associated values, and `.sheet(item:)`
/// needs `Identifiable`. Boxed rather than making the domain type carry an id
/// it has no use for.
///
/// Construct it ONCE, into `@State`. The id is minted per instance, so building
/// one inside a computed `Binding`'s `get` — or anywhere else that re-runs on a
/// body evaluation — changes the item's identity on every pass and makes the
/// sheet dismiss and re-present in a loop.
private struct ConflictBox: Identifiable {
    let id = UUID()
    let value: StandJoinConflict
}
