//
//  BadgeRenderer.swift
//  SpeakLife
//
//  Apple award-winning badge graphics engine
//

import SwiftUI
import CoreGraphics

// MARK: - Main Badge View

struct BadgeView: View {
    let badge: Badge
    let size: CGFloat
    let showGlow: Bool
    let showParticles: Bool
    
    // Default to a clean, static medal. Glow/particles are reserved for the
    // unlock celebration, which opts in explicitly — keeping the collection and
    // profile badges restrained instead of busy.
    init(badge: Badge, size: CGFloat = 120, showGlow: Bool = false, showParticles: Bool = false) {
        self.badge = badge
        self.size = size
        self.showGlow = showGlow
        self.showParticles = showParticles
    }
    
    var body: some View {
        ZStack {
            // Particle effects layer
            if showParticles && badge.isUnlocked {
                BadgeParticleEffect(
                    rarity: badge.rarity,
                    primaryColor: badge.type.primaryColor,
                    size: size
                )
            }
            
            // Main badge content
            BadgeContent(
                badge: badge,
                size: size,
                showGlow: showGlow
            )
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Badge Content Renderer

struct BadgeContent: View {
    let badge: Badge
    let size: CGFloat
    let showGlow: Bool
    
    @State private var glowPulse: Double = 1.0

    var body: some View {
        ZStack {
            // Soft single-tone glow — only on the celebration screen (showGlow).
            // One restrained metal color, gently pulsing; no rainbow halo.
            if showGlow && badge.isUnlocked {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                badge.rarity.metalBase.opacity(badge.rarity.glowIntensity * 0.6 * glowPulse),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: size * 0.35,
                            endRadius: size * 0.85
                        )
                    )
                    .frame(width: size * 1.5, height: size * 1.5)
                    .blur(radius: size * 0.08)
            }

            // Minted metal rim
            BadgeRing(badge: badge, size: size)

            // Embossed emblem on a dark coin face
            BadgeCenterContent(
                badge: badge,
                size: size * 0.66
            )
        }
        .onAppear {
            if showGlow && badge.isUnlocked {
                withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
                    glowPulse = 1.25
                }
            }
        }
    }
}

// MARK: - Badge Ring Component

struct BadgeRing: View {
    let badge: Badge
    let size: CGFloat

    private var rimColors: [Color] {
        badge.isUnlocked
            ? badge.rarity.metalGradient
            : [Color(white: 0.50), Color(white: 0.38), Color(white: 0.26)]
    }

    var body: some View {
        ZStack {
            // Soft, grounded drop shadow
            Circle()
                .fill(Color.black.opacity(0.18))
                .frame(width: size, height: size)
                .offset(y: size * 0.02)
                .blur(radius: size * 0.04)

            // Beveled metal rim: light top-left to shadow bottom-right
            Circle()
                .strokeBorder(
                    LinearGradient(
                        colors: rimColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: size * 0.07
                )
                .frame(width: size, height: size)

            // Crisp inner edge for definition
            Circle()
                .stroke(Color.black.opacity(0.18), lineWidth: size * 0.008)
                .frame(width: size * 0.86, height: size * 0.86)
        }
    }
}

// MARK: - Badge Center Content

struct BadgeCenterContent: View {
    let badge: Badge
    let size: CGFloat
    
    var body: some View {
        ZStack {
            // Dark coin face — lets the metal rim and emblem be the heroes
            Circle()
                .fill(
                    LinearGradient(
                        colors: badge.isUnlocked
                            ? [Color(white: 0.17), Color(white: 0.09)]
                            : [Color(white: 0.20), Color(white: 0.12)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: size, height: size)

            // Faint top sheen
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.16), Color.clear],
                        startPoint: .top,
                        endPoint: .center
                    )
                )
                .frame(width: size, height: size)

            // Emblem
            if badge.isUnlocked {
                Image(systemName: badge.type.iconName)
                    .font(.system(size: size * 0.42, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [badge.rarity.metalHighlight, badge.rarity.metalBase],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: .black.opacity(0.45), radius: size * 0.02, x: 0, y: size * 0.012)
            } else {
                Image(systemName: "lock.fill")
                    .font(.system(size: size * 0.34, weight: .semibold))
                    .foregroundColor(Color(white: 0.45))
            }
        }
    }
}

// MARK: - Badge Rarity Indicator

struct BadgeRarityIndicator: View {
    let rarity: BadgeRarity
    let size: CGFloat
    
    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .fill(rarity.ringColor)
                .frame(width: size, height: size)
            
            // Rarity stars
            HStack(spacing: 1) {
                ForEach(0..<starCount, id: \.self) { _ in
                    Image(systemName: "star.fill")
                        .font(.system(size: size * 0.25, weight: .bold))
                        .foregroundColor(.white)
                }
            }
        }
        .shadow(color: .black.opacity(0.3), radius: 2, x: 1, y: 1)
    }
    
    private var starCount: Int {
        switch rarity {
        case .common: return 1
        case .rare: return 2
        case .epic: return 3
        case .legendary: return 4
        }
    }
}

// MARK: - Badge Particle Effects

struct BadgeParticleEffect: View {
    let rarity: BadgeRarity
    let primaryColor: Color
    let size: CGFloat
    
    @State private var particleStates: [ParticleState] = []
    
    var body: some View {
        ZStack {
            ForEach(particleStates.indices, id: \.self) { index in
                if particleStates.indices.contains(index) {
                    ParticleView(
                        state: particleStates[index],
                        color: primaryColor,
                        size: size * 0.03
                    )
                }
            }
        }
        .onAppear {
            initializeParticles()
            startParticleAnimation()
        }
    }
    
    private func initializeParticles() {
        particleStates = (0..<rarity.particleCount).map { index in
            ParticleState(
                angle: Double(index) * (360.0 / Double(rarity.particleCount)),
                radius: size * 0.6,
                opacity: Double.random(in: 0.3...0.8),
                scale: Double.random(in: 0.5...1.2)
            )
        }
    }
    
    private func startParticleAnimation() {
        for index in particleStates.indices {
            let delay = Double(index) * 0.1
            
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                withAnimation(
                    .easeInOut(duration: Double.random(in: 2...4))
                    .repeatForever(autoreverses: true)
                ) {
                    if particleStates.indices.contains(index) {
                        particleStates[index].opacity = Double.random(in: 0.1...1.0)
                        particleStates[index].scale = Double.random(in: 0.3...1.5)
                    }
                }
            }
        }
    }
}

struct ParticleState {
    var angle: Double
    var radius: Double
    var opacity: Double
    var scale: Double
}

struct ParticleView: View {
    let state: ParticleState
    let color: Color
    let size: CGFloat
    
    var body: some View {
        Circle()
            .fill(color.opacity(state.opacity))
            .frame(width: size * state.scale, height: size * state.scale)
            .position(
                x: cos(state.angle * .pi / 180) * state.radius,
                y: sin(state.angle * .pi / 180) * state.radius
            )
            .blur(radius: 1)
    }
}

// MARK: - Badge with Text

struct BadgeDisplayView: View {
    let badge: Badge
    let size: CGFloat
    let showTitle: Bool
    
    init(badge: Badge, size: CGFloat = 120, showTitle: Bool = true) {
        self.badge = badge
        self.size = size
        self.showTitle = showTitle
    }
    
    var body: some View {
        VStack(spacing: DS.Spacing.xs) {
            BadgeView(badge: badge, size: size)

            if showTitle {
                VStack(spacing: DS.Spacing.xxs) {
                    Text(badge.displayTitle)
                        .font(.system(size: size * 0.12, weight: .bold, design: .rounded))
                        .foregroundColor(badge.isUnlocked ? .white : .gray)
                        .multilineTextAlignment(.center)
                    
                    if badge.isUnlocked {
                        Text(badge.rarity.displayName.uppercased())
                            .font(.system(size: size * 0.08, weight: .medium, design: .rounded))
                            .foregroundColor(badge.rarity.ringColor)
                            .tracking(1)
                    }
                }
                .frame(width: size * 1.2)
            }
        }
    }
}

// MARK: - High-Resolution Badge Generator

struct BadgeImageGenerator {
    static func generateHighResolutionBadge(badge: Badge, size: CGSize = CGSize(width: 500, height: 500)) -> UIImage? {
        let badgeView = BadgeView(badge: badge, size: min(size.width, size.height) * 0.8)
            .frame(width: size.width, height: size.height)
            .background(Color.clear)
        
        let controller = UIHostingController(rootView: badgeView)
        controller.view.bounds = CGRect(origin: .zero, size: size)
        controller.view.backgroundColor = .clear
        
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            controller.view.drawHierarchy(in: controller.view.bounds, afterScreenUpdates: true)
        }
    }
    
    static func generateShareableImage(badge: Badge, includeAppBranding: Bool = true) -> UIImage? {
        let shareSize = CGSize(width: 1080, height: 1080) // Instagram square
        
        let renderer = UIGraphicsImageRenderer(size: shareSize)
        return renderer.image { context in
            let cgContext = context.cgContext
            
            // Background gradient
            let backgroundGradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: [
                    Color(red: 0.1, green: 0.1, blue: 0.2).cgColor!,
                    Color(red: 0.05, green: 0.05, blue: 0.15).cgColor!
                ] as CFArray,
                locations: [0.0, 1.0]
            )!
            
            cgContext.drawLinearGradient(
                backgroundGradient,
                start: CGPoint(x: 0, y: 0),
                end: CGPoint(x: shareSize.width, y: shareSize.height),
                options: []
            )
            
            // Badge
            if let badgeImage = generateHighResolutionBadge(badge: badge, size: CGSize(width: 400, height: 400)) {
                let badgeRect = CGRect(
                    x: (shareSize.width - 400) / 2,
                    y: (shareSize.height - 400) / 2 - 100,
                    width: 400,
                    height: 400
                )
                badgeImage.draw(in: badgeRect)
            }
            
            // Title
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 48, weight: .black),
                .foregroundColor: UIColor.white,
                .strokeColor: UIColor.black,
                .strokeWidth: -2
            ]
            
            let title = badge.title
            let titleSize = title.size(withAttributes: titleAttributes)
            let titleRect = CGRect(
                x: (shareSize.width - titleSize.width) / 2,
                y: shareSize.height * 0.75,
                width: titleSize.width,
                height: titleSize.height
            )
            title.draw(in: titleRect, withAttributes: titleAttributes)
            
            // App branding
            if includeAppBranding {
                let brandingAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 24, weight: .medium),
                    .foregroundColor: UIColor.white.withAlphaComponent(0.8)
                ]
                
                let branding = "Earned in SpeakLife"
                let brandingSize = branding.size(withAttributes: brandingAttributes)
                let brandingRect = CGRect(
                    x: (shareSize.width - brandingSize.width) / 2,
                    y: shareSize.height - 80,
                    width: brandingSize.width,
                    height: brandingSize.height
                )
                branding.draw(in: brandingRect, withAttributes: brandingAttributes)
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
struct BadgeRenderer_Previews: PreviewProvider {
    static var previews: some View {
        let sampleBadge = Badge(
            type: .streak,
            rarity: .legendary,
            title: "Destiny Carrier",
            description: "365 days of speaking life!",
            requirement: .streakDays(365),
            unlockedAt: Date(),
            isUnlocked: true
        )
        
        VStack(spacing: 40) {
            BadgeDisplayView(badge: sampleBadge, size: 150)
            
            HStack(spacing: 20) {
                ForEach(BadgeRarity.allCases, id: \.self) { rarity in
                    let testBadge = Badge(
                        type: .streak,
                        rarity: rarity,
                        title: rarity.displayName,
                        description: "Test badge",
                        requirement: .streakDays(7),
                        unlockedAt: Date(),
                        isUnlocked: true
                    )
                    BadgeView(badge: testBadge, size: 80)
                }
            }
        }
        .padding()
        .background(Color.black)
    }
}
#endif