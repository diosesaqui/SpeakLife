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
    
    init(badge: Badge, size: CGFloat = 120, showGlow: Bool = true, showParticles: Bool = true) {
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
    
    @State private var rotationAngle: Double = 0
    @State private var glowPulse: Double = 1.0
    
    var body: some View {
        ZStack {
            // Outer glow effect
            if showGlow && badge.isUnlocked {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                badge.type.primaryColor.opacity(badge.rarity.glowIntensity * glowPulse),
                                badge.type.secondaryColor.opacity(badge.rarity.glowIntensity * 0.5 * glowPulse),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: size * 0.3,
                            endRadius: size * 0.8
                        )
                    )
                    .frame(width: size * 1.4, height: size * 1.4)
                    .blur(radius: 8)
            }
            
            // Badge base ring
            BadgeRing(
                badge: badge,
                size: size,
                rotationAngle: rotationAngle
            )
            
            // Badge center content
            BadgeCenterContent(
                badge: badge,
                size: size * 0.6
            )
            
            // Rarity indicator
            if badge.isUnlocked {
                BadgeRarityIndicator(
                    rarity: badge.rarity,
                    size: size * 0.2
                )
                .offset(x: size * 0.3, y: -size * 0.3)
            }
        }
        .onAppear {
            startAnimations()
        }
    }
    
    private func startAnimations() {
        if badge.isUnlocked {
            // Slow rotation for legendary badges
            if badge.rarity == .legendary {
                withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
                    rotationAngle = 360
                }
            }
            
            // Glow pulsing
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                glowPulse = badge.rarity == .legendary ? 1.3 : 1.1
            }
        }
    }
}

// MARK: - Badge Ring Component

struct BadgeRing: View {
    let badge: Badge
    let size: CGFloat
    let rotationAngle: Double
    
    var body: some View {
        ZStack {
            // Shadow ring
            Circle()
                .fill(Color.black.opacity(0.3))
                .frame(width: size, height: size)
                .offset(y: 4)
                .blur(radius: 4)
            
            // Base ring
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [
                            Color(red: 0.1, green: 0.1, blue: 0.1),
                            Color(red: 0.3, green: 0.3, blue: 0.3)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: size * 0.08
                )
                .frame(width: size * 0.9, height: size * 0.9)
            
            // Rarity ring (colored)
            if badge.isUnlocked {
                Circle()
                    .stroke(
                        AngularGradient(
                            colors: rarityGradientColors,
                            center: .center,
                            startAngle: .degrees(rotationAngle),
                            endAngle: .degrees(rotationAngle + 360)
                        ),
                        lineWidth: size * 0.06
                    )
                    .frame(width: size * 0.85, height: size * 0.85)
                
                // Inner highlight ring
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.8),
                                Color.white.opacity(0.3),
                                Color.clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: size * 0.015
                    )
                    .frame(width: size * 0.75, height: size * 0.75)
            } else {
                // Locked ring
                Circle()
                    .stroke(
                        Color.gray.opacity(0.5),
                        lineWidth: size * 0.06
                    )
                    .frame(width: size * 0.85, height: size * 0.85)
            }
        }
    }
    
    private var rarityGradientColors: [Color] {
        let baseColor = badge.rarity.ringColor
        return [
            baseColor,
            baseColor.opacity(0.8),
            Color.white.opacity(0.9),
            baseColor.opacity(0.8),
            baseColor
        ]
    }
}

// MARK: - Badge Center Content

struct BadgeCenterContent: View {
    let badge: Badge
    let size: CGFloat
    
    @State private var iconScale: CGFloat = 1.0
    
    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .fill(
                    RadialGradient(
                        colors: badge.isUnlocked ? centerGradientColors : lockedGradientColors,
                        center: .center,
                        startRadius: 0,
                        endRadius: size * 0.5
                    )
                )
                .frame(width: size, height: size)
            
            // Badge icon or lock
            Group {
                if badge.isUnlocked {
                    // Badge type icon
                    Image(systemName: badge.type.iconName)
                        .font(.system(size: size * 0.4, weight: .bold))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.5), radius: 2, x: 1, y: 1)
                        .scaleEffect(iconScale)
                } else {
                    // Lock icon
                    Image(systemName: "lock.fill")
                        .font(.system(size: size * 0.35, weight: .bold))
                        .foregroundColor(.gray)
                }
            }
        }
        .onAppear {
            if badge.isUnlocked && badge.rarity == .legendary {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    iconScale = 1.1
                }
            }
        }
    }
    
    private var centerGradientColors: [Color] {
        [
            badge.type.primaryColor,
            badge.type.secondaryColor,
            badge.type.primaryColor.opacity(0.8)
        ]
    }
    
    private var lockedGradientColors: [Color] {
        [
            Color(red: 0.2, green: 0.2, blue: 0.2),
            Color(red: 0.1, green: 0.1, blue: 0.1),
            Color(red: 0.15, green: 0.15, blue: 0.15)
        ]
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
        VStack(spacing: 8) {
            BadgeView(badge: badge, size: size)
            
            if showTitle {
                VStack(spacing: 4) {
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