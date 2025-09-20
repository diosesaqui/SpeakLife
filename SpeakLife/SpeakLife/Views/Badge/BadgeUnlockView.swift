//
//  BadgeUnlockView.swift
//  SpeakLife
//
//  Stunning badge unlock celebration view
//

import SwiftUI

struct BadgeUnlockView: View {
    let badge: Badge
    @Binding var isPresented: Bool
    
    @State private var showContent = false
    @State private var badgeScale: CGFloat = 0
    @State private var badgeRotation: Double = 0
    @State private var titleOffset: CGFloat = 100
    @State private var descriptionOpacity: Double = 0
    @State private var particleExplosion = false
    @State private var lightRayAnimation = false
    @State private var celebrationComplete = false
    @State private var typewriterText = ""
    @State private var showBadge = false
    @State private var glowIntensity: Double = 0
    
    private let fullTitle = "BADGE UNLOCKED!"
    
    var body: some View {
        ZStack {
            // Animated background
            BadgeUnlockBackground(showContent: showContent)
                .ignoresSafeArea()
            
            // Light rays
            LightRayEffect(animate: lightRayAnimation)
            
            // Particle explosion
            if particleExplosion {
                ParticleExplosion(
                    primaryColor: badge.type.primaryColor,
                    secondaryColor: badge.type.secondaryColor
                )
            }
            
            VStack(spacing: 30) {
                Spacer()
                    .frame(minHeight: 20)
                
                // "BADGE UNLOCKED!" text with typewriter effect
                VStack(spacing: 20) {
                    HStack {
                        Text(typewriterText)
                            .font(.system(size: 28, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                            .shadow(color: badge.type.primaryColor, radius: glowIntensity * 10, x: 0, y: 0)
                            .tracking(1.5)
                            .minimumScaleFactor(0.8)
                            .lineLimit(1)
                        
                        if typewriterText.count < fullTitle.count {
                            Text("|")
                                .font(.system(size: 28, weight: .black))
                                .foregroundColor(.white)
                                .opacity(showContent ? 1 : 0)
                                .animation(.easeInOut(duration: 0.5).repeatForever(), value: showContent)
                        }
                    }
                    .padding(.horizontal, 20)
                }
                
                // Badge with dramatic entrance
                ZStack {
                    // Glow effect
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    badge.type.primaryColor.opacity(glowIntensity),
                                    badge.type.secondaryColor.opacity(glowIntensity * 0.5),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 50,
                                endRadius: 200
                            )
                        )
                        .frame(width: 400, height: 400)
                        .blur(radius: 20)
                    
                    // Main badge
                    BadgeView(
                        badge: badge,
                        size: 200,
                        showGlow: true,
                        showParticles: true
                    )
                    .scaleEffect(badgeScale)
                    .rotationEffect(.degrees(badgeRotation))
                    .opacity(showBadge ? 1 : 0)
                }
                
                // Badge title and description
                VStack(spacing: 16) {
                    Text(badge.title)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.8)
                        .lineLimit(2)
                        .padding(.horizontal, 20)
                        .offset(y: titleOffset)
                    
                    Text(badge.description)
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .lineLimit(nil) // Allow unlimited lines
                        .fixedSize(horizontal: false, vertical: true) // Allow vertical expansion
                        .frame(maxWidth: UIScreen.main.bounds.width - 60) // Ensure proper width
                        .padding(.horizontal, 30)
                        .opacity(descriptionOpacity)
                    
                    // Rarity badge
                    HStack(spacing: 8) {
                        ForEach(0..<rarityStars, id: \.self) { _ in
                            Image(systemName: "star.fill")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(badge.rarity.ringColor)
                        }
                        
                        Text(badge.rarity.displayName.uppercased())
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(badge.rarity.ringColor)
                            .tracking(1)
                    }
                    .opacity(descriptionOpacity)
                }
                .frame(maxWidth: .infinity)
                
                Spacer()
                    .frame(minHeight: 20)
                
                // Continue button
                if celebrationComplete {
                    CelebrationContinueButton {
                        withAnimation(.easeInOut(duration: 0.5)) {
                            isPresented = false
                        }
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .onAppear {
            startCelebrationSequence()
        }
    }
    
    private var rarityStars: Int {
        switch badge.rarity {
        case .common: return 1
        case .rare: return 2
        case .epic: return 3
        case .legendary: return 4
        }
    }
    
    private func startCelebrationSequence() {
        // Step 1: Show background (0.5s)
        withAnimation(.easeInOut(duration: 0.5)) {
            showContent = true
        }
        
        // Step 2: Typewriter effect for title (1.5s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            startTypewriterEffect()
        }
        
        // Step 3: Particle explosion (2s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeInOut(duration: 0.3)) {
                particleExplosion = true
            }
        }
        
        // Step 4: Badge dramatic entrance (2.3s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.3) {
            showBadge = true
            withAnimation(.spring(response: 0.8, dampingFraction: 0.6)) {
                badgeScale = 1.0
                badgeRotation = 360
            }
            
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                glowIntensity = 0.8
            }
        }
        
        // Step 5: Light rays (2.5s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            lightRayAnimation = true
        }
        
        // Step 6: Title slide in (3s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                titleOffset = 0
            }
        }
        
        // Step 7: Description fade in (3.5s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
            withAnimation(.easeInOut(duration: 0.8)) {
                descriptionOpacity = 1.0
            }
        }
        
        // Step 8: Show continue button (4.5s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.5) {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                celebrationComplete = true
            }
        }
    }
    
    private func startTypewriterEffect() {
        typewriterText = ""
        for (index, character) in fullTitle.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.08) {
                typewriterText += String(character)
            }
        }
    }
}

// MARK: - Background Animation

struct BadgeUnlockBackground: View {
    let showContent: Bool
    
    @State private var gradientAnimation = false
    @State private var shimmerOffset: CGFloat = -1
    
    var body: some View {
        ZStack {
            // Base gradient
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.05, blue: 0.2),
                    Color(red: 0.1, green: 0.05, blue: 0.3),
                    Color(red: 0.15, green: 0.1, blue: 0.4),
                    Color(red: 0.05, green: 0.05, blue: 0.2)
                ],
                startPoint: gradientAnimation ? .topLeading : .bottomTrailing,
                endPoint: gradientAnimation ? .bottomTrailing : .topLeading
            )
            
            // Shimmer overlay
            LinearGradient(
                colors: [
                    Color.clear,
                    Color.white.opacity(0.1),
                    Color.white.opacity(0.2),
                    Color.white.opacity(0.1),
                    Color.clear
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .mask(
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [Color.clear, Color.white, Color.clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .rotationEffect(.degrees(45))
                    .offset(x: shimmerOffset * UIScreen.main.bounds.width * 2)
            )
        }
        .opacity(showContent ? 1 : 0)
        .onAppear {
            withAnimation(.easeInOut(duration: 4.0).repeatForever(autoreverses: true)) {
                gradientAnimation.toggle()
            }
            
            withAnimation(.linear(duration: 3.0).repeatForever(autoreverses: false)) {
                shimmerOffset = 1
            }
        }
    }
}

// MARK: - Light Ray Effect

struct LightRayEffect: View {
    let animate: Bool
    
    @State private var rotationAngle: Double = 0
    @State private var rayOpacity: Double = 0
    
    var body: some View {
        ZStack {
            ForEach(0..<8, id: \.self) { index in
                RayShape()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(rayOpacity),
                                Color.yellow.opacity(rayOpacity * 0.5),
                                Color.clear
                            ],
                            startPoint: .center,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: UIScreen.main.bounds.width * 1.5, height: 4)
                    .rotationEffect(.degrees(Double(index) * 45 + rotationAngle))
                    .blendMode(.screen)
            }
        }
        .onChange(of: animate) { shouldAnimate in
            if shouldAnimate {
                withAnimation(.easeInOut(duration: 0.5)) {
                    rayOpacity = 0.6
                }
                
                withAnimation(.linear(duration: 8.0).repeatForever(autoreverses: false)) {
                    rotationAngle = 360
                }
            }
        }
    }
}

struct RayShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY - rect.height/4))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY + rect.height/4))
        path.closeSubpath()
        return path
    }
}

// MARK: - Particle Explosion

struct ParticleExplosion: View {
    let primaryColor: Color
    let secondaryColor: Color
    
    @State private var particles: [ExplosionParticle] = []
    
    var body: some View {
        ZStack {
            ForEach(particles.indices, id: \.self) { index in
                if particles.indices.contains(index) {
                    Circle()
                        .fill(particles[index].color)
                        .frame(width: particles[index].size, height: particles[index].size)
                        .position(particles[index].position)
                        .opacity(particles[index].opacity)
                        .blur(radius: particles[index].blur)
                }
            }
        }
        .onAppear {
            createExplosion()
        }
    }
    
    private func createExplosion() {
        let center = CGPoint(x: UIScreen.main.bounds.width / 2, y: UIScreen.main.bounds.height / 2)
        let colors = [primaryColor, secondaryColor, .white, .yellow]
        
        particles = (0..<50).map { _ in
            let angle = Double.random(in: 0...2 * .pi)
            let distance = Double.random(in: 100...300)
            let targetPosition = CGPoint(
                x: center.x + cos(angle) * distance,
                y: center.y + sin(angle) * distance
            )
            
            return ExplosionParticle(
                position: center,
                targetPosition: targetPosition,
                color: colors.randomElement() ?? primaryColor,
                size: Double.random(in: 4...12),
                opacity: Double.random(in: 0.6...1.0),
                blur: Double.random(in: 0...2)
            )
        }
        
        // Animate particles
        for index in particles.indices {
            let delay = Double.random(in: 0...0.3)
            let duration = Double.random(in: 0.8...1.5)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                withAnimation(.easeOut(duration: duration)) {
                    if particles.indices.contains(index) {
                        particles[index].position = particles[index].targetPosition
                        particles[index].opacity = 0
                        particles[index].size *= 0.5
                    }
                }
            }
        }
    }
}

struct ExplosionParticle {
    var position: CGPoint
    let targetPosition: CGPoint
    let color: Color
    var size: Double
    var opacity: Double
    let blur: Double
}

// MARK: - Continue Button

struct CelebrationContinueButton: View {
    let action: () -> Void
    
    @State private var pulseScale: CGFloat = 1.0
    @State private var glowIntensity: Double = 0
    
    var body: some View {
        Button(action: action) {
            Text("Continue Your Journey")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
                .padding(.horizontal, 32)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 25)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.2, green: 0.4, blue: 0.8),
                                    Color(red: 0.1, green: 0.3, blue: 0.7)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 25)
                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                )
                .shadow(color: Color(red: 0.2, green: 0.4, blue: 0.8).opacity(glowIntensity), radius: 10, x: 0, y: 0)
                .scaleEffect(pulseScale)
        }
        .buttonStyle(PlainButtonStyle())
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                pulseScale = 1.05
                glowIntensity = 0.5
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
struct BadgeUnlockView_Previews: PreviewProvider {
    @State static var isPresented = true
    
    static var previews: some View {
        BadgeUnlockView(
            badge: Badge(
                type: .streak,
                rarity: .legendary,
                title: "Destiny Carrier",
                description: "365 days of speaking life into your destiny! You've proven your unwavering commitment to the covenant and now carry the full weight of your divine purpose.",
                requirement: .streakDays(365),
                unlockedAt: Date(),
                isUnlocked: true
            ),
            isPresented: $isPresented
        )
    }
}
#endif