//
//  LandingView.swift
//  SpeakLife
//
//  Premium cold-start branding screen. Sequenced entrance (2.8s total):
//    0.10s  glow + icon spring in (response 0.7, damping 0.78)
//    0.55s  wordmark letter cascade begins (35ms per letter)
//    0.70s  diagonal light sweep across the icon
//    1.30s  italic tagline fades in
//    1.75s  one gentle breath cycle on the icon
//    2.45s  outgoing fade (0.35s)
//
//  Total budget: 2.8s, matched by SpeakLifeApp's dismiss timer.
//
//  Ambient backdrop combines two motion layers drawn together in a single
//  Canvas/TimelineView: drifting particles rising vertically and stationary
//  twinkling stars with sine-wave opacity. Both are skipped under
//  accessibilityReduceMotion, which also collapses the entrance into a
//  single 0.6s crossfade.
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

    // Shimmer rectangle slides left → right across the icon once.
    @State private var shimmerOffset: CGFloat = -120

    // Single flip drives the per-letter wordmark cascade via per-letter
    // animation delays on `value: wordmarkStarted`.
    @State private var wordmarkStarted = false

    @State private var taglineOpacity: Double = 0
    @State private var contentOpacity: Double = 1.0

    private let wordmark = "SpeakLife"

    var body: some View {
        ZStack {
            Image(backgroundImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea()

            LinearGradient(
                colors: [
                    Color.black.opacity(0.15),
                    Color(red: 0.04, green: 0.06, blue: 0.15).opacity(0.55)
                ],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            if !reduceMotion {
                AmbientBackdrop()
                    .opacity(contentOpacity * 0.9)
                    .allowsHitTesting(false)
                    .ignoresSafeArea()
            }

            VStack(spacing: 22) {
                iconLockup
                wordmarkAndTagline
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

    // MARK: - Icon + Glow + Shimmer

    private var iconLockup: some View {
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

            iconWithShimmer
                .scaleEffect(iconScale * iconBreath)
                .opacity(iconOpacity)
        }
    }

    private var iconWithShimmer: some View {
        ZStack {
            Image(uiImage: UIImage(named: "appIconDisplay") ?? UIImage())
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 132, height: 132)

            // Single light-sweep band. Rotated 20° so the gleam reads as a
            // diagonal highlight rather than a vertical wipe. .plusLighter
            // brightens whatever it crosses without flattening the icon art.
            Rectangle()
                .fill(
                    LinearGradient(
                        stops: [
                            .init(color: .white.opacity(0.0),  location: 0.0),
                            .init(color: .white.opacity(0.0),  location: 0.35),
                            .init(color: .white.opacity(0.55), location: 0.5),
                            .init(color: .white.opacity(0.0),  location: 0.65),
                            .init(color: .white.opacity(0.0),  location: 1.0)
                        ],
                        startPoint: .leading, endPoint: .trailing
                    )
                )
                .frame(width: 70, height: 220)
                .rotationEffect(.degrees(20))
                .offset(x: shimmerOffset)
                .blendMode(.plusLighter)
                .allowsHitTesting(false)
        }
        .frame(width: 132, height: 132)
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.35), radius: 24, x: 0, y: 14)
    }

    // MARK: - Wordmark + Tagline

    private var wordmarkAndTagline: some View {
        VStack(spacing: 10) {
            // Per-letter cascade: each glyph keys off a single `wordmarkStarted`
            // toggle, but each one's `.animation` carries its own delay so the
            // word reveals like it's being typeset, not stamped.
            HStack(spacing: 0.6) {
                ForEach(Array(wordmark.enumerated()), id: \.offset) { idx, char in
                    Text(String(char))
                        .font(Font.custom("AppleSDGothicNeo-Bold", size: 42))
                        .foregroundColor(.white)
                        .shadow(color: Color.black.opacity(0.32), radius: 10, y: 3)
                        .opacity(wordmarkStarted ? 1.0 : 0)
                        .offset(y: wordmarkStarted ? 0 : 18)
                        .animation(
                            reduceMotion
                                ? .easeOut(duration: 0.4)
                                : .spring(response: 0.55, dampingFraction: 0.85)
                                    .delay(Double(idx) * 0.035),
                            value: wordmarkStarted
                        )
                }
            }

            Text("Speak God's promises. Walk in victory.")
                .font(Font.custom("AppleSDGothicNeo-Regular", size: 15))
                .italic()
                .foregroundColor(.white.opacity(0.82))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .shadow(color: Color.black.opacity(0.25), radius: 6, y: 2)
                .opacity(taglineOpacity)
        }
    }

    // MARK: - Sequence

    private func runEntranceSequence() {
        if reduceMotion {
            withAnimation(.easeOut(duration: 0.6)) {
                iconScale = 1.0
                iconOpacity = 1.0
                glowScale = 1.0
                glowOpacity = 0.85
                wordmarkStarted = true
                taglineOpacity = 1.0
            }
            return
        }

        // 0.10s — glow + icon spring in
        withAnimation(.spring(response: 0.7, dampingFraction: 0.78).delay(0.10)) {
            iconScale = 1.0
            iconOpacity = 1.0
            glowScale = 1.0
            glowOpacity = 0.88
        }

        // 0.55s — wordmark cascade trigger (per-letter delays applied inline)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
            wordmarkStarted = true
        }

        // 0.70s — diagonal shimmer sweeps across the icon
        withAnimation(.easeInOut(duration: 0.55).delay(0.70)) {
            shimmerOffset = 120
        }

        // 1.30s — tagline fades in (after the last letter has settled)
        withAnimation(.easeOut(duration: 0.5).delay(1.30)) {
            taglineOpacity = 1.0
        }

        // 1.75s — single breath cycle: 1.0 → 1.025 → 1.0 across 0.70s
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.75) {
            withAnimation(.easeInOut(duration: 0.35)) { iconBreath = 1.025 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                withAnimation(.easeInOut(duration: 0.35)) { iconBreath = 1.0 }
            }
        }

        // 2.45s — outgoing fade
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.45) {
            withAnimation(.easeOut(duration: 0.35)) { contentOpacity = 0 }
        }
    }
}

// MARK: - Ambient Backdrop

/// Drifting particles + stationary twinkling stars, rendered together in a
/// single Canvas so the work doesn't compete with SwiftUI's state-driven
/// animation pipeline during the entrance sequence. Stars are constrained to
/// the upper and lower thirds so they never sit behind the icon/wordmark.
private struct AmbientBackdrop: View {
    private struct DriftParticle {
        let x: CGFloat            // 0...1 of width
        let phase: Double         // 0...1 starting offset
        let speed: Double         // cycles per second
        let size: CGFloat
        let maxOpacity: Double
    }

    private struct TwinkleStar {
        let x: CGFloat            // 0...1 of width
        let y: CGFloat            // 0...1 of height (avoids icon band)
        let phase: Double         // radians
        let twinkleHz: Double     // twinkle frequency in Hz
        let size: CGFloat
        let baseOpacity: Double
    }

    private let particles: [DriftParticle]
    private let stars: [TwinkleStar]
    private let startDate = Date()

    init(particleCount: Int = 16, starCount: Int = 8) {
        var gen = SystemRandomNumberGenerator()
        self.particles = (0..<particleCount).map { _ in
            DriftParticle(
                x: .random(in: 0.04...0.96, using: &gen),
                phase: .random(in: 0...1, using: &gen),
                speed: .random(in: 0.05...0.12, using: &gen),
                size: .random(in: 1.8...4.2, using: &gen),
                maxOpacity: .random(in: 0.32...0.62, using: &gen)
            )
        }
        // Alternate upper/lower halves so stars never sit on the center band
        // where the icon and wordmark live.
        self.stars = (0..<starCount).map { i in
            let inUpper = i % 2 == 0
            return TwinkleStar(
                x: .random(in: 0.06...0.94, using: &gen),
                y: inUpper
                    ? .random(in: 0.05...0.28, using: &gen)
                    : .random(in: 0.74...0.94, using: &gen),
                phase: .random(in: 0...(2 * .pi), using: &gen),
                twinkleHz: .random(in: 0.35...0.85, using: &gen),
                size: .random(in: 1.4...2.8, using: &gen),
                baseOpacity: .random(in: 0.55...0.85, using: &gen)
            )
        }
    }

    var body: some View {
        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSince(startDate)
            Canvas { ctx, size in
                drawParticles(in: ctx, size: size, t: t)
                drawStars(in: ctx, size: size, t: t)
            }
            .blur(radius: 0.4)
        }
    }

    private func drawParticles(in ctx: GraphicsContext, size: CGSize, t: Double) {
        for p in particles {
            var progress = (p.phase + t * p.speed)
                .truncatingRemainder(dividingBy: 1.0)
            if progress < 0 { progress += 1.0 }

            let y = size.height * (1.0 - CGFloat(progress))
            let x = size.width * p.x
            let alpha = sin(progress * .pi) * p.maxOpacity

            let rect = CGRect(
                x: x - p.size / 2,
                y: y - p.size / 2,
                width: p.size,
                height: p.size
            )
            ctx.fill(Path(ellipseIn: rect), with: .color(.white.opacity(alpha)))
        }
    }

    private func drawStars(in ctx: GraphicsContext, size: CGSize, t: Double) {
        for s in stars {
            // sin returns -1...1 → normalize to 0...1 with phase offset
            let twinkle = (sin(t * s.twinkleHz * 2 * .pi + s.phase) + 1) / 2
            let alpha = s.baseOpacity * (0.30 + twinkle * 0.70)

            let x = size.width * s.x
            let y = size.height * s.y
            let rect = CGRect(
                x: x - s.size / 2,
                y: y - s.size / 2,
                width: s.size,
                height: s.size
            )
            ctx.fill(Path(ellipseIn: rect), with: .color(.white.opacity(alpha)))
        }
    }
}
