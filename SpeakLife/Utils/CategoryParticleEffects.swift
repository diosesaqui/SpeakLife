//
//  CategoryParticleEffects.swift
//  SpeakLife
//
//  Category-specific particle effects and themed animations
//

import SwiftUI
import CoreGraphics

// MARK: - Category Theme Manager

final class CategoryThemeManager: ObservableObject {
    
    enum CategoryTheme: String, CaseIterable {
        case faith, hope, love, peace, strength, gratitude, joy, grace
        case fear, anxiety, rest, wisdom, confidence, destiny, identity
        case marriage, parenting, work, health, wealth, favor, miracles
        case warfare, protection, purity, obedience, spiritualGrowth
        
        var colors: [Color] {
            switch self {
            case .faith:
                return [.blue, .white, .silver]
            case .hope:
                return [.yellow, .orange, .gold]
            case .love:
                return [.red, .pink, .white]
            case .peace:
                return [.blue, .teal, .mint]
            case .strength:
                return [.orange, .red, .yellow]
            case .gratitude:
                return [.yellow, .orange, .gold]
            case .joy:
                return [.yellow, .pink, .orange]
            case .grace:
                return [.purple, .white, .blue]
            case .fear:
                return [.blue, .teal, .white] // Calming colors
            case .anxiety:
                return [.green, .mint, .white] // Soothing colors
            case .rest:
                return [.blue, .purple, .indigo]
            case .wisdom:
                return [.purple, .blue, .white]
            case .confidence:
                return [.orange, .yellow, .gold]
            case .destiny:
                return [.purple, .gold, .white]
            case .identity:
                return [.blue, .teal, .white]
            case .marriage:
                return [.red, .pink, .gold]
            case .parenting:
                return [.green, .yellow, .orange]
            case .work:
                return [.blue, .gray, .white]
            case .health:
                return [.green, .mint, .white]
            case .wealth:
                return [.gold, .yellow, .green]
            case .favor:
                return [.purple, .gold, .white]
            case .miracles:
                return [.white, .gold, .blue]
            case .warfare:
                return [.red, .orange, .gold]
            case .protection:
                return [.blue, .white, .silver]
            case .purity:
                return [.white, .blue, .silver]
            case .obedience:
                return [.blue, .white, .purple]
            case .spiritualGrowth:
                return [.green, .blue, .white]
            }
        }
        
        var symbols: [String] {
            switch self {
            case .faith:
                return ["cross.fill", "star.fill", "sparkles"]
            case .hope:
                return ["sun.max.fill", "star.fill", "sparkles"]
            case .love:
                return ["heart.fill", "heart.circle.fill", "sparkles"]
            case .peace:
                return ["leaf.fill", "water.waves", "sparkles"]
            case .strength:
                return ["bolt.fill", "flame.fill", "star.fill"]
            case .gratitude:
                return ["hands.sparkles.fill", "star.fill", "heart.fill"]
            case .joy:
                return ["face.smiling.fill", "star.fill", "sparkles"]
            case .grace:
                return ["dove.fill", "sparkles", "star.fill"]
            case .fear:
                return ["shield.fill", "star.fill", "sparkles"]
            case .anxiety:
                return ["leaf.fill", "sparkles", "circle.fill"]
            case .rest:
                return ["moon.stars.fill", "sparkles", "cloud.fill"]
            case .wisdom:
                return ["book.fill", "star.fill", "lightbulb.fill"]
            case .confidence:
                return ["crown.fill", "star.fill", "bolt.fill"]
            case .destiny:
                return ["star.fill", "crown.fill", "sparkles"]
            case .identity:
                return ["person.fill", "star.fill", "diamond.fill"]
            case .marriage:
                return ["heart.fill", "infinity", "star.fill"]
            case .parenting:
                return ["house.fill", "heart.fill", "star.fill"]
            case .work:
                return ["hammer.fill", "star.fill", "gear.fill"]
            case .health:
                return ["heart.text.square.fill", "plus.circle.fill", "star.fill"]
            case .wealth:
                return ["dollarsign.circle.fill", "star.fill", "diamond.fill"]
            case .favor:
                return ["crown.fill", "star.fill", "sparkles"]
            case .miracles:
                return ["wand.and.stars", "star.fill", "sparkles"]
            case .warfare:
                return ["shield.fill", "sword.fill", "star.fill"]
            case .protection:
                return ["shield.checkerboard", "star.fill", "sparkles"]
            case .purity:
                return ["drop.fill", "sparkles", "star.fill"]
            case .obedience:
                return ["checkmark.circle.fill", "star.fill", "heart.fill"]
            case .spiritualGrowth:
                return ["tree.fill", "star.fill", "sparkles"]
            }
        }
        
        var particleCount: Int {
            switch self {
            case .faith, .hope, .love, .peace:
                return 25
            case .strength, .confidence, .destiny:
                return 30
            case .joy, .gratitude, .celebration:
                return 35
            case .miracles, .favor, .spiritualGrowth:
                return 40
            default:
                return 20
            }
        }
        
        var animationStyle: ParticleAnimationStyle {
            switch self {
            case .faith, .hope:
                return .rising
            case .love, .gratitude, .joy:
                return .floating
            case .peace, .rest:
                return .gentle
            case .strength, .confidence:
                return .energetic
            case .miracles, .favor:
                return .magical
            case .warfare, .protection:
                return .protective
            default:
                return .gentle
            }
        }
        
        static func from(string: String) -> CategoryTheme {
            return CategoryTheme(rawValue: string.lowercased()) ?? .faith
        }
    }
    
    enum ParticleAnimationStyle {
        case rising, floating, gentle, energetic, magical, protective
        
        var duration: Double {
            switch self {
            case .gentle: return 3.0
            case .rising: return 4.0
            case .floating: return 5.0
            case .energetic: return 2.0
            case .magical: return 3.5
            case .protective: return 2.5
            }
        }
        
        var velocity: (x: Double, y: Double) {
            switch self {
            case .gentle: return (x: 20, y: -30)
            case .rising: return (x: 10, y: -80)
            case .floating: return (x: 30, y: -20)
            case .energetic: return (x: 50, y: -60)
            case .magical: return (x: 40, y: -70)
            case .protective: return (x: 15, y: -25)
            }
        }
    }
}

// MARK: - Category Particle System

struct CategoryParticleSystem: View {
    let category: CategoryThemeManager.CategoryTheme
    let intensity: ParticleIntensity
    @State private var particles: [CategoryParticleData] = []
    @State private var isActive = false
    
    enum ParticleIntensity {
        case subtle, moderate, intense, celebration
        
        var multiplier: Double {
            switch self {
            case .subtle: return 0.5
            case .moderate: return 1.0
            case .intense: return 1.5
            case .celebration: return 2.5
            }
        }
    }
    
    struct CategoryParticleData: Identifiable {
        let id = UUID()
        var position: CGPoint
        var velocity: CGPoint
        var rotation: Double
        var rotationSpeed: Double
        var scale: CGFloat
        var opacity: Double
        var color: Color
        var symbol: String
        var animationDelay: Double
    }
    
    var body: some View {
        ZStack {
            ForEach(particles) { particle in
                Image(systemName: particle.symbol)
                    .font(.system(size: 12 * particle.scale, weight: .bold))
                    .foregroundColor(particle.color)
                    .opacity(particle.opacity)
                    .rotationEffect(.degrees(particle.rotation))
                    .scaleEffect(particle.scale)
                    .position(particle.position)
            }
        }
        .onAppear {
            generateParticles()
            startAnimation()
        }
    }
    
    private func generateParticles() {
        let count = Int(Double(category.particleCount) * intensity.multiplier)
        let screenWidth = UIScreen.main.bounds.width
        let screenHeight = UIScreen.main.bounds.height
        
        particles = (0..<count).map { index in
            let colors = category.colors
            let symbols = category.symbols
            
            return CategoryParticleData(
                position: CGPoint(
                    x: CGFloat.random(in: 50...(screenWidth - 50)),
                    y: screenHeight + 50 // Start below screen
                ),
                velocity: CGPoint(
                    x: CGFloat.random(in: -CGFloat(category.animationStyle.velocity.x)...CGFloat(category.animationStyle.velocity.x)),
                    y: CGFloat.random(in: -CGFloat(category.animationStyle.velocity.y)...(-CGFloat(category.animationStyle.velocity.y) * 0.5))
                ),
                rotation: Double.random(in: 0...360),
                rotationSpeed: Double.random(in: -180...180),
                scale: CGFloat.random(in: 0.8...1.5),
                opacity: Double.random(in: 0.7...1.0),
                color: colors.randomElement() ?? .white,
                symbol: symbols.randomElement() ?? "star.fill",
                animationDelay: Double.random(in: 0...(category.animationStyle.duration * 0.3))
            )
        }
    }
    
    private func startAnimation() {
        for (index, var particle) in particles.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + particle.animationDelay) {
                withAnimation(.easeOut(duration: category.animationStyle.duration)) {
                    if index < particles.count {
                        particles[index].position.x += particle.velocity.x
                        particles[index].position.y += particle.velocity.y
                        particles[index].rotation += particle.rotationSpeed
                        particles[index].opacity = 0
                        particles[index].scale *= 0.3
                    }
                }
            }
        }
    }
}

// MARK: - Specialized Category Effects

struct FaithCrossEffect: View {
    @State private var crossScale: CGFloat = 0
    @State private var glowIntensity: Double = 0
    @State private var rayAngles: [Double] = []
    
    var body: some View {
        ZStack {
            // Cross symbol
            Image(systemName: "cross.fill")
                .font(.system(size: 60, weight: .bold))
                .foregroundColor(.white)
                .shadow(color: .blue, radius: glowIntensity, x: 0, y: 0)
                .scaleEffect(crossScale)
            
            // Light rays
            ForEach(Array(rayAngles.enumerated()), id: \.offset) { index, angle in
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [.white.opacity(0.8), .clear],
                            startPoint: .center,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: 100, height: 2)
                    .rotationEffect(.degrees(angle))
                    .opacity(glowIntensity > 5 ? 1 : 0)
                    .animation(.easeInOut(duration: 0.5).delay(Double(index) * 0.1), value: glowIntensity)
            }
        }
        .onAppear {
            // Generate ray angles
            rayAngles = (0..<8).map { Double($0) * 45 }
            
            withAnimation(.spring(response: 0.8, dampingFraction: 0.6)) {
                crossScale = 1.0
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    glowIntensity = 10
                }
            }
        }
    }
}

struct LoveHeartBurst: View {
    @State private var hearts: [HeartData] = []
    @State private var centralHeartScale: CGFloat = 0
    
    struct HeartData: Identifiable {
        let id = UUID()
        var position: CGPoint
        var targetPosition: CGPoint
        var scale: CGFloat = 0
        var opacity: Double = 1
        var color: Color
        var delay: Double
    }
    
    var body: some View {
        ZStack {
            // Central heart
            Image(systemName: "heart.fill")
                .font(.system(size: 50, weight: .bold))
                .foregroundColor(.red)
                .scaleEffect(centralHeartScale)
                .glow(color: .pink, intensity: 0.8)
            
            // Surrounding hearts
            ForEach(hearts) { heart in
                Image(systemName: "heart.fill")
                    .font(.system(size: 20))
                    .foregroundColor(heart.color)
                    .scaleEffect(heart.scale)
                    .opacity(heart.opacity)
                    .position(heart.position)
            }
        }
        .onAppear {
            generateHearts()
            startHeartAnimation()
        }
    }
    
    private func generateHearts() {
        let center = CGPoint(x: UIScreen.main.bounds.width / 2, y: UIScreen.main.bounds.height / 2)
        let colors: [Color] = [.red, .pink, .white]
        
        hearts = (0..<12).map { index in
            let angle = Double(index) * (360.0 / 12.0)
            let radius: CGFloat = 80
            
            let targetX = center.x + cos(angle * .pi / 180) * radius
            let targetY = center.y + sin(angle * .pi / 180) * radius
            
            return HeartData(
                position: center,
                targetPosition: CGPoint(x: targetX, y: targetY),
                color: colors.randomElement() ?? .red,
                delay: Double(index) * 0.1
            )
        }
    }
    
    private func startHeartAnimation() {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
            centralHeartScale = 1.0
        }
        
        for (index, var heart) in hearts.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + heart.delay) {
                withAnimation(.spring(response: 0.8, dampingFraction: 0.6)) {
                    hearts[index].scale = 1.0
                    hearts[index].position = heart.targetPosition
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    withAnimation(.easeOut(duration: 1.5)) {
                        hearts[index].opacity = 0
                        hearts[index].scale = 0.3
                    }
                }
            }
        }
    }
}

struct PeaceWaveEffect: View {
    @State private var waveOffsets: [CGFloat] = [0, 0, 0]
    @State private var waveOpacities: [Double] = [0.8, 0.6, 0.4]
    
    var body: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { index in
                WaveShape(offset: waveOffsets[index], frequency: 3 + Double(index))
                    .stroke(
                        LinearGradient(
                            colors: [.blue, .teal, .mint],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        lineWidth: 3
                    )
                    .opacity(waveOpacities[index])
                    .animation(
                        .linear(duration: 2.0 + Double(index) * 0.5)
                        .repeatForever(autoreverses: false),
                        value: waveOffsets[index]
                    )
            }
        }
        .onAppear {
            for index in 0..<3 {
                waveOffsets[index] = 1.0
            }
        }
    }
}

struct WaveShape: Shape {
    var offset: CGFloat
    var frequency: Double
    
    var animatableData: CGFloat {
        get { offset }
        set { offset = newValue }
    }
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height
        let midHeight = height / 2
        
        path.move(to: CGPoint(x: 0, y: midHeight))
        
        for x in stride(from: 0, through: width, by: 1) {
            let relativeX = x / width
            let sine = sin((relativeX * frequency * 2 * .pi) + (offset * 2 * .pi))
            let y = midHeight + (sine * 20)
            path.addLine(to: CGPoint(x: x, y: y))
        }
        
        return path
    }
}

struct StrengthLightningEffect: View {
    @State private var lightningPaths: [Path] = []
    @State private var showLightning = false
    @State private var glowIntensity: Double = 0
    
    var body: some View {
        ZStack {
            // Lightning bolts
            ForEach(0..<lightningPaths.count, id: \.self) { index in
                lightningPaths[index]
                    .stroke(
                        LinearGradient(
                            colors: [.yellow, .orange, .red],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 4
                    )
                    .shadow(color: .yellow, radius: glowIntensity, x: 0, y: 0)
                    .opacity(showLightning ? 1 : 0)
                    .animation(
                        .easeInOut(duration: 0.2)
                        .delay(Double(index) * 0.1),
                        value: showLightning
                    )
            }
        }
        .onAppear {
            generateLightning()
            startLightningAnimation()
        }
    }
    
    private func generateLightning() {
        let screenWidth = UIScreen.main.bounds.width
        let screenHeight = UIScreen.main.bounds.height
        
        lightningPaths = (0..<3).map { _ in
            var path = Path()
            let startX = CGFloat.random(in: 100...(screenWidth - 100))
            let startY: CGFloat = 100
            
            path.move(to: CGPoint(x: startX, y: startY))
            
            var currentX = startX
            var currentY = startY
            
            // Create zigzag pattern
            for _ in 0..<8 {
                currentY += CGFloat.random(in: 30...60)
                currentX += CGFloat.random(in: -30...30)
                path.addLine(to: CGPoint(x: currentX, y: currentY))
                
                if currentY > screenHeight - 200 {
                    break
                }
            }
            
            return path
        }
    }
    
    private func startLightningAnimation() {
        withAnimation(.easeIn(duration: 0.1)) {
            showLightning = true
            glowIntensity = 15
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.easeOut(duration: 0.3)) {
                showLightning = false
                glowIntensity = 0
            }
        }
    }
}

// MARK: - Category Effect Factory

struct CategoryEffectFactory {
    static func createEffect(for category: String, intensity: CategoryParticleSystem.ParticleIntensity = .moderate) -> AnyView {
        let theme = CategoryThemeManager.CategoryTheme.from(string: category)
        
        switch theme {
        case .faith:
            return AnyView(
                ZStack {
                    FaithCrossEffect()
                    CategoryParticleSystem(category: theme, intensity: intensity)
                }
            )
        case .love:
            return AnyView(
                ZStack {
                    LoveHeartBurst()
                    CategoryParticleSystem(category: theme, intensity: intensity)
                }
            )
        case .peace, .rest:
            return AnyView(
                ZStack {
                    PeaceWaveEffect()
                    CategoryParticleSystem(category: theme, intensity: intensity)
                }
            )
        case .strength, .confidence:
            return AnyView(
                ZStack {
                    StrengthLightningEffect()
                    CategoryParticleSystem(category: theme, intensity: intensity)
                }
            )
        default:
            return AnyView(CategoryParticleSystem(category: theme, intensity: intensity))
        }
    }
}

// MARK: - View Extensions

extension View {
    func categoryParticleEffect(
        category: String,
        intensity: CategoryParticleSystem.ParticleIntensity = .moderate,
        isActive: Bool = true
    ) -> some View {
        self.overlay(
            Group {
                if isActive {
                    CategoryEffectFactory.createEffect(for: category, intensity: intensity)
                }
            }
        )
    }
}