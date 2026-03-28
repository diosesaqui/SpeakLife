//
//  ModernCelebrationView.swift
//  SpeakLife
//
//  Apple-worthy celebration animation for task completion
//

import SwiftUI

struct ModernCelebrationView: View {
    @State private var checkmarkScale: CGFloat = 0
    @State private var checkmarkOpacity: Double = 0
    @State private var pulseScale: CGFloat = 0
    @State private var pulseOpacity: Double = 0.8
    @State private var sparksOpacity: Double = 0
    @State private var showConfetti = false
    
    let accentColor: Color
    
    init(accentColor: Color = .blue) {
        self.accentColor = accentColor
    }
    
    var body: some View {
        ZStack {
            // Pulse background
            Circle()
                .fill(accentColor.opacity(0.3))
                .scaleEffect(pulseScale)
                .opacity(pulseOpacity)
                .frame(width: 80, height: 80)
            
            // Success checkmark
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60, weight: .bold))
                .foregroundColor(accentColor)
                .scaleEffect(checkmarkScale)
                .opacity(checkmarkOpacity)
            
            // Sparkling stars around
            ForEach(0..<8, id: \.self) { index in
                SparkleCelebrationView(index: index, show: sparksOpacity > 0)
                    .opacity(sparksOpacity)
            }
            
            // Confetti particles
            if showConfetti {
                LightweightConfettiView(particleCount: 30)
            }
        }
        .onAppear {
            startCelebration()
        }
    }
    
    private func startCelebration() {
        // Immediate pulse effect
        withAnimation(.easeOut(duration: 0.6)) {
            pulseScale = 1.5
            pulseOpacity = 0
        }
        
        // Checkmark appears quickly with bounce
        withAnimation(.interpolatingSpring(stiffness: 300, damping: 15).delay(0.1)) {
            checkmarkScale = 1.0
            checkmarkOpacity = 1.0
        }
        
        // Sparkles appear
        withAnimation(.easeOut(duration: 0.4).delay(0.3)) {
            sparksOpacity = 1.0
        }
        
        // Show confetti
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            showConfetti = true
        }
        
        // Fade out sparkles
        withAnimation(.easeIn(duration: 0.5).delay(1.0)) {
            sparksOpacity = 0
        }
        
        // Scale down checkmark slightly for final state
        withAnimation(.easeInOut(duration: 0.3).delay(1.2)) {
            checkmarkScale = 0.9
        }
    }
}

struct SparkleCelebrationView: View {
    let index: Int
    let show: Bool
    @State private var offset: CGPoint = .zero
    @State private var scale: CGFloat = 0
    @State private var rotation: Double = 0
    
    private let distance: CGFloat = 60
    private let angle: Double
    
    init(index: Int, show: Bool) {
        self.index = index
        self.show = show
        self.angle = Double(index) * 45.0 // 8 sparkles at 45° intervals
    }
    
    var body: some View {
        Image(systemName: "sparkle")
            .font(.system(size: 12, weight: .bold))
            .foregroundColor(.yellow)
            .scaleEffect(scale)
            .rotationEffect(.degrees(rotation))
            .offset(x: offset.x, y: offset.y)
            .onChange(of: show) { newValue in
                if newValue {
                    startSparkle()
                }
            }
    }
    
    private func startSparkle() {
        let targetX = cos(angle * .pi / 180) * distance
        let targetY = sin(angle * .pi / 180) * distance
        
        withAnimation(.easeOut(duration: 0.6).delay(Double(index) * 0.05)) {
            offset = CGPoint(x: targetX, y: targetY)
            scale = 1.0
            rotation = 180
        }
        
        withAnimation(.easeIn(duration: 0.4).delay(0.8)) {
            scale = 0
        }
    }
}

struct LightweightConfettiView: View {
    let particleCount: Int
    @State private var particles: [ConfettiParticleState] = []
    
    var body: some View {
        ZStack {
            ForEach(particles.indices, id: \.self) { index in
                ConfettiParticleView(particle: particles[index])
            }
        }
        .onAppear {
            initializeParticles()
        }
    }
    
    private func initializeParticles() {
        particles = (0..<particleCount).map { _ in
            ConfettiParticleState()
        }
    }
}

struct ConfettiParticleState {
    let id = UUID()
    let startX: CGFloat = CGFloat.random(in: -200...200)
    let startY: CGFloat = CGFloat.random(in: -50...50)
    let endY: CGFloat = CGFloat.random(in: 300...500)
    let color: Color = [.red, .blue, .green, .yellow, .orange, .purple].randomElement() ?? .blue
    let size: CGFloat = CGFloat.random(in: 4...8)
    let rotationSpeed: Double = Double.random(in: 180...360)
    let duration: Double = Double.random(in: 1.5...2.5)
}

struct ConfettiParticleView: View {
    let particle: ConfettiParticleState
    @State private var yOffset: CGFloat = 0
    @State private var rotation: Double = 0
    @State private var opacity: Double = 1
    
    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(particle.color)
            .frame(width: particle.size, height: particle.size)
            .rotationEffect(.degrees(rotation))
            .opacity(opacity)
            .offset(x: particle.startX, y: particle.startY + yOffset)
            .onAppear {
                withAnimation(.easeIn(duration: particle.duration)) {
                    yOffset = particle.endY
                    opacity = 0
                }
                
                withAnimation(.linear(duration: particle.duration)) {
                    rotation = particle.rotationSpeed
                }
            }
    }
}

// MARK: - Streak Completion Celebration View
struct StreakCompletionCelebrationView: View {
    let streakCount: Int
    @State private var fireScale: CGFloat = 0
    @State private var fireOpacity: Double = 0
    @State private var numberScale: CGFloat = 0
    @State private var numberOpacity: Double = 0
    @State private var ringScale: CGFloat = 0
    @State private var ringOpacity: Double = 0.8
    @State private var showEmbers = false
    @State private var showStars = false
    @State private var pulseAnimation = false
    
    var body: some View {
        ZStack {
            // Expanding ring pulse
            Circle()
                .stroke(LinearGradient(
                    colors: [.orange, .red],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ), lineWidth: 3)
                .scaleEffect(ringScale)
                .opacity(ringOpacity)
                .frame(width: 100, height: 100)
            
            // Fire icon with gradient
            ZStack {
                Image(systemName: "flame.fill")
                    .font(.system(size: 60, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.yellow, .orange, .red],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .scaleEffect(fireScale)
                    .opacity(fireOpacity)
                    .scaleEffect(pulseAnimation ? 1.1 : 1.0)
                    .shadow(color: .orange.opacity(0.5), radius: 10)
                
                // Streak number overlay
                Text("\(streakCount)")
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .scaleEffect(numberScale)
                    .opacity(numberOpacity)
                    .offset(y: 5)
            }
            
            // Ember particles floating up
            if showEmbers {
                ForEach(0..<12, id: \.self) { index in
                    EmberParticleView(index: index)
                }
            }
            
            // Star burst effect
            if showStars {
                ForEach(0..<6, id: \.self) { index in
                    StarBurstView(index: index, color: .yellow)
                }
            }
        }
        .onAppear {
            startStreakCelebration()
        }
    }
    
    private func startStreakCelebration() {
        // Ring expansion
        withAnimation(.easeOut(duration: 0.8)) {
            ringScale = 1.8
            ringOpacity = 0
        }
        
        // Fire appears with bounce
        withAnimation(.interpolatingSpring(stiffness: 350, damping: 12)) {
            fireScale = 1.0
            fireOpacity = 1.0
        }
        
        // Number appears slightly after
        withAnimation(.interpolatingSpring(stiffness: 300, damping: 15).delay(0.2)) {
            numberScale = 1.0
            numberOpacity = 1.0
        }
        
        // Show embers
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            showEmbers = true
        }
        
        // Show stars
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            showStars = true
        }
        
        // Start pulse animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation(.easeInOut(duration: 0.8).repeatCount(2, autoreverses: true)) {
                pulseAnimation = true
            }
        }
    }
}

struct EmberParticleView: View {
    let index: Int
    @State private var yOffset: CGFloat = 0
    @State private var xOffset: CGFloat = 0
    @State private var opacity: Double = 1
    @State private var scale: CGFloat = 0
    
    private let startX: CGFloat
    private let targetY: CGFloat = -120
    private let duration: Double
    
    init(index: Int) {
        self.index = index
        self.startX = CGFloat.random(in: -30...30)
        self.duration = Double.random(in: 1.2...2.0)
    }
    
    var body: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [.yellow, .orange],
                    center: .center,
                    startRadius: 0,
                    endRadius: 3
                )
            )
            .frame(width: 6, height: 6)
            .scaleEffect(scale)
            .opacity(opacity)
            .offset(x: startX + xOffset, y: yOffset)
            .onAppear {
                withAnimation(.easeOut(duration: duration).delay(Double(index) * 0.1)) {
                    yOffset = targetY
                    xOffset = CGFloat.random(in: -20...20)
                    opacity = 0
                    scale = 1.2
                }
                
                withAnimation(.easeIn(duration: 0.3)) {
                    scale = 1.0
                }
            }
    }
}

struct StarBurstView: View {
    let index: Int
    let color: Color
    @State private var offset: CGPoint = .zero
    @State private var scale: CGFloat = 0
    @State private var rotation: Double = 0
    @State private var opacity: Double = 1
    
    private let distance: CGFloat = 80
    private let angle: Double
    
    init(index: Int, color: Color) {
        self.index = index
        self.color = color
        self.angle = Double(index) * 60.0 // 6 stars at 60° intervals
    }
    
    var body: some View {
        Image(systemName: "star.fill")
            .font(.system(size: 14, weight: .bold))
            .foregroundColor(color)
            .scaleEffect(scale)
            .rotationEffect(.degrees(rotation))
            .opacity(opacity)
            .offset(x: offset.x, y: offset.y)
            .onAppear {
                let targetX = cos(angle * .pi / 180) * distance
                let targetY = sin(angle * .pi / 180) * distance
                
                withAnimation(.easeOut(duration: 0.7).delay(Double(index) * 0.05)) {
                    offset = CGPoint(x: targetX, y: targetY)
                    scale = 1.2
                    rotation = 360
                }
                
                withAnimation(.easeIn(duration: 0.4).delay(0.9)) {
                    scale = 0
                    opacity = 0
                }
            }
    }
}

#Preview {
    VStack(spacing: 50) {
        ModernCelebrationView(accentColor: .green)
            .frame(width: 200, height: 200)
            .background(Color.black.opacity(0.1))
        
        StreakCompletionCelebrationView(streakCount: 7)
            .frame(width: 200, height: 200)
            .background(Color.black.opacity(0.1))
    }
}
