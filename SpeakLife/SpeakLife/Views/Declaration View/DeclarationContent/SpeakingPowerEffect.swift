//
//  SpeakingPowerEffect.swift
//  SpeakLife
//
//  Visual feedback shown while the user speaks a declaration.
//  Conveys that power is being released into the atmosphere.
//
//  Design intent:
//    - Golden expanding rings (like sound/spirit waves moving outward)
//    - Soft radiant glow that pulses with each ring
//    - Light particles rising upward (like breath ascending)
//  All pure SwiftUI — no external dependencies.
//

import SwiftUI

// MARK: - Main effect container

struct SpeakingPowerEffect: View {
    let isActive: Bool

    var body: some View {
        ZStack {
            // Layer 1: Expanding spirit rings
            ForEach(0..<3, id: \.self) { index in
                SpiritRing(delay: Double(index) * 0.55, isActive: isActive)
            }

            // Layer 2: Soft central radiant glow
            RadiantGlow(isActive: isActive)

            // Layer 3: Rising light particles
            ForEach(0..<12, id: \.self) { index in
                RisingParticle(
                    index: index,
                    totalCount: 12,
                    isActive: isActive
                )
            }
        }
        .allowsHitTesting(false) // Never intercept touches
    }
}

// MARK: - Spirit Ring

/// A golden ring that expands outward and fades — like a wave of power going forth.
private struct SpiritRing: View {
    let delay: Double
    let isActive: Bool

    @State private var scale: CGFloat = 0.3
    @State private var opacity: Double = 0

    private let ringColor = Color(red: 1.0, green: 0.843, blue: 0.0) // Constants.gold

    var body: some View {
        Circle()
            .stroke(
                ringColor.opacity(opacity),
                lineWidth: 1.5
            )
            .scaleEffect(scale)
            .frame(width: 280, height: 280)
            .onChange(of: isActive) { active in
                if active {
                    startAnimation()
                } else {
                    stopAnimation()
                }
            }
            .onAppear {
                if isActive { startAnimation() }
            }
    }

    private func startAnimation() {
        // Reset before animating so repeat works cleanly
        scale = 0.3
        opacity = 0

        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            withAnimation(
                .easeOut(duration: 1.8)
                .repeatForever(autoreverses: false)
            ) {
                scale = 1.6
                opacity = 0
            }
            // Brief flash at start of each cycle
            withAnimation(.easeIn(duration: 0.15).delay(delay)) {
                opacity = 0.65
            }
        }
    }

    private func stopAnimation() {
        withAnimation(.easeOut(duration: 0.4)) {
            opacity = 0
            scale = 0.3
        }
    }
}

// MARK: - Radiant Glow

/// A soft golden glow that pulses while speaking — the "power source" at center.
private struct RadiantGlow: View {
    let isActive: Bool

    @State private var pulse: CGFloat = 0.85
    @State private var glowOpacity: Double = 0

    var body: some View {
        ZStack {
            // Outer soft halo
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 1.0, green: 0.843, blue: 0.0).opacity(0.18),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 120
                    )
                )
                .frame(width: 240, height: 240)
                .scaleEffect(pulse)
                .opacity(glowOpacity)

            // Inner bright core
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(0.25),
                            Color(red: 1.0, green: 0.843, blue: 0.0).opacity(0.1),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 55
                    )
                )
                .frame(width: 110, height: 110)
                .scaleEffect(pulse)
                .opacity(glowOpacity)
        }
        .onChange(of: isActive) { active in
            if active {
                withAnimation(.easeIn(duration: 0.4)) {
                    glowOpacity = 1
                }
                withAnimation(
                    .easeInOut(duration: 1.2)
                    .repeatForever(autoreverses: true)
                ) {
                    pulse = 1.08
                }
            } else {
                withAnimation(.easeOut(duration: 0.5)) {
                    glowOpacity = 0
                    pulse = 0.85
                }
            }
        }
        .onAppear {
            if isActive {
                glowOpacity = 1
                withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                    pulse = 1.08
                }
            }
        }
    }
}

// MARK: - Rising Particle

/// Small golden spark that rises upward — like breath/words ascending.
private struct RisingParticle: View {
    let index: Int
    let totalCount: Int
    let isActive: Bool

    @State private var yOffset: CGFloat = 0
    @State private var xDrift: CGFloat = 0
    @State private var opacity: Double = 0
    @State private var scale: CGFloat = 0.4

    // Spread particles across a horizontal band
    private var startX: CGFloat {
        let spread: CGFloat = 160
        let step = spread / CGFloat(totalCount - 1)
        return -spread / 2 + step * CGFloat(index)
    }

    private var delay: Double {
        // Random-ish stagger so they don't all move together
        let offsets = [0.0, 0.3, 0.6, 0.15, 0.45, 0.75,
                       0.1, 0.5, 0.8, 0.25, 0.55, 0.9]
        return offsets[index % offsets.count]
    }

    private var duration: Double {
        let durations = [2.2, 2.5, 2.0, 2.8, 2.3, 2.6,
                         2.1, 2.4, 2.7, 2.0, 2.9, 2.3]
        return durations[index % durations.count]
    }

    var body: some View {
        Circle()
            .fill(Color(red: 1.0, green: 0.9, blue: 0.5))
            .frame(width: 4, height: 4)
            .scaleEffect(scale)
            .opacity(opacity)
            .offset(x: startX + xDrift, y: yOffset)
            .onChange(of: isActive) { active in
                if active {
                    startRising()
                } else {
                    stopRising()
                }
            }
            .onAppear {
                if isActive { startRising() }
            }
    }

    private func startRising() {
        yOffset = 60
        opacity = 0
        scale = 0.4
        xDrift = 0

        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            withAnimation(
                .easeInOut(duration: duration)
                .repeatForever(autoreverses: false)
            ) {
                yOffset = -160
                opacity = 0
                xDrift = CGFloat.random(in: -18...18)
            }
            withAnimation(.easeIn(duration: 0.3)) {
                opacity = 0.8
                scale = 1.0
            }
        }
    }

    private func stopRising() {
        withAnimation(.easeOut(duration: 0.3)) {
            opacity = 0
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color(red: 0.05, green: 0.07, blue: 0.18)
            .ignoresSafeArea()

        VStack {
            Text("I am the head and not the tail.\nI am above and not beneath.")
                .font(.system(size: 22, weight: .semibold, design: .serif))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }

        SpeakingPowerEffect(isActive: true)
    }
}
