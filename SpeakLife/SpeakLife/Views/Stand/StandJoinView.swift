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
    @State private var conflict: StandJoinConflict?
    @State private var joinedRoomId: String?
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
        .sheet(item: Binding(
            get: { conflict.map { ConflictBox(value: $0) } },
            set: { if $0 == nil { conflict = nil } }
        )) { box in
            StandConflictSheet(conflict: box.value) { decision in
                conflict = nil
                finishJoin(decision: decision)
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

            joinedRoomId = outcome.roomId
            joinedEnforcement = outcome.enforcement
            if case .clear = decision {
                finishJoin(decision: .clear)
            } else if case .sameCampaign = decision {
                finishJoin(decision: .sameCampaign)
            } else {
                // Anything that would disturb a campaign in flight is the
                // user's call, never the app's.
                conflict = decision
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
private struct ConflictBox: Identifiable {
    let id = UUID()
    let value: StandJoinConflict
}
