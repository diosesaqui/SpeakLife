//
//  OnboardingProductExperienceScreen.swift
//  SpeakLife
//
//  Shared pre-paywall "product capability" screen. Lifted out of
//  ProductOnboardingView so multiple onboarding flows can reuse the same source
//  (avoids two copies drifting). Used by:
//    - Product flow (value screen #4, "Good experience")
//    - Warfare flow (pre-paywall recap, after the rating ask) — shows the
//      tangible features right before the purchase decision to de-risk the ask.
//

import SwiftUI

struct OnboardingProductExperienceScreen: View {
    let size: CGSize
    /// Which onboarding flow is showing this screen ("product" | "warfare").
    /// Stamped onto `product_experience_shown` so the funnels can tell them apart.
    let flow: String
    let onContinue: () -> Void
    @State private var v = false

    private let features: [(icon: String, title: String, body: String)] = [
        ("waveform", "Speak it out loud", "Declarations are made to be spoken, not just read. Open your mouth over your situation and watch what shifts."),
        ("bubble.left.and.bubble.right.fill", "Bible Chat", "Ask anything and get answers rooted in Scripture. Like having a wise friend in the Word, any hour of the day."),
        ("headphones", "Listen anywhere", "Press play and let Scripture wash over you. Hands-free declarations for the commute, the gym, or a sleepless night."),
        ("car", "Built for real life", "Use it in the car, before a hard conversation, or late at night. Simple when everything else feels heavy.")
    ]

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    Spacer().frame(height: size.height * 0.12)

                    VStack(spacing: 12) {
                        Text("Built for the middle\nof the storm.")
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .appearStagger(v)

                        Text("No friction when you're at your lowest.\nJust the Word, the moment you need it.")
                            .font(.system(size: 16, weight: .regular, design: .rounded))
                            .foregroundColor(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                            .padding(.horizontal, 24)
                            .fixedSize(horizontal: false, vertical: true)
                            .appearStagger(v, delay: 0.12)
                    }
                    .padding(.horizontal, 28)

                    VStack(spacing: 12) {
                        ForEach(Array(features.enumerated()), id: \.offset) { idx, feature in
                            featureRow(feature)
                                .appearStagger(v, delay: 0.22 + Double(idx) * 0.1)
                        }
                    }
                    .padding(.horizontal, 24)

                    Spacer().frame(height: 8)
                }
            }

            ProductContinueButton(label: "Continue →") { onContinue() }
                .padding(.top, 8).padding(.bottom, 36)
                .appearStagger(v, delay: 0.52)
        }
        .onAppear {
            AnalyticsService.shared.track("product_experience_shown", parameters: ["flow": flow])
            withAnimation { v = true }
        }
    }

    private func featureRow(_ feature: (icon: String, title: String, body: String)) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.12))
                    .frame(width: 46, height: 46)
                Image(systemName: feature.icon)
                    .font(.system(size: 20))
                    .foregroundColor(.white)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(feature.title)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                Text(feature.body)
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundColor(.white.opacity(0.6))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        )
    }
}

// File-private staggered fade/rise modifier (each onboarding file keeps its own
// copy of this helper; duplicated here so this screen is self-contained).
private struct AppearStagger: ViewModifier {
    let shown: Bool
    let delay: Double
    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : 16)
            .animation(.easeOut(duration: 0.55).delay(delay), value: shown)
    }
}

private extension View {
    func appearStagger(_ shown: Bool, delay: Double = 0) -> some View {
        modifier(AppearStagger(shown: shown, delay: delay))
    }
}
