//
//  EnforcementCompletionView.swift
//  SpeakLife
//
//  Day 7. The moment a finite challenge ends is exactly where people drift, so
//  the next Enforcement is offered before the user has left the screen.
//

import SwiftUI
import SpeakLifeCore

struct EnforcementCompletionView: View {
    let completed: Enforcement
    let nextOptions: [Enforcement]
    let isPremium: Bool
    /// The week of a stand they are already in, when it is not the one they
    /// just finished. Leads the screen: it is the thing they were waiting on.
    var standCampaign: Enforcement? = nil
    var onStartStand: () -> Void = {}

    let onStartNext: (Enforcement) -> Void
    let onDone: () -> Void

    @State private var showConfetti = false
    /// The campaign they chose to run with somebody. The invite sheet creates
    /// the stand itself, so a failure has a screen to land on instead of
    /// leaving this button doing nothing.
    @State private var standInviteFor: Enforcement?

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "#0B1026"), Color(hex: "#1B2350")],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            if showConfetti {
                ConfettiView().allowsHitTesting(false)
            }

            VStack(spacing: DS.Spacing.lg) {
                Spacer(minLength: 0)

                ModernCelebrationView(accentColor: DS.Palette.gold)
                    .frame(width: 140, height: 140)

                VStack(spacing: DS.Spacing.xs) {
                    Text("You finished")
                        .font(.system(size: 17, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.7))

                    // The celebration blob is persisted whole, so a week begun
                    // before the naming fix would be congratulated for
                    // finishing "Enforcing Warfare & Victory".
                    Text(completed.displayTitle)
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)

                    Text("Seven days standing on ground Jesus already took.")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white.opacity(0.75))
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, DS.Spacing.lg)

                Spacer(minLength: 0)

                // Not premium-gated: a stand runs on a Stand Pass as well.
                if let standCampaign {
                    VStack(spacing: DS.Spacing.sm) {
                        Text("YOUR STAND IS WAITING")
                            .font(.system(size: 11, weight: .bold))
                            .tracking(1.4)
                            .foregroundColor(DS.Palette.gold.opacity(0.9))

                        Button(action: onStartStand) {
                            HStack {
                                Image(systemName: "person.2.fill")
                                    .font(.system(size: 14, weight: .semibold))
                                Text("Start \(standCampaign.displayTitle)")
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.85)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 13, weight: .bold))
                                    .opacity(0.6)
                            }
                            .foregroundColor(.black)
                            .padding(.horizontal, DS.Spacing.md)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                                    .fill(DS.Palette.gold)
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.horizontal, DS.Spacing.lg)
                }

                if isPremium && !nextOptions.isEmpty {
                    VStack(spacing: DS.Spacing.sm) {
                        Text("ENFORCE THE NEXT ONE")
                            .font(.system(size: 11, weight: .bold))
                            .tracking(1.4)
                            .foregroundColor(DS.Palette.gold.opacity(0.9))

                        ForEach(nextOptions) { enforcement in
                            Button {
                                onStartNext(enforcement)
                            } label: {
                                HStack {
                                    Text(enforcement.displayTitle)
                                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 13, weight: .bold))
                                        .opacity(0.6)
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, DS.Spacing.md)
                                .padding(.vertical, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                                        .fill(Color.white.opacity(0.12))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal, DS.Spacing.lg)
                }

                // They have just held seven days and have proof it works.
                // This is where a finisher becomes an inviter (spec §9.5).
                if FeatureFlag.standTogetherEnabled, isPremium, let next = nextOptions.first {
                    Button {
                        standInviteFor = next
                    } label: {
                        Label("Run the next one with someone",
                              systemImage: "person.2.fill")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundColor(DS.Palette.gold)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(PlainButtonStyle())
                }

                Button(action: onDone) {
                    Text("Done")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.7))
                        .padding(.vertical, 12)
                }
                .padding(.bottom, DS.Spacing.md)
            }
        }
        .sheet(item: $standInviteFor) { StandInviteSheet(source: .newStand($0)) }
        .onAppear {
            withAnimation(.easeOut(duration: 0.3)) { showConfetti = true }
        }
    }
}
