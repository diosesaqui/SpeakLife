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

#Preview {
    ModernCelebrationView(accentColor: .green)
        .frame(width: 200, height: 200)
        .background(Color.black.opacity(0.1))
}
