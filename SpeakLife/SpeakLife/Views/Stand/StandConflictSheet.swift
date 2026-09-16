//
//  StandConflictSheet.swift
//  SpeakLife
//
//  The one screen standing between an invitation and somebody losing a week.
//
//  `EnforcementService.begin` clears `completedDayNumbers`, `startedOn` and
//  `lastAdvancedOn`. Every path that reaches it has to be one the person
//  explicitly agreed to, with the cost stated in plain words — "you're on day 4
//  of Enforcing Healing" — rather than a generic "this will replace your
//  current plan".
//
//  Day 3 is the line (`StandJoinResolver.lateThreshold`). Two days is a false
//  start. Three is a week somebody is holding on to, and that case gets a
//  third option: keep it, and join at day 0.
//

import SwiftUI
import SpeakLifeCore

struct StandConflictSheet: View {

    let conflict: StandJoinConflict
    let onDecision: (StandJoinConflict) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Gradients().speakLifeCYOCell.ignoresSafeArea()
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                Spacer(minLength: DS.Spacing.lg)
                headline
                body(for: conflict)
                Spacer()
                actions
            }
            .padding(DS.Spacing.md)
        }
        .presentationDetents([.medium])
    }

    private var headline: some View {
        Text(title)
            .font(.system(size: 24, weight: .bold, design: .rounded))
            .foregroundColor(DS.Palette.textPrimary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var title: String {
        switch conflict {
        case .replaceEarly, .replaceLate: return "You're already standing."
        case .awaitingCelebration:        return "You just finished one."
        case .clear, .sameCampaign:       return "Ready."
        }
    }

    @ViewBuilder
    private func body(for conflict: StandJoinConflict) -> some View {
        switch conflict {
        case .replaceEarly(let current, let day), .replaceLate(let current, let day):
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                // Named and numbered. A generic warning is how somebody taps
                // through and loses four days without registering it.
                Text("You're on day \(day) of \(current.displayTitle).")
                    .font(DS.Typography.body)
                    .foregroundColor(DS.Palette.textPrimary)
                Text(isLate
                     ? "Joining this stand starts a different seven days. You can finish yours first and join them from day one instead."
                     : "Joining this stand starts a different seven days.")
                    .font(DS.Typography.callout)
                    .foregroundColor(DS.Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

        case .awaitingCelebration:
            Text("Let's mark that first. Your stand will be waiting right after.")
                .font(DS.Typography.body)
                .foregroundColor(DS.Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

        case .clear, .sameCampaign:
            EmptyView()
        }
    }

    private var isLate: Bool {
        if case .replaceLate = conflict { return true }
        return false
    }

    private var actions: some View {
        VStack(spacing: DS.Spacing.sm) {
            switch conflict {
            case .replaceEarly, .replaceLate:
                primary("Start theirs") { onDecision(conflict) }
                if isLate {
                    // Joining at day 0 keeps the campaign they are holding. The
                    // shared one begins when that one finishes, and nothing is
                    // discarded in the meantime.
                    secondary("Finish mine first") { onDecision(.sameCampaign) }
                }
                secondary("Not now") { dismiss() }

            case .awaitingCelebration:
                primary("See it") { onDecision(.awaitingCelebration) }

            case .clear, .sameCampaign:
                primary("Let's go") { onDecision(conflict) }
            }
        }
    }

    private func primary(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DS.Spacing.sm)
                .background(Capsule().fill(DS.Palette.gold))
        }
    }

    private func secondary(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundColor(DS.Palette.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DS.Spacing.xs)
        }
    }
}
