//
//  EnforcementCompletionView.swift
//  SpeakLife
//
//  Day 7. The moment a finite challenge ends is exactly where people drift, so
//  the next Enforcement is offered before the user has left the screen.
//

import SwiftUI

struct EnforcementCompletionView: View {
    let completed: Enforcement
    let nextOptions: [Enforcement]
    let isPremium: Bool

    let onStartNext: (Enforcement) -> Void
    let onDone: () -> Void

    @State private var showConfetti = false

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

                Button(action: onDone) {
                    Text("Done")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.7))
                        .padding(.vertical, 12)
                }
                .padding(.bottom, DS.Spacing.md)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.3)) { showConfetti = true }
        }
    }
}
