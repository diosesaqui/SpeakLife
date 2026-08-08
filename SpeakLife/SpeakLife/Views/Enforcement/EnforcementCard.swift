//
//  EnforcementCard.swift
//  SpeakLife
//
//  The Enforcement's home on the Today tab. Four states: locked (non-premium),
//  invitation, active, and nothing at all when the user isn't yet eligible.
//
//  Tone note: this card is an invitation, never an obligation. No badge dot, no
//  unread count, no red. A user with a 200-day streak should never feel they've
//  fallen behind on something that didn't exist yesterday.
//

import SwiftUI

struct EnforcementCard: View {
    @ObservedObject var service: EnforcementService

    let isPremium: Bool
    let totalDaysCompleted: Int

    /// Premium user picked a theme.
    let onStart: (Enforcement) -> Void
    /// Active user tapped into today's audio.
    let onOpenAudio: (EnforcementDay) -> Void
    /// Non-premium user tapped anywhere on the locked card.
    let onLockedTap: () -> Void
    /// Active user chose to drop this campaign and pick a different one.
    let onSwitch: () -> Void

    /// Confirms before dropping a campaign — the days already spoken are lost,
    /// and it sits next to the audio button, so a mis-tap must not wipe progress.
    @State private var confirmingSwitch = false

    var body: some View {
        if service.isEligible(totalDaysCompleted: totalDaysCompleted) {
            Group {
                if let enforcement = service.activeEnforcement, let day = service.activeDay {
                    activeCard(enforcement: enforcement, day: day)
                } else if isPremium {
                    invitationCard
                } else {
                    lockedCard
                }
            }
            .padding(DS.Spacing.md)
            .dsGlass(cornerRadius: DS.Radius.lg, strokeOpacity: 0.16, elevation: DS.Elevation.medium)
        }
    }

    // MARK: - Active

    @ViewBuilder
    private func activeCard(enforcement: Enforcement, day: EnforcementDay) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            eyebrow("DAY \(service.progress.currentDay) OF \(Enforcement.length) · \(enforcement.title.uppercased())")
                .accessibilityHidden(true)

            dayRail

            Text(day.anchorText)
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
                .fixedSize(horizontal: false, vertical: true)

            Text(day.anchorBook)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.55))

            HStack(spacing: DS.Spacing.xs) {
                Button {
                    onOpenAudio(day)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 16, weight: .semibold))
                        Text("\(day.audioTitle) · \(day.audioMinutes) min")
                            .font(.system(size: 14, weight: .semibold))
                            .lineLimit(1)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, DS.Spacing.sm)
                    .padding(.vertical, 9)
                    .background(Capsule().fill(Color.white.opacity(0.14)))
                    .overlay(Capsule().stroke(Color.white.opacity(0.22), lineWidth: 1))
                }
                .buttonStyle(PlainButtonStyle())
                .accessibilityLabel("Play today's audio, \(day.audioTitle)")

                Spacer(minLength: 0)

                // The way out. Without this, picking the wrong theme locks the
                // user into it for seven days with no exit.
                Button {
                    confirmingSwitch = true
                } label: {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.65))
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(Color.white.opacity(0.10)))
                        .overlay(Circle().stroke(Color.white.opacity(0.18), lineWidth: 1))
                }
                .buttonStyle(PlainButtonStyle())
                .accessibilityLabel("Switch to a different enforcement")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .confirmationDialog("Switch enforcement?",
                            isPresented: $confirmingSwitch, titleVisibility: .visible) {
            Button("Switch", role: .destructive, action: onSwitch)
            Button("Keep going", role: .cancel) { }
        } message: {
            Text("You're on day \(service.progressSnapshot.currentDay) of \(Enforcement.length). Switching starts a new one from day 1.")
        }
    }

    /// Seven dots: filled for days done, ringed for today, hollow ahead.
    private var dayRail: some View {
        HStack(spacing: 7) {
            ForEach(1...Enforcement.length, id: \.self) { day in
                let done = service.progress.completedDayNumbers.contains(day)
                let isToday = day == service.progress.currentDay
                Circle()
                    .fill(done ? AnyShapeStyle(DS.Gradient.gold) : AnyShapeStyle(Color.white.opacity(0.14)))
                    .frame(width: 11, height: 11)
                    .overlay(
                        Circle().stroke(
                            isToday ? DS.Palette.gold : Color.white.opacity(0.22),
                            lineWidth: isToday ? 2 : 1
                        )
                    )
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement()
        .accessibilityLabel("Day \(service.progress.currentDay) of \(Enforcement.length)")
    }

    // MARK: - Invitation

    private var invitationCard: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            eyebrow("ENFORCE THE VICTORY")

            Text("Seven days standing on what Jesus already won.")
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.92))
                .fixedSize(horizontal: false, vertical: true)

            // The theme matching their strongest onboarding signal leads, but
            // every theme stays one tap away — this is a suggestion, not a route.
            let recommended = service.recommendedEnforcement()
            themeChips { enforcement in
                Button { onStart(enforcement) } label: {
                    chipLabel(enforcement.themeName, locked: false,
                              highlighted: enforcement.id == recommended?.id)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Locked

    private var lockedCard: some View {
        Button(action: onLockedTap) {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                HStack(spacing: 6) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(DS.Palette.gold.opacity(0.9))
                    eyebrow("ENFORCE THE VICTORY")
                }

                Text("Seven days standing on what Jesus already won.")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.92))
                    .fixedSize(horizontal: false, vertical: true)

                // Themes stay legible so the user can see exactly what's behind
                // the paywall before deciding.
                themeChips { enforcement in
                    chipLabel(enforcement.themeName, locked: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel("Enforce the victory. Premium feature. Tap to learn more.")
    }

    // MARK: - Shared pieces

    private func eyebrow(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .bold))
            .tracking(1.4)
            .foregroundColor(DS.Palette.gold.opacity(0.9))
            .lineLimit(1)
    }

    /// Wraps the catalog into two rows so four theme names never crowd.
    @ViewBuilder
    private func themeChips<Chip: View>(@ViewBuilder chip: @escaping (Enforcement) -> Chip) -> some View {
        let enforcements = service.catalog
        VStack(spacing: 8) {
            ForEach(Array(stride(from: 0, to: enforcements.count, by: 2)), id: \.self) { start in
                HStack(spacing: 8) {
                    ForEach(enforcements[start..<min(start + 2, enforcements.count)]) { enforcement in
                        chip(enforcement)
                    }
                }
            }
        }
    }

    private func chipLabel(_ title: String, locked: Bool, highlighted: Bool = false) -> some View {
        Text(title)
            .font(.system(size: 14, weight: .semibold, design: .rounded))
            .foregroundColor(locked ? .white.opacity(0.6) : .white)
            .lineLimit(1)
            .minimumScaleFactor(0.85)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous)
                    .fill(Color.white.opacity(locked ? 0.07 : (highlighted ? 0.20 : 0.13)))
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous)
                    .stroke(highlighted ? DS.Palette.gold.opacity(0.75)
                                        : Color.white.opacity(locked ? 0.12 : 0.22),
                            lineWidth: highlighted ? 1.5 : 1)
            )
    }
}
