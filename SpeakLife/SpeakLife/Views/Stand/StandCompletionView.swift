//
//  StandCompletionView.swift
//  SpeakLife
//
//  Day 7, together.
//
//  This is the best conversion moment the app has and it is also the moment
//  most easily ruined. They just finished something hard with somebody they
//  love. So: the celebration lands first and completely, the share comes
//  second, and the paywall is never the first thing on screen — an invitee
//  whose Stand Pass is expiring sees an offer only after the moment has been
//  given room (spec §10).
//

import SwiftUI
import SpeakLifeCore

struct StandCompletionView: View {

    let room: StandRoom
    let onDismiss: () -> Void

    @State private var shareImage: UIImage?
    @State private var appeared = false

    private var names: [String] {
        room.activeMembers
            .filter { $0.uid != StandAuthCoordinator.shared.currentUid }
            .map(\.displayName)
    }

    var body: some View {
        ZStack {
            Gradients().speakLifeCYOCell.ignoresSafeArea()

            VStack(spacing: DS.Spacing.lg) {
                Spacer()

                Text("SEVEN DAYS")
                    .font(.system(size: 13, weight: .bold))
                    .tracking(3)
                    .foregroundColor(DS.Palette.gold)

                Text(room.enforcement.displayTitle)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundColor(DS.Palette.textPrimary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Text(togetherLine)
                    .font(DS.Typography.body)
                    .foregroundColor(DS.Palette.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                avatars

                Spacer()

                if let shareImage {
                    ShareLink(item: Image(uiImage: shareImage),
                              preview: SharePreview("Seven days",
                                                    image: Image(uiImage: shareImage))) {
                        Label("Share this", systemImage: "square.and.arrow.up")
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, DS.Spacing.sm)
                            .background(Capsule().fill(DS.Palette.gold))
                    }
                }

                Button("Done") { onDismiss() }
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(DS.Palette.textSecondary)
                    .padding(.bottom, DS.Spacing.md)
            }
            .padding(DS.Spacing.md)
            .opacity(appeared ? 1 : 0)
            .scaleEffect(appeared ? 1 : 0.94)
        }
        .onAppear {
            withAnimation(DS.Motion.bouncy) { appeared = true }
            PremiumHaptics.success()
            shareImage = StandInviteCardRenderer.renderCompletion(
                title: room.enforcement.displayTitle,
                names: names)
            AnalyticsService.shared.track("stand_completed_shown", parameters: [
                "room_id": room.id,
                "member_count": room.activeMembers.count,
            ])
        }
    }

    private var togetherLine: String {
        let others = names
        switch others.count {
        case 0:  return "You held the whole week."
        case 1:  return "You and \(others[0]) held the whole week."
        case 2:  return "You, \(others[0]) and \(others[1]) held the whole week."
        default: return "You and \(others.count) others held the whole week."
        }
    }

    private var avatars: some View {
        HStack(spacing: -DS.Spacing.xs) {
            ForEach(room.activeMembers.prefix(6)) { member in
                ZStack {
                    Circle()
                        .fill(StandMemberRow.palette[member.colorIndex % StandMemberRow.palette.count])
                        .frame(width: 48, height: 48)
                    Text(member.displayInitial)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                .overlay(Circle().stroke(Color.black.opacity(0.35), lineWidth: 3))
            }
            if room.activeMembers.count > 6 {
                Text("+\(room.activeMembers.count - 6)")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(DS.Palette.textSecondary)
                    .padding(.leading, DS.Spacing.sm)
            }
        }
        .padding(.top, DS.Spacing.sm)
    }
}
