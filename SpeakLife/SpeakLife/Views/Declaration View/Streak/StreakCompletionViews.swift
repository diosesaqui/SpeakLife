//
//  StreakCompletionViews.swift
//  SpeakLife
//
//  Fire animation and completion celebration views
//

import SwiftUI
import Photos

// MARK: - Fire Animation View
struct FireStreakView: View {
    let streakNumber: Int
    @State private var animateFlames = false
    @State private var animateNumber = false
    @State private var showSparkles = false
    
    var body: some View {
        ZStack {
            // Background blur
            Color.black.opacity(0.6)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                // Fire animation with streak number
                ZStack {
                    // Animated flames
                    ForEach(0..<5, id: \.self) { index in
                        FlameShape()
                            .fill(
                                LinearGradient(
                                    colors: [.red, .orange, .yellow],
                                    startPoint: .bottom,
                                    endPoint: .top
                                )
                            )
                            .frame(width: 60 + CGFloat(index * 10), height: 80 + CGFloat(index * 15))
                            .offset(y: animateFlames ? -10 : 10)
                            .animation(
                                .easeInOut(duration: 0.8 + Double(index) * 0.2)
                                .repeatForever(autoreverses: true),
                                value: animateFlames
                            )
                            .opacity(0.8 - Double(index) * 0.15)
                    }
                    
                    // Streak number
                    Text("\(streakNumber)")
                        .font(.system(size: 72, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 2)
                        .scaleEffect(animateNumber ? 1.2 : 0.8)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: animateNumber)
                }
                
                // Sparkles effect
                if showSparkles {
                    ForEach(0..<12, id: \.self) { index in
                        SparkleView()
                            .offset(
                                x: cos(Double(index) * .pi / 6) * 100,
                                y: sin(Double(index) * .pi / 6) * 100
                            )
                    }
                }
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.5)) {
                animateFlames = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    animateNumber = true
                }
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                showSparkles = true
            }
        }
    }
}

struct FlameShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        let width = rect.width
        let height = rect.height
        
        path.move(to: CGPoint(x: width * 0.5, y: height))
        
        // Left side of flame
        path.addCurve(
            to: CGPoint(x: width * 0.2, y: height * 0.6),
            control1: CGPoint(x: width * 0.3, y: height * 0.9),
            control2: CGPoint(x: width * 0.1, y: height * 0.8)
        )
        
        path.addCurve(
            to: CGPoint(x: width * 0.5, y: 0),
            control1: CGPoint(x: width * 0.2, y: height * 0.3),
            control2: CGPoint(x: width * 0.4, y: height * 0.1)
        )
        
        // Right side of flame
        path.addCurve(
            to: CGPoint(x: width * 0.8, y: height * 0.6),
            control1: CGPoint(x: width * 0.6, y: height * 0.1),
            control2: CGPoint(x: width * 0.9, y: height * 0.3)
        )
        
        path.addCurve(
            to: CGPoint(x: width * 0.5, y: height),
            control1: CGPoint(x: width * 0.9, y: height * 0.8),
            control2: CGPoint(x: width * 0.7, y: height * 0.9)
        )
        
        return path
    }
}

struct SparkleView: View {
    @State private var animate = false
    @State private var opacity: Double = 1.0
    
    var body: some View {
        Image(systemName: "star.fill")
            .font(.system(size: CGFloat.random(in: 12...20)))
            .foregroundColor(.yellow)
            .opacity(opacity)
            .scaleEffect(animate ? 1.5 : 0.5)
            .animation(
                .easeInOut(duration: Double.random(in: 0.5...1.5))
                .repeatForever(autoreverses: true),
                value: animate
            )
            .onAppear {
                animate = true
                
                withAnimation(.easeOut(duration: 2.0)) {
                    opacity = 0
                }
            }
    }
}

// MARK: - Stunning Completion Celebration View
// MARK: - Supporting Components for Enhanced Celebration

struct AnimatedGradientBackground: View {
    @State private var animateGradient = false
    @State private var shimmerOffset: CGFloat = -1
    
    var body: some View {
        ZStack {
            // Base gradient
            LinearGradient(
                colors: [
                    Color(red: 0.1, green: 0.0, blue: 0.3),
                    Color(red: 0.3, green: 0.1, blue: 0.5),
                    Color(red: 0.1, green: 0.0, blue: 0.4),
                    Color(red: 0.0, green: 0.1, blue: 0.3)
                ],
                startPoint: animateGradient ? .topLeading : .bottomTrailing,
                endPoint: animateGradient ? .bottomTrailing : .topLeading
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
                startPoint: .topLeading,
                endPoint: .bottomTrailing
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
        .onAppear {
            withAnimation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true)) {
                animateGradient.toggle()
            }
            
            withAnimation(.linear(duration: 2.5).repeatForever(autoreverses: false)) {
                shimmerOffset = 1
            }
        }
    }
}

struct ParticleLayer: View {
    let count: Int
    let type: ParticleType
    
    enum ParticleType {
        case sparkles, stars, circles
    }
    
    var body: some View {
        ZStack {
            ForEach(0..<count, id: \.self) { index in
                particleView(for: type, index: index)
                    .position(
                        x: CGFloat.random(in: 0...UIScreen.main.bounds.width),
                        y: CGFloat.random(in: 0...UIScreen.main.bounds.height)
                    )
                    .animation(
                        .easeInOut(duration: Double.random(in: 2...5))
                        .repeatForever(autoreverses: true)
                        .delay(Double.random(in: 0...2)),
                        value: UUID()
                    )
            }
        }
    }
    
    @ViewBuilder
    private func particleView(for type: ParticleType, index: Int) -> some View {
        switch type {
        case .sparkles:
            Image(systemName: "sparkles")
                .font(.system(size: CGFloat.random(in: 8...16)))
                .foregroundColor(.white.opacity(Double.random(in: 0.3...0.8)))
        case .stars:
            Image(systemName: "star.fill")
                .font(.system(size: CGFloat.random(in: 6...12)))
                .foregroundColor(.yellow.opacity(Double.random(in: 0.4...0.9)))
        case .circles:
            Circle()
                .fill(Color.white.opacity(Double.random(in: 0.2...0.6)))
                .frame(width: CGFloat.random(in: 3...8), height: CGFloat.random(in: 3...8))
        }
    }
}

struct FloatingOrbs: View {
    @State private var orbPositions: [CGPoint] = []
    
    var body: some View {
        ZStack {
            ForEach(0..<8, id: \.self) { index in
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.white.opacity(0.2),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 5,
                            endRadius: 30
                        )
                    )
                    .frame(width: CGFloat.random(in: 40...80), height: CGFloat.random(in: 40...80))
                    .position(orbPositions.indices.contains(index) ? orbPositions[index] : CGPoint(x: 0, y: 0))
                    .animation(
                        .easeInOut(duration: Double.random(in: 3...6))
                        .repeatForever(autoreverses: true),
                        value: orbPositions
                    )
            }
        }
        .onAppear {
            generateOrbPositions()
            Timer.scheduledTimer(withTimeInterval: 4.0, repeats: true) { _ in
                generateOrbPositions()
            }
        }
    }
    
    private func generateOrbPositions() {
        orbPositions = (0..<8).map { _ in
            CGPoint(
                x: CGFloat.random(in: 50...UIScreen.main.bounds.width - 50),
                y: CGFloat.random(in: 100...UIScreen.main.bounds.height - 100)
            )
        }
    }
}

struct StunningFireDisplay: View {
    let streakNumber: Int
    let showContent: Bool
    @State private var flameAnimations: [Bool] = Array(repeating: false, count: 7)
    @State private var numberScale: CGFloat = 0
    @State private var glowIntensity: Double = 0
    @State private var sparkleRotation: Double = 0
    @State private var numberShimmer: CGFloat = -1
    
    var body: some View {
        ZStack {
            // Rotating sparkle ring
            ForEach(0..<12, id: \.self) { index in
                Image(systemName: "sparkles")
                    .font(.system(size: 16))
                    .foregroundColor(.yellow.opacity(0.8))
                    .offset(
                        x: cos(Double(index) * .pi / 6 + sparkleRotation) * 80,
                        y: sin(Double(index) * .pi / 6 + sparkleRotation) * 80
                    )
                    .opacity(showContent ? 1 : 0)
                    .animation(.easeInOut(duration: 0.5).delay(Double(index) * 0.1), value: showContent)
            }
            
            // Multiple flame layers for depth with enhanced effects
            ForEach(0..<7, id: \.self) { index in
                FlameShape()
                    .fill(
                        RadialGradient(
                            colors: enhancedFlameColors(for: index),
                            center: .bottom,
                            startRadius: 10,
                            endRadius: 80
                        )
                    )
                    .frame(
                        width: 80 + CGFloat(index * 8),
                        height: 100 + CGFloat(index * 12)
                    )
                    .offset(y: flameAnimations[index] ? -CGFloat(8 + index * 2) : CGFloat(8 + index * 2))
                    .opacity(0.9 - Double(index) * 0.1)
                    .shadow(color: flameColors(for: index)[0], radius: 5, x: 0, y: 0)
                    .animation(
                        .easeInOut(duration: 0.8 + Double(index) * 0.1)
                        .repeatForever(autoreverses: true),
                        value: flameAnimations[index]
                    )
            }
            
            // Enhanced glowing streak number with shimmer
            ZStack {
                // Number with glow
                Text("\(streakNumber)")
                    .font(.system(size: 84, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .shadow(color: .orange, radius: glowIntensity, x: 0, y: 0)
                    .shadow(color: .yellow, radius: glowIntensity * 0.5, x: 0, y: 0)
                    .shadow(color: .red, radius: glowIntensity * 0.3, x: 0, y: 0)
                
                // Shimmer overlay
                Text("\(streakNumber)")
                    .font(.system(size: 84, weight: .black, design: .rounded))
                    .foregroundColor(.clear)
                    .overlay(
                        LinearGradient(
                            colors: [
                                Color.clear,
                                Color.white.opacity(0.8),
                                Color.yellow.opacity(0.6),
                                Color.white.opacity(0.8),
                                Color.clear
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .mask(
                            Text("\(streakNumber)")
                                .font(.system(size: 84, weight: .black, design: .rounded))
                        )
                        .offset(x: numberShimmer * 200)
                    )
            }
            .scaleEffect(numberScale)
            .animation(.spring(response: 0.8, dampingFraction: 0.6), value: numberScale)
        }
        .onChange(of: showContent) { show in
            if show {
                startAnimations()
            }
        }
    }
    
    private func flameColors(for index: Int) -> [Color] {
        switch index {
        case 0...2:
            return [.red, .orange, .yellow]
        case 3...4:
            return [.orange, .yellow, .white]
        default:
            return [.yellow, .white, .yellow]
        }
    }
    
    private func enhancedFlameColors(for index: Int) -> [Color] {
        switch index {
        case 0...2:
            return [.red, .orange, .yellow, .white]
        case 3...4:
            return [.orange, .yellow, .white, .yellow]
        default:
            return [.yellow, .white, .yellow, .orange]
        }
    }
    
    private func startAnimations() {
        for index in flameAnimations.indices {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.1) {
                flameAnimations[index] = true
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                numberScale = 1.0
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                glowIntensity = 15
            }
            
            withAnimation(.linear(duration: 3.0).repeatForever(autoreverses: false)) {
                sparkleRotation = .pi * 2
            }
            
            withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: false).delay(0.5)) {
                numberShimmer = 1
            }
        }
    }
}

struct AnimatedDaysText: View {
    let showContent: Bool
    @State private var typewriterText = ""
    @State private var showCursor = true
    private let fullText = "DAYS OF LIFE SPOKEN!"
    
    var body: some View {
        HStack {
            Text(typewriterText)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            
            if showCursor && typewriterText.count < fullText.count {
                Text("|")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                    .opacity(showCursor ? 1 : 0)
                    .animation(.easeInOut(duration: 0.5).repeatForever(), value: showCursor)
            }
        }
        .onChange(of: showContent) { show in
            if show {
                startTypewriter()
            }
        }
    }
    
    private func startTypewriter() {
        typewriterText = ""
        for (index, character) in fullText.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.08) {
                typewriterText += String(character)
            }
        }
        
        withAnimation(.easeInOut(duration: 0.5).repeatForever()) {
            showCursor.toggle()
        }
    }
}

struct PremiumRecordBadge: View {
    let bounce: Bool
    @State private var shimmer = false
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "crown.fill")
                .font(.system(size: 24))
                .foregroundColor(.yellow)
            
            Text("NEW RECORD!")
                .font(.system(size: 20, weight: .black, design: .rounded))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 25)
                .fill(
                    LinearGradient(
                        colors: [.purple, .blue, .purple],
                        startPoint: shimmer ? .leading : .trailing,
                        endPoint: shimmer ? .trailing : .leading
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 25)
                .stroke(Color.white, lineWidth: 2)
        )
        .scaleEffect(bounce ? 1.1 : 1.0)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                shimmer.toggle()
            }
        }
    }
}

struct GlowingMessage: View {
    let text: String
    let showContent: Bool
    let glow: Bool
    
    var body: some View {
        Text(text)
            .font(.system(size: 24, weight: .semibold, design: .rounded))
            .foregroundColor(.white)
            .multilineTextAlignment(.center)
            .shadow(color: .white, radius: glow ? 8 : 2, x: 0, y: 0)
            .padding(.horizontal, 32)
            .scaleEffect(showContent ? 1 : 0)
            .animation(.spring(response: 0.8, dampingFraction: 0.6).delay(1.0), value: showContent)
    }
}

struct StunningShareButton: View {
    let action: () -> Void
    @State private var pulseScale: CGFloat = 1.0
    @State private var gradientAnimation = false
    @State private var shimmerOffset: CGFloat = -1
    @State private var glowIntensity: Double = 0
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 20, weight: .semibold))
                
                Text("Share Victory")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 32)
            .padding(.vertical, 16)
            .background(
                ZStack {
                    // Base gradient
                    RoundedRectangle(cornerRadius: 30)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 1.0, green: 0.3, blue: 0.6),
                                    Color(red: 0.8, green: 0.2, blue: 0.9),
                                    Color(red: 1.0, green: 0.3, blue: 0.6)
                                ],
                                startPoint: gradientAnimation ? .leading : .trailing,
                                endPoint: gradientAnimation ? .trailing : .leading
                            )
                        )
                    
                    // Shimmer effect
                    RoundedRectangle(cornerRadius: 30)
                        .fill(
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
                                .offset(x: shimmerOffset * 300)
                        )
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 30)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.8),
                                Color.white.opacity(0.4),
                                Color.white.opacity(0.8)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )
            )
            .shadow(color: Color(red: 1.0, green: 0.3, blue: 0.6).opacity(glowIntensity), radius: 15, x: 0, y: 0)
            .scaleEffect(pulseScale)
        }
        .buttonStyle(PlainButtonStyle())
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                pulseScale = 1.05
                glowIntensity = 0.6
            }
            withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: false)) {
                gradientAnimation.toggle()
            }
            withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: false).delay(0.5)) {
                shimmerOffset = 1
            }
        }
    }
}

struct ElegantContinueButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text("Continue Journey")
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.9))
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.white.opacity(0.1))
                        )
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct AppLogoView: View {
    @State private var glowIntensity: Double = 0
    
    var body: some View {
        ZStack {
            // Glow effect background
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(glowIntensity * 0.3),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 20,
                        endRadius: 60
                    )
                )
                .frame(width: 120, height: 120)
            
            // Logo container with subtle background
            Circle()
                .fill(Color.white.opacity(0.15))
                .frame(width: 80, height: 80)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                )
            
            // Try to load the app icon
            Group {
                if let appIcon = UIImage(named: "appIconDisplay") ??
                                 UIImage(named: "speaklifeicon") ??
                                 UIImage(named: "AppIcon") {
                    Image(uiImage: appIcon)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 100, height: 100)
                        .clipShape(Circle())
                } else {
                    // Fallback to text logo
                    Text("SL")
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                }
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                glowIntensity = 1.0
            }
        }
    }
}

struct CompletionCelebrationView: View {
    let celebration: CompletionCelebration
    @Environment(\.presentationMode) var presentationMode
    @State private var showContent = false
    @State private var showShareButton = false
    @State private var particleOffset: CGFloat = 0
    @State private var orbScale: CGFloat = 0
    @State private var orbOpacity: Double = 0
    @State private var textGlow = false
    @State private var recordBadgeBounce = false
    
    var body: some View {
        ZStack {
            // Enhanced animated gradient background
            AnimatedGradientBackground()
                .ignoresSafeArea()
            
            // Multiple layers of particle effects
            ParticleLayer(count: 50, type: .sparkles)
            ParticleLayer(count: 30, type: .stars)
            ParticleLayer(count: 20, type: .circles)
            
            // Floating orbs in background
            FloatingOrbs()
            
            VStack(spacing: 0) {
                Spacer()
                
                // Main content with enhanced animations
                if showContent {
                    VStack(spacing: 32) {
                        // Stunning fire display with glow
                        StunningFireDisplay(
                            streakNumber: celebration.streakNumber,
                            showContent: showContent
                        )
                        
                        // Animated days text with typewriter effect
                        AnimatedDaysText(showContent: showContent)
                        
                        // Premium new record badge
                        if celebration.isNewRecord {
                            PremiumRecordBadge(bounce: recordBadgeBounce)
                                .scaleEffect(showContent ? 1 : 0)
                                .animation(.spring(response: 0.8, dampingFraction: 0.5).delay(0.6), value: showContent)
                                .onAppear {
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                                        withAnimation(.spring(response: 0.4, dampingFraction: 0.3).repeatForever()) {
                                            recordBadgeBounce.toggle()
                                        }
                                    }
                                }
                        }
                        
                        // Glowing motivational message
                        GlowingMessage(
                            text: celebration.motivationalMessage,
                            showContent: showContent,
                            glow: textGlow
                        )
                        .onAppear {
                            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                                textGlow.toggle()
                            }
                        }
                        
                        // SpeakLife logo
                        if showContent {
                            AppLogoView()
                                .scaleEffect(showContent ? 1 : 0)
                                .animation(.spring(response: 0.8, dampingFraction: 0.6).delay(1.5), value: showContent)
                        }
                    }
                }
                
                Spacer()
                
                // Premium buttons with animations
                VStack(spacing: 20) {
                    if showShareButton {
                        // Stunning Instagram share button
                        StunningShareButton(action: shareToInstagram)
                            .scaleEffect(showShareButton ? 1 : 0)
                            .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(1.2), value: showShareButton)
                    }
                    
                    // Elegant continue button
                    ElegantContinueButton {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .opacity(showShareButton ? 1 : 0)
                    .animation(.easeInOut(duration: 0.6).delay(1.5), value: showShareButton)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 50)
            }
        }
        .onAppear {
            startCelebrationSequence()
        }
    }
    
    private func startCelebrationSequence() {
        // Stagger the appearance of elements for dramatic effect
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                showContent = true
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                showShareButton = true
            }
        }
        
        // Start text glow animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                textGlow = true
            }
        }
    }
    
    private func shareToInstagram() {
        guard let shareImage = celebration.shareImage else { 
            print("❌ No share image available for sharing")
            return 
        }
        
        print("✅ Share image available: \(shareImage.size), scale: \(shareImage.scale)")
        
        // Create properly sized image for Instagram
        let targetSize = CGSize(width: 1080, height: 1920)
        let resizedImage = resizeImageForInstagram(shareImage, targetSize: targetSize)
        
        // Use Photos approach for consistent behavior across all screens
        print("📱 Using Photos approach for reliable Instagram sharing")
        trySaveToPhotosForManualShare(image: resizedImage)
    }
    
    // MARK: - Instagram Sharing Helper Methods
    
    private func resizeImageForInstagram(_ image: UIImage, targetSize: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
    
    private func trySaveToPhotosForManualShare(image: UIImage) {
        // Request photos permission first
       // let photos = PHPhotoLibrary.shared()
        
        PHPhotoLibrary.requestAuthorization { status in
            DispatchQueue.main.async {
                switch status {
                case .authorized, .limited:
                    self.saveImageToPhotos(image: image)
                case .denied, .restricted:
                    print("❌ Photos access denied")
                    self.showPhotosPermissionAlert()
                case .notDetermined:
                    print("❌ Photos permission not determined")
                @unknown default:
                    print("❌ Unknown photos permission status")
                }
            }
        }
    }
    
    private func saveImageToPhotos(image: UIImage) {
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.creationRequestForAsset(from: image)
        }) { success, error in
            DispatchQueue.main.async {
                if success {
                    print("✅ Image saved to Photos")
                    self.showImageSavedAlert()
                } else {
                    print("❌ Failed to save image: \(error?.localizedDescription ?? "Unknown error")")
                }
            }
        }
    }
    
    private func showImageSavedAlert() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootViewController = window.rootViewController else {
            return
        }
        
        let alert = UIAlertController(
            title: "🎉 Image Saved!",
            message: "Your streak achievement has been saved to Photos. Open Instagram and create a new Story to share it!",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Open Instagram", style: .default) { _ in
            if let instagramURL = URL(string: "instagram://story-camera"),
               UIApplication.shared.canOpenURL(instagramURL) {
                UIApplication.shared.open(instagramURL)
            }
        })
        
        alert.addAction(UIAlertAction(title: "OK", style: .cancel))
        
        var topController = rootViewController
        while let presentedController = topController.presentedViewController {
            topController = presentedController
        }
        
        topController.present(alert, animated: true)
    }
    
    private func showPhotosPermissionAlert() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootViewController = window.rootViewController else {
            return
        }
        
        let alert = UIAlertController(
            title: "Photos Access Needed",
            message: "To save your streak achievement, please allow access to Photos in Settings.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Settings", style: .default) { _ in
            if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(settingsURL)
            }
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        var topController = rootViewController
        while let presentedController = topController.presentedViewController {
            topController = presentedController
        }
        
        topController.present(alert, animated: true)
    }
}

// MARK: - Preview Helpers
#if DEBUG
struct StreakCompletionViews_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            FireStreakView(streakNumber: 42)
                .previewDisplayName("Fire Animation")
            
            CompletionCelebrationView(
                celebration: CompletionCelebration(
                    streakNumber: 30,
                    isNewRecord: true,
                    motivationalMessage: "🏆 NEW RECORD! 30 days of speaking LIFE! You're unstoppable!",
                    shareImage: nil
                )
            )
            .previewDisplayName("Celebration View")
        }
    }
}
#endif
