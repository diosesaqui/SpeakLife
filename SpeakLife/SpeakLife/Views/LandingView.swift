//
//  LandingView.swift
//  SpeakLife
//
//  Premium cold-start branding screen. Sequenced entrance:
//    0.10s  glow + icon spring in (response 0.7, damping 0.78)
//    0.55s  wordmark settles up
//    0.90s  tagline fade
//    1.40s  one gentle breath cycle on the icon
//    2.10s  outgoing fade
//
//  Total budget: 2.5s, matched by SpeakLifeApp's dismiss timer.
//  ReduceMotion path skips particles + breath and crossfades the
//  final composition in 0.6s.
//

import SwiftUI

struct LandingView: View {
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var backgroundImage = "moonlight2"

    @State private var iconScale: CGFloat = 0.86
    @State private var iconOpacity: Double = 0
    @State private var iconBreath: CGFloat = 1.0

    @State private var glowScale: CGFloat = 0.7
    @State private var glowOpacity: Double = 0

    @State private var wordmarkOffset: CGFloat = 18
    @State private var wordmarkOpacity: Double = 0
    @State private var taglineOpacity: Double = 0

    @State private var contentOpacity: Double = 1.0

    var body: some View {
        ZStack {
            // Layer 1 — Branded background image (Remote Config-driven)
            Image(backgroundImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea()

            // Layer 2 — Dim vignette so the icon + glow read on any backdrop
            LinearGradient(
                colors: [
                    Color.black.opacity(0.15),
                    Color(red: 0.04, green: 0.06, blue: 0.15).opacity(0.55)
                ],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            // Layer 3 — Ambient particles (skipped under ReduceMotion)
            if !reduceMotion {
                AmbientParticleLayer()
                    .opacity(contentOpacity * 0.9)
                    .allowsHitTesting(false)
                    .ignoresSafeArea()
            }

            // Layer 4 — Glow + Icon + Wordmark + Tagline
            VStack(spacing: 22) {
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color(hex: "FBBF24").opacity(0.45),
                                    Color(hex: "F59E0B").opacity(0.18),
                                    Color(hex: "F59E0B").opacity(0)
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 200
                            )
                        )
                        .frame(width: 380, height: 380)
                        .scaleEffect(glowScale)
                        .opacity(glowOpacity)
                        .blur(radius: 6)

                    Image(uiImage: UIImage(named: "appIconDisplay") ?? UIImage())
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 132, height: 132)
                        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 30, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(0.35), radius: 24, x: 0, y: 14)
                        .scaleEffect(iconScale * iconBreath)
                        .opacity(iconOpacity)
                }

                VStack(spacing: 10) {
                    Text("SpeakLife")
                        .font(Font.custom("AppleSDGothicNeo-Bold", size: 42))
                        .kerning(0.6)
                        .foregroundColor(.white)
                        .shadow(color: Color.black.opacity(0.32), radius: 10, y: 3)
                        .offset(y: wordmarkOffset)
                        .opacity(wordmarkOpacity)

                    Text("Speak God's Word over your life.")
                        .font(Font.custom("AppleSDGothicNeo-Regular", size: 15))
                        .italic()
                        .foregroundColor(.white.opacity(0.82))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                        .shadow(color: Color.black.opacity(0.25), radius: 6, y: 2)
                        .opacity(taglineOpacity)
                }
            }
            .opacity(contentOpacity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
        .onAppear {
            backgroundImage = subscriptionStore.onboardingBGImage.isEmpty
                ? "moonlight2"
                : subscriptionStore.onboardingBGImage
            runEntranceSequence()
        }
    }

    // MARK: - Animation

    private func runEntranceSequence() {
        if reduceMotion {
            // Single calm crossfade; honor user's motion preferences.
            withAnimation(.easeOut(duration: 0.6)) {
                iconScale = 1.0
                iconOpacity = 1.0
                glowScale = 1.0
                glowOpacity = 0.85
                wordmarkOffset = 0
                wordmarkOpacity = 1.0
                taglineOpacity = 1.0
            }
            return
        }

        withAnimation(.spring(response: 0.7, dampingFraction: 0.78).delay(0.1)) {
            iconScale = 1.0
            iconOpacity = 1.0
            glowScale = 1.0
            glowOpacity = 0.88
        }

        withAnimation(.spring(response: 0.55, dampingFraction: 0.86).delay(0.55)) {
            wordmarkOffset = 0
            wordmarkOpacity = 1.0
        }

        withAnimation(.easeOut(duration: 0.55).delay(0.9)) {
            taglineOpacity = 1.0
        }

        // One unhurried breath: 1.0 → 1.025 → 1.0 across ~0.7s.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.40) {
            withAnimation(.easeInOut(duration: 0.35)) {
                iconBreath = 1.025
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                withAnimation(.easeInOut(duration: 0.35)) {
                    iconBreath = 1.0
                }
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.10) {
            withAnimation(.easeOut(duration: 0.4)) {
                contentOpacity = 0
            }
        }
    }
}

// MARK: - Ambient Particles

/// Slow upward drift of soft, blurred dots behind the icon. Each particle has
/// a randomized phase + speed so the field never looks like a marching grid.
/// Drawn with Canvas/TimelineView so motion is independent of SwiftUI's
/// state-driven animation pipeline — no `withAnimation` thrash, no scheduler
/// pressure during the entrance sequence.
private struct AmbientParticleLayer: View {
    private struct Particle {
        let x: CGFloat            // 0...1 of width
        let phase: Double         // 0...1 starting offset
        let speed: Double         // cycles per second
        let size: CGFloat
        let maxOpacity: Double
    }

    private let particles: [Particle]
    private let startDate = Date()

    init(count: Int = 16) {
        var generator = SystemRandomNumberGenerator()
        self.particles = (0..<count).map { _ in
            Particle(
                x: CGFloat.random(in: 0.04...0.96, using: &generator),
                phase: Double.random(in: 0...1, using: &generator),
                speed: Double.random(in: 0.05...0.12, using: &generator),
                size: CGFloat.random(in: 1.8...4.2, using: &generator),
                maxOpacity: Double.random(in: 0.32...0.62, using: &generator)
            )
        }
    }

    var body: some View {
        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSince(startDate)
            Canvas { ctx, size in
                for particle in particles {
                    var progress = (particle.phase + t * particle.speed)
                        .truncatingRemainder(dividingBy: 1.0)
                    if progress < 0 { progress += 1.0 }

                    let y = size.height * (1.0 - CGFloat(progress))
                    let x = size.width * particle.x
                    // Fade in then out across the rise: sin(πp) peaks at 0.5.
                    let alpha = sin(progress * .pi) * particle.maxOpacity

                    let rect = CGRect(
                        x: x - particle.size / 2,
                        y: y - particle.size / 2,
                        width: particle.size,
                        height: particle.size
                    )
                    ctx.fill(Path(ellipseIn: rect), with: .color(.white.opacity(alpha)))
                }
            }
            .blur(radius: 0.4)
        }
    }
}
