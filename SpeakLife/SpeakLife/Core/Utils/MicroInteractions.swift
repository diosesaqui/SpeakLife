//
//  MicroInteractions.swift
//  SpeakLife
//
//  Premium micro-interaction animations for enhanced user experience
//

import SwiftUI
import Foundation
import CoreGraphics

// MARK: - Card Tap Animation

struct CardTapAnimation: ViewModifier {
    @State private var isPressed = false
    @State private var shadowRadius: CGFloat = 5
    @State private var shadowOpacity: Double = 0.2
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .shadow(
                color: Color.black.opacity(shadowOpacity),
                radius: shadowRadius,
                x: 0,
                y: shadowRadius * 0.4
            )
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isPressed)
            .onTapGesture {
                PremiumHaptics.cardTap()
                
                withAnimation(.spring(response: 0.15, dampingFraction: 0.8)) {
                    isPressed = true
                    shadowRadius = 12
                    shadowOpacity = 0.4
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isPressed = false
                        shadowRadius = 5
                        shadowOpacity = 0.2
                    }
                }
            }
    }
}

// MARK: - Button Morphing Effect

struct MorphingButton: View {
    let title: String
    let action: () -> Void
    @State private var isSuccess = false
    @State private var buttonWidth: CGFloat = 120
    @State private var showCheckmark = false
    @State private var buttonOpacity: Double = 1.0
    
    var body: some View {
        Button(action: handleTap) {
            HStack {
                if showCheckmark {
                    Image(systemName: "checkmark")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .scaleEffect(showCheckmark ? 1.0 : 0.0)
                        .animation(.spring(response: 0.4, dampingFraction: 0.6), value: showCheckmark)
                } else {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .opacity(buttonOpacity)
                }
            }
            .frame(width: buttonWidth, height: 44)
            .background(
                RoundedRectangle(cornerRadius: 22)
                    .fill(isSuccess ? Color.green : Color.blue)
                    .animation(.easeInOut(duration: 0.3), value: isSuccess)
            )
        }
        .disabled(isSuccess)
    }
    
    private func handleTap() {
        PremiumHaptics.safeSuccessSequence()
        action()
        
        withAnimation(.easeInOut(duration: 0.2)) {
            buttonOpacity = 0.0
            buttonWidth = 44
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                isSuccess = true
                showCheckmark = true
            }
        }
        
        // Reset after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeInOut(duration: 0.3)) {
                isSuccess = false
                showCheckmark = false
                buttonOpacity = 1.0
                buttonWidth = 120
            }
        }
    }
}

// MARK: - Heart Pulse Animation

struct HeartPulse: View {
    let isFavorited: Bool
    @State private var pulseScale: CGFloat = 1.0
    @State private var ringScales: [CGFloat] = [0, 0, 0]
    @State private var ringOpacities: [Double] = [0, 0, 0]
    
    var body: some View {
        ZStack {
            // Expanding rings
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .stroke(Color.red.opacity(0.4), lineWidth: 2)
                    .scaleEffect(ringScales[index])
                    .opacity(ringOpacities[index])
                    .animation(
                        .easeOut(duration: 0.8)
                        .delay(Double(index) * 0.15),
                        value: ringScales[index]
                    )
            }
            
            // Heart icon
            Image(systemName: isFavorited ? "heart.fill" : "heart")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(isFavorited ? .red : .gray)
                .scaleEffect(pulseScale)
                .animation(.spring(response: 0.4, dampingFraction: 0.6), value: pulseScale)
        }
        .onTapGesture {
            if isFavorited {
                PremiumHaptics.favoriteAdded()
                triggerPulse()
            } else {
                PremiumHaptics.favoriteRemoved()
            }
        }
        .onChange(of: isFavorited) { favorited in
            if favorited {
                triggerPulse()
            }
        }
    }
    
    private func triggerPulse() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
            pulseScale = 1.3
        }
        
        // Trigger rings
        for i in 0..<3 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.15) {
                withAnimation(.easeOut(duration: 0.8)) {
                    ringScales[i] = 2.0 + CGFloat(i) * 0.5
                    ringOpacities[i] = 1.0
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    withAnimation(.easeOut(duration: 0.3)) {
                        ringOpacities[i] = 0
                    }
                }
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                pulseScale = 1.0
            }
        }
        
        // Reset rings
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            ringScales = [0, 0, 0]
            ringOpacities = [0, 0, 0]
        }
    }
}

// MARK: - Breathing Animation

struct BreathingCircle: View {
    @State private var isExpanded = false
    let color: Color
    let duration: Double
    
    init(color: Color = .blue.opacity(0.3), duration: Double = 4.0) {
        self.color = color
        self.duration = duration
    }
    
    var body: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [color, color.opacity(0.1), Color.clear],
                    center: .center,
                    startRadius: 20,
                    endRadius: isExpanded ? 100 : 60
                )
            )
            .scaleEffect(isExpanded ? 1.2 : 0.8)
            .opacity(isExpanded ? 0.8 : 0.4)
            .animation(
                .easeInOut(duration: duration)
                .repeatForever(autoreverses: true),
                value: isExpanded
            )
            .onAppear {
                isExpanded = true
            }
    }
}

// MARK: - Shimmer Effect

struct ShimmerEffect: ViewModifier {
    @State private var shimmerOffset: CGFloat = -1
    
    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    colors: [
                        Color.clear,
                        Color.white.opacity(0.3),
                        Color.white.opacity(0.6),
                        Color.white.opacity(0.3),
                        Color.clear
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .mask(content)
                .offset(x: shimmerOffset * 300)
            )
            .onAppear {
                withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: false)) {
                    shimmerOffset = 1
                }
            }
    }
}

// MARK: - Glow Effect

struct GlowEffect: ViewModifier {
    let color: Color
    let intensity: Double
    @State private var glowAnimation = false
    
    func body(content: Content) -> some View {
        content
            .shadow(
                color: color.opacity(glowAnimation ? intensity : intensity * 0.3),
                radius: glowAnimation ? 20 : 10,
                x: 0,
                y: 0
            )
            .animation(
                .easeInOut(duration: 1.5)
                .repeatForever(autoreverses: true),
                value: glowAnimation
            )
            .onAppear {
                glowAnimation = true
            }
    }
}

// MARK: - Floating Animation

struct FloatingAnimation: ViewModifier {
    @State private var offset: CGFloat = 0
    let amplitude: CGFloat
    let duration: Double
    
    init(amplitude: CGFloat = 10, duration: Double = 2.0) {
        self.amplitude = amplitude
        self.duration = duration
    }
    
    func body(content: Content) -> some View {
        content
            .offset(y: offset)
            .animation(
                .easeInOut(duration: duration)
                .repeatForever(autoreverses: true),
                value: offset
            )
            .onAppear {
                offset = amplitude
            }
    }
}

// MARK: - Scale Bounce Effect

struct ScaleBounce: ViewModifier {
    @State private var scale: CGFloat = 1.0
    let bounceScale: CGFloat
    let duration: Double
    
    init(bounceScale: CGFloat = 1.05, duration: Double = 1.0) {
        self.bounceScale = bounceScale
        self.duration = duration
    }
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .animation(
                .easeInOut(duration: duration)
                .repeatForever(autoreverses: true),
                value: scale
            )
            .onAppear {
                scale = bounceScale
            }
    }
}

// MARK: - Page Turn Effect

struct PageTurn: ViewModifier {
    @State private var rotationAngle: Double = 0
    let isActive: Bool
    
    func body(content: Content) -> some View {
        content
            .rotation3DEffect(
                .degrees(rotationAngle),
                axis: (x: 0, y: 1, z: 0),
                anchor: .trailing,
                perspective: 0.8
            )
            .animation(.easeInOut(duration: 0.6), value: rotationAngle)
            .onChange(of: isActive) { active in
                if active {
                    rotationAngle = -90
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        rotationAngle = 0
                    }
                }
            }
    }
}

// MARK: - View Extensions

extension View {
    func cardTapAnimation() -> some View {
        self.modifier(CardTapAnimation())
    }
    
    func shimmer() -> some View {
        self.modifier(ShimmerEffect())
    }
    
    func glow(color: Color = .white, intensity: Double = 0.5) -> some View {
        self.modifier(GlowEffect(color: color, intensity: intensity))
    }
    
    func floating(amplitude: CGFloat = 10, duration: Double = 2.0) -> some View {
        self.modifier(FloatingAnimation(amplitude: amplitude, duration: duration))
    }
    
    func scaleBounce(bounceScale: CGFloat = 1.05, duration: Double = 1.0) -> some View {
        self.modifier(ScaleBounce(bounceScale: bounceScale, duration: duration))
    }
    
    func pageTurn(isActive: Bool) -> some View {
        self.modifier(PageTurn(isActive: isActive))
    }
}