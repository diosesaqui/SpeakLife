//
//  SpeakingPowerEffect.swift
//  SpeakLife
//
//  Visual feedback shown while the user speaks a declaration.
//  Conveys that power is being released into the atmosphere.
//
//  Layers (back → front):
//    1. Radiating light rays   — slow rotating golden beams
//    2. Expanding spirit rings — 3 golden waves moving outward
//    3. Radiant glow           — pulsing golden/white core
//    4. Rising particles       — sparks ascending like breath
//    5. Top message            — optional subtle caption
//

import SwiftUI

// MARK: - Main effect container

struct SpeakingPowerEffect: View {
    let isActive: Bool
    var message: String? = nil   // e.g. "God's power flows when you speak"

    var body: some View {
        ZStack {
            // Layer 1: slow-rotating light rays (most dramatic, behind everything)
            LightRays(isActive: isActive)

            // Layer 2: expanding spirit rings
            ForEach(0..<3, id: \.self) { index in
                SpiritRing(delay: Double(index) * 0.6, isActive: isActive)
            }

            // Layer 3: radiant core glow
            RadiantGlow(isActive: isActive)

            // Layer 4: rising particles
            ForEach(0..<16, id: \.self) { index in
                RisingParticle(index: index, totalCount: 16, isActive: isActive)
            }

            // Layer 5: subtle top message
            if let message {
                VStack {
                    PowerMessage(text: message, isActive: isActive)
                        .padding(.top, 100)
                    Spacer()
                }
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Light Rays

/// 10 thin golden beams radiating from center, slowly rotating — like a holy sunrise.
private struct LightRays: View {
    let isActive: Bool

    @State private var rotation: Double = 0
    @State private var opacity: Double = 0

    private let rayCount = 10
    private let gold = Color(red: 1.0, green: 0.843, blue: 0.0)

    var body: some View {
        ZStack {
            ForEach(0..<rayCount, id: \.self) { index in
                let angle = Double(index) * (360.0 / Double(rayCount))
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [gold.opacity(0.0), gold.opacity(0.18), gold.opacity(0.0)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: 340, height: 2)
                    .rotationEffect(.degrees(angle + rotation))
            }
        }
        .opacity(opacity)
        .onChange(of: isActive) { active in
            if active {
                withAnimation(.easeIn(duration: 0.8)) { opacity = 1 }
                withAnimation(.linear(duration: 18).repeatForever(autoreverses: false)) {
                    rotation = 360
                }
            } else {
                withAnimation(.easeOut(duration: 0.6)) { opacity = 0 }
            }
        }
        .onAppear {
            if isActive {
                opacity = 1
                withAnimation(.linear(duration: 18).repeatForever(autoreverses: false)) {
                    rotation = 360
                }
            }
        }
    }
}

// MARK: - Spirit Ring

/// A golden ring that expands outward and fades — like a wave of power going forth.
private struct SpiritRing: View {
    let delay: Double
    let isActive: Bool

    @State private var scale: CGFloat = 0.2
    @State private var opacity: Double = 0

    private let gold = Color(red: 1.0, green: 0.843, blue: 0.0)

    var body: some View {
        Circle()
            .stroke(gold.opacity(opacity), lineWidth: 1.5)
            .scaleEffect(scale)
            .frame(width: 320, height: 320)
            .onChange(of: isActive) { active in
                active ? startAnimation() : stopAnimation()
            }
            .onAppear { if isActive { startAnimation() } }
    }

    private func startAnimation() {
        scale = 0.2
        opacity = 0
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            withAnimation(.easeOut(duration: 2.0).repeatForever(autoreverses: false)) {
                scale = 1.8
            }
            withAnimation(.easeIn(duration: 0.2).delay(delay)) {
                opacity = 0.7
            }
            withAnimation(.easeOut(duration: 2.0).delay(0.2).repeatForever(autoreverses: false)) {
                opacity = 0
            }
        }
    }

    private func stopAnimation() {
        withAnimation(.easeOut(duration: 0.4)) { opacity = 0; scale = 0.2 }
    }
}

// MARK: - Radiant Glow

/// Pulsing golden/white light at center — the source of the spoken word.
private struct RadiantGlow: View {
    let isActive: Bool

    @State private var pulse: CGFloat = 0.9
    @State private var glowOpacity: Double = 0
    private let gold = Color(red: 1.0, green: 0.843, blue: 0.0)

    var body: some View {
        ZStack {
            // Wide outer halo
            Circle()
                .fill(
                    RadialGradient(
                        colors: [gold.opacity(0.22), Color.clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 140
                    )
                )
                .frame(width: 280, height: 280)
                .scaleEffect(pulse)
                .opacity(glowOpacity)

            // Bright inner core
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.white.opacity(0.3), gold.opacity(0.15), Color.clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 60
                    )
                )
                .frame(width: 120, height: 120)
                .scaleEffect(pulse)
                .opacity(glowOpacity)
        }
        .onChange(of: isActive) { active in
            if active {
                withAnimation(.easeIn(duration: 0.4)) { glowOpacity = 1 }
                withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                    pulse = 1.1
                }
            } else {
                withAnimation(.easeOut(duration: 0.5)) { glowOpacity = 0; pulse = 0.9 }
            }
        }
        .onAppear {
            if isActive {
                glowOpacity = 1
                withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                    pulse = 1.1
                }
            }
        }
    }
}

// MARK: - Rising Particle

/// Golden sparks that drift upward — like breath/words ascending to heaven.
private struct RisingParticle: View {
    let index: Int
    let totalCount: Int
    let isActive: Bool

    @State private var yOffset: CGFloat = 0
    @State private var xDrift: CGFloat = 0
    @State private var opacity: Double = 0
    @State private var particleScale: CGFloat = 0.3

    private var startX: CGFloat {
        let spread: CGFloat = 180
        let step = spread / CGFloat(totalCount - 1)
        return -spread / 2 + step * CGFloat(index)
    }

    private static let delays: [Double] = [
        0.0, 0.35, 0.65, 0.15, 0.5, 0.8, 0.1, 0.45,
        0.75, 0.25, 0.55, 0.9, 0.2, 0.6, 0.4, 0.7
    ]
    private static let durations: [Double] = [
        2.4, 2.7, 2.2, 3.0, 2.5, 2.8, 2.3, 2.6,
        2.9, 2.2, 3.1, 2.5, 2.0, 2.8, 2.4, 2.7
    ]
    private static let sizes: [CGFloat] = [
        3, 4, 3, 5, 3, 4, 3, 5, 4, 3, 5, 3, 4, 3, 5, 4
    ]

    private var delay: Double { Self.delays[index % Self.delays.count] }
    private var duration: Double { Self.durations[index % Self.durations.count] }
    private var size: CGFloat { Self.sizes[index % Self.sizes.count] }

    var body: some View {
        Circle()
            .fill(Color(red: 1.0, green: 0.92, blue: 0.55))
            .frame(width: size, height: size)
            .scaleEffect(particleScale)
            .opacity(opacity)
            .offset(x: startX + xDrift, y: yOffset)
            .onChange(of: isActive) { active in
                active ? startRising() : stopRising()
            }
            .onAppear { if isActive { startRising() } }
    }

    private func startRising() {
        yOffset = 80
        opacity = 0
        particleScale = 0.3
        xDrift = 0
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            withAnimation(.easeInOut(duration: duration).repeatForever(autoreverses: false)) {
                yOffset = -180
                opacity = 0
                xDrift = CGFloat.random(in: -22...22)
            }
            withAnimation(.easeIn(duration: 0.25)) {
                opacity = 0.9
                particleScale = 1.0
            }
        }
    }

    private func stopRising() {
        withAnimation(.easeOut(duration: 0.3)) { opacity = 0 }
    }
}

// MARK: - Power Message

/// Subtle caption that fades in at the top when the effect is active.
private struct PowerMessage: View {
    let text: String
    let isActive: Bool

    @State private var textOpacity: Double = 0
    @State private var textOffset: CGFloat = -8

    var body: some View {
        Text(text)
            .font(.system(size: 13, weight: .medium, design: .rounded))
            .foregroundStyle(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.55),
                        Color(red: 1.0, green: 0.9, blue: 0.6).opacity(0.55)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .tracking(1.5)          // subtle letter-spacing for elegance
            .opacity(textOpacity)
            .offset(y: textOffset)
            .onChange(of: isActive) { active in
                if active {
                    withAnimation(.easeOut(duration: 0.8).delay(0.3)) {
                        textOpacity = 1
                        textOffset = 0
                    }
                } else {
                    withAnimation(.easeIn(duration: 0.3)) {
                        textOpacity = 0
                        textOffset = -8
                    }
                }
            }
            .onAppear {
                if isActive {
                    withAnimation(.easeOut(duration: 0.8).delay(0.3)) {
                        textOpacity = 1
                        textOffset = 0
                    }
                }
            }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color(red: 0.05, green: 0.07, blue: 0.18).ignoresSafeArea()

        VStack {
            Spacer()
            Text("I am the head and not the tail.\nI am above and not beneath.")
                .font(.system(size: 24, weight: .semibold, design: .serif))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
        }

        SpeakingPowerEffect(
            isActive: true,
            message: "God's power flows when you speak"
        )
    }
}
