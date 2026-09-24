//
//  StandRoomView.swift
//  SpeakLife
//
//  The room: who is standing with you, and who has spoken today.
//
//  THE DESIGN RULE THIS SCREEN ENFORCES (spec §1):
//
//      Report presence, never absence.
//
//  There is no "behind" state, no red, no missed-day marker and no ordering by
//  progress. A member on day 2 next to a member on day 6 are both simply
//  standing. `dayNumber` is per member and campaigns wait rather than expire,
//  so "behind" is not even a coherent idea here — and the moment the UI invents
//  one, this becomes a scoreboard and stops carrying the person having the
//  hardest week of their year.
//

import SwiftUI
import SpeakLifeCore

struct StandRoomView: View {

    let roomId: String

    @ObservedObject private var service = StandService.shared
    @ObservedObject private var auth = StandAuthCoordinator.shared

    @State private var showInvite = false
    @State private var showLeaveConfirm = false
    @State private var showUpgradePrompt = false
    @Environment(\.dismiss) private var dismiss

    private var room: StandRoom? { service.rooms.first { $0.id == roomId } }
    private var todayStamp: String { StandDayStamp.stamp() }

    var body: some View {
        ZStack {
            Gradients().speakLifeCYOCell.ignoresSafeArea()

            if let room {
                content(room)
            } else if service.isLoading {
                ProgressView().tint(.white)
            } else {
                missingRoom
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    if room?.member(auth.currentUid ?? "")?.isOwner == true {
                        Button("Invite someone") { showInvite = true }
                    }
                    Button("Leave this stand", role: .destructive) { showLeaveConfirm = true }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showInvite) {
            if let room { StandInviteSheet(room: room) }
        }
        // Was set, and the 3-prompt budget spent, with nothing presenting it.
        .sheet(isPresented: $showUpgradePrompt) {
            StandUpgradePromptSheet()
        }
        .confirmationDialog("Leave this stand?",
                            isPresented: $showLeaveConfirm, titleVisibility: .visible) {
            Button("Leave", role: .destructive) { leave() }
            Button("Stay", role: .cancel) {}
        } message: {
            Text("The others will keep going. You can be invited back.")
        }
        .onAppear {
            service.startListening()
            AnalyticsService.shared.trackScreenView("stand_room", metadata: ["room_id": roomId])
            maybePromptUpgrade()
        }
    }

    // MARK: - Content

    @ViewBuilder
    private func content(_ room: StandRoom) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                header(room)
                todayAnchor(room)
                roster(room)
                if room.activeMembers.count == 1 { aloneSoFar(room) }
                Spacer(minLength: DS.Spacing.xl)
            }
            .padding(DS.Spacing.md)
        }
    }

    private func header(_ room: StandRoom) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Text(room.enforcement.displayTitle.uppercased())
                .font(.system(size: 12, weight: .bold))
                .tracking(1.4)
                .foregroundColor(DS.Palette.gold.opacity(0.9))

            Text(room.presenceSummary(todayStamp: todayStamp, viewer: auth.currentUid))
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(DS.Palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Today's line, from the room's campaign rather than the local one — every
    /// member speaks the same words on their own day N.
    @ViewBuilder
    private func todayAnchor(_ room: StandRoom) -> some View {
        // From days spoken here, not the stored `dayNumber` — see
        // `StandMember.standDay`. The two disagree in any room written by a
        // build older than `dayToRecord`, and this header is one of the places
        // that showed it.
        //
        // Once today is spoken the header shows TODAY's day, the one just
        // spoken — not tomorrow's. It used to always read one ahead, so a
        // member who had spoken read "DAY 3 OF 7" directly above their own row
        // saying "Day 2 of 7".
        let me = room.member(auth.currentUid ?? "")
        let spoken = me?.standDay ?? 0
        let spokeToday = me?.spoke(on: todayStamp) ?? false
        let myDay = max(spokeToday ? spoken : spoken + 1, 1)
        if let day = room.enforcement.day(min(myDay, Enforcement.length)) {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                Text("DAY \(min(myDay, Enforcement.length)) OF \(Enforcement.length)")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1.2)
                    .foregroundColor(DS.Palette.textSecondary)

                Text(day.anchorText)
                    .font(.system(size: 19, weight: .semibold, design: .rounded))
                    .foregroundColor(DS.Palette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(day.anchorBook)
                    .font(DS.Typography.caption)
                    .foregroundColor(DS.Palette.textSecondary)
            }
            .padding(DS.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .dsGlass(cornerRadius: DS.Radius.lg,
                     strokeOpacity: 0.16,
                     elevation: DS.Elevation.medium)
        }
    }

    private func roster(_ room: StandRoom) -> some View {
        VStack(spacing: DS.Spacing.sm) {
            ForEach(room.activeMembers) { member in
                StandMemberRow(
                    member: member,
                    isYou: member.uid == auth.currentUid,
                    todayStamp: todayStamp
                )
            }
        }
    }

    /// A stand of one is the normal state between tapping Invite and the other
    /// person accepting, so it reads as anticipation rather than failure.
    ///
    /// It also states the rule `dayToRecord` enforces: the shared week is held
    /// at zero until somebody else is standing, so both members read Day 1 on
    /// the same day rather than the invitee starting a week behind.
    private func aloneSoFar(_ room: StandRoom) -> some View {
        VStack(spacing: DS.Spacing.sm) {
            Text("Your seven days start when they do.")
                .font(DS.Typography.callout)
                .foregroundColor(DS.Palette.textSecondary)
            Button {
                showInvite = true
            } label: {
                Text("Send the invite again")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(DS.Palette.textPrimary)
                    .padding(.horizontal, DS.Spacing.md)
                    .padding(.vertical, DS.Spacing.sm)
                    .background(Capsule().fill(DS.Palette.surface))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, DS.Spacing.sm)
    }

    private var missingRoom: some View {
        VStack(spacing: DS.Spacing.sm) {
            Text("This stand is no longer available.")
                .font(DS.Typography.body)
                .foregroundColor(DS.Palette.textPrimary)
            Button("Back") { dismiss() }
                .foregroundColor(DS.Palette.gold)
        }
        .padding(DS.Spacing.lg)
    }

    // MARK: - Actions

    private func leave() {
        Task {
            try? await service.leaveStand(roomId: roomId)
            dismiss()
        }
    }

    /// An anonymous account lives in this device's Keychain: it survives a
    /// reinstall but does not move to a new phone. Ask once they have a stand
    /// worth keeping, never before.
    private func maybePromptUpgrade() {
        guard auth.shouldPromptUpgrade,
              let room, room.member(auth.currentUid ?? "")?.hasStarted == true else { return }
        auth.recordUpgradePromptShown()
        showUpgradePrompt = true
    }
}

// MARK: - Member row

struct StandMemberRow: View {

    let member: StandMember
    let isYou: Bool
    let todayStamp: String

    private var spokeToday: Bool { member.spoke(on: todayStamp) }

    var body: some View {
        HStack(spacing: DS.Spacing.sm) {
            avatar

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: DS.Spacing.xxs) {
                    Text(isYou ? "You" : member.displayName)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(DS.Palette.textPrimary)
                    if member.isOwner {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 10))
                            .foregroundColor(DS.Palette.gold.opacity(0.8))
                    }
                }
                Text(dayLabel)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(DS.Palette.textSecondary)
            }

            Spacer(minLength: DS.Spacing.xs)
            weekStrip
        }
        .padding(DS.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                .fill(DS.Palette.surface)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
    }

    private var avatar: some View {
        ZStack {
            Circle()
                .fill(Self.palette[member.colorIndex % Self.palette.count].opacity(0.85))
                .frame(width: 40, height: 40)
            Text(member.displayInitial)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundColor(.white)
        }
        .overlay(
            // Spoken today reads as a quiet gold ring. There is deliberately no
            // counterpart for not-spoken: absence is never marked.
            Circle()
                .stroke(DS.Palette.gold, lineWidth: spokeToday ? 2 : 0)
                .frame(width: 46, height: 46)
        )
    }

    private var dayLabel: String {
        member.hasStarted
            ? "Day \(member.standDay) of \(Enforcement.length)"
            : "Just joined"
    }

    /// The seven days of THIS stand, filled up to the days spoken.
    ///
    /// It used to be the last seven calendar days with a dot per day spoken.
    /// Next to "Day 2 of 7" that read as a seven-day progress rail, so today's
    /// dot at the far right looked like day 7 already done, and a gap between
    /// two dots marked a missed day — the absence this screen promises never
    /// to show. Filling from the left matches the number beside it; who spoke
    /// TODAY is already the gold ring on the avatar.
    private var weekStrip: some View {
        HStack(spacing: 5) {
            ForEach(1...Enforcement.length, id: \.self) { day in
                Circle()
                    .fill(day <= member.standDay
                          ? DS.Palette.gold
                          : Color.white.opacity(0.14))
                    .frame(width: 8, height: 8)
            }
        }
        .accessibilityHidden(true)
    }

    private var accessibilityText: String {
        let who = isYou ? "You" : member.displayName
        let spoke = spokeToday ? "spoke today" : "has not spoken today"
        return "\(who), \(dayLabel), \(spoke)"
    }

    /// Eight stable colours. `colorIndex` is derived server-side from a hash of
    /// the uid, so a person keeps the same colour in every room and on every
    /// device.
    static let palette: [Color] = [
        Color(hex: "#7C3AED"), Color(hex: "#0EA5E9"), Color(hex: "#059669"),
        Color(hex: "#D97706"), Color(hex: "#DC2626"), Color(hex: "#0D9488"),
        Color(hex: "#B7791F"), Color(hex: "#4F46E5"),
    ]
}
