//
//  StandListView.swift
//  SpeakLife
//
//  Every stand this person is in or has held. Reached from Profile → My Stands.
//
//  Low discovery by design — the campaign card and the day-1 prompt are where
//  people actually find the feature (spec §9.5). This exists because both of
//  those disappear when a campaign ends, and a week somebody held with their
//  mother should not become unreachable the moment it finishes.
//

import SwiftUI
import SpeakLifeCore

struct StandListView: View {

    @ObservedObject private var service = StandService.shared
    @Environment(\.dismiss) private var dismiss

    private var active: [StandRoom] { service.rooms.filter { $0.status == .active } }
    private var past: [StandRoom] { service.rooms.filter { $0.status != .active } }

    var body: some View {
        ZStack {
            Gradients().speakLifeCYOCell.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                    if !active.isEmpty { section("STANDING NOW", rooms: active) }
                    if !past.isEmpty { section("HELD", rooms: past) }
                    if service.rooms.isEmpty { empty }
                }
                .padding(DS.Spacing.md)
            }
        }
        .navigationTitle("My Stands")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { dismiss() }.foregroundColor(DS.Palette.gold)
            }
        }
        .onAppear { service.startListening() }
    }

    private func section(_ title: String, rooms: [StandRoom]) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .tracking(1.3)
                .foregroundColor(DS.Palette.textSecondary)

            ForEach(rooms) { room in
                NavigationLink(destination: StandRoomView(roomId: room.id)) {
                    row(room)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }

    private func row(_ room: StandRoom) -> some View {
        HStack(spacing: DS.Spacing.sm) {
            VStack(alignment: .leading, spacing: 4) {
                Text(room.enforcement.displayTitle)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(DS.Palette.textPrimary)
                Text(subtitle(room))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(DS.Palette.textSecondary)
            }
            Spacer(minLength: DS.Spacing.xs)
            HStack(spacing: -6) {
                ForEach(room.activeMembers.prefix(4)) { member in
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
        .padding(DS.Spacing.sm)
        .background(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
            .fill(DS.Palette.surface))
    }

    private func subtitle(_ room: StandRoom) -> String {
        switch room.status {
        case .active:
            return room.presenceSummary(todayStamp: StandDayStamp.stamp(),
                                        viewer: StandAuthCoordinator.shared.currentUid)
        case .completed:
            // Named as finished, never as over. Seven days held together is the
            // thing this whole feature exists to produce.
            return "Seven days, together."
        case .dormant:
            return "Waiting for you. Campaigns don't expire."
        case .archived:
            return "Archived."
        }
    }

    private var empty: some View {
        VStack(spacing: DS.Spacing.sm) {
            Text("You're not standing with anyone yet.")
                .font(DS.Typography.body)
                .foregroundColor(DS.Palette.textPrimary)
            Text("Start a seven-day campaign, then invite someone into it.")
                .font(DS.Typography.callout)
                .foregroundColor(DS.Palette.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, DS.Spacing.xl)
    }
}
