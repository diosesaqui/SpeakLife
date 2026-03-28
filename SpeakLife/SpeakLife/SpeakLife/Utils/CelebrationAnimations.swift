//
//  CelebrationAnimations.swift
//  SpeakLife
//
//  Premium celebration animations for key moments and achievements
//

import SwiftUI
import Foundation
import CoreGraphics

// MARK: - Milestone Celebration Manager

class CelebrationManager: ObservableObject {
    @Published var showCelebration = false
    @Published var celebrationType: CelebrationType = .firstAffirmation
    
    enum CelebrationType {
        case firstAffirmation, firstStreak, firstFavorite, firstJournal
        case streak7, streak30, streak100, streak365
        case dailyGoalComplete, weeklyGoalComplete, monthlyGoalComplete
        case newRecord, birthday, holiday, newYear
        case premiumUpgrade, shareSuccess
        
        var title: String {
            switch self {
            case .firstAffirmation: return "First Declaration! ✨"
            case .firstStreak: return "Streak Started! 🔥"
            case .firstFavorite: return "First Favorite! ❤️"
            case .firstJournal: return "First Journal Entry! 📝"
            case .streak7: return "7 Days Strong! 🌟"
            case .streak30: return "30 Days of Faith! 👑"
            case .streak100: return "100 Days of Life! 🏆"
            case .streak365: return "One Year of Speaking Life! 🎉"
            case .dailyGoalComplete: return "Daily Goal Complete! ✅"
            case .weeklyGoalComplete: return "Weekly Goal Achieved! 🌈"
            case .monthlyGoalComplete: return "Monthly Goal Crushed! 💪"
            case .newRecord: return "New Personal Record! 🥇"
            case .birthday: return "Happy Birthday! 🎂"
            case .holiday: return "Holiday Blessings! 🎊"
            case .newYear: return "Happy New Year! 🎆"
            case .premiumUpgrade: return "Premium Unlocked! 👑"
            case .shareSuccess: return "Shared the Love! 📱"
            }
        }
        
        var message: String {
            switch self {
            case .firstAffirmation: return "You've spoken your first declaration of faith. God's promises are being activated!"
            case .firstStreak: return "Consistency is the key to transformation. Keep going!"
            case .firstFavorite: return "This affirmation resonates with your heart. Let it guide you."
            case .firstJournal: return "Your spiritual reflections matter. God sees your faithful heart."
            case .streak7: return "A week of speaking life! You're building something beautiful."
            case .streak30: return "30 days of declaring God's truth. Your faith is growing stronger!"
            case .streak100: return "100 days of speaking life! You're living in the power of God's promises."
            case .streak365: return "A full year of declarations! You've experienced the transformation of speaking life."
            case .dailyGoalComplete: return "Today's goals are complete. Your commitment is inspiring!"
            case .weeklyGoalComplete: return "This week you've stayed consistent. God is proud of your faithfulness."
            case .monthlyGoalComplete: return "A full month of growth. You're walking in your purpose!"
            case .newRecord: return "You've reached a new personal best! Keep pushing boundaries."
            case .birthday: return "God has blessed you with another year of life. Celebrate His goodness!"
            case .holiday: return "May this season fill your heart with joy and peace."
            case .newYear: return "A new year, new mercies, new opportunities. God has great plans for you!"
            case .premiumUpgrade: return "Welcome to premium! Unlock your full potential in faith."
            case .shareSuccess: return "You've shared the light with others. Your testimony matters!"
            }
        }
        
        var particleType: ParticleSystem.ParticleType {
            switch self {
            case .firstAffirmation, .firstStreak, .firstFavorite, .firstJournal:
                return .gentle
            case .streak7, .dailyGoalComplete:
                return .sparkles
            case .streak30, .weeklyGoalComplete:
                return .stars
            case .streak100, .monthlyGoalComplete, .newRecord:
                return .fireworks
            case .streak365:
                return .golden
            case .birthday, .holiday, .newYear:
                return .celebration
            case .premiumUpgrade:
                return .premium
            case .shareSuccess:
                return .hearts
            }
        }
        
        var hapticPattern: (() -> Void) {
            switch self {
            case .firstAffirmation, .firstStreak, .firstFavorite, .firstJournal:
                return PremiumHaptics.safeHeartbeat
            case .streak7, .dailyGoalComplete:
                return PremiumHaptics.safeSuccessSequence
            case .streak30, .weeklyGoalComplete:
                return PremiumHaptics.safeCelebrationBurst
            case .streak100, .monthlyGoalComplete, .newRecord:
                return { 
                    PremiumHaptics.celebrationBurst()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        PremiumHaptics.celebrationBurst()
                    }
                }
            case .streak365:
                return {
                    for i in 0..<3 {
                        DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.4) {
                            PremiumHaptics.celebrationBurst()
                        }
                    }
                }
            case .birthday, .holiday, .newYear:
                return PremiumHaptics.birthday
            case .premiumUpgrade:
                return PremiumHaptics.buildUp
            case .shareSuccess:
                return PremiumHaptics.safeHeartbeat
            }
        }
    }
    
    func triggerCelebration(_ type: CelebrationType) {
        celebrationType = type
        showCelebration = true
        type.hapticPattern()
    }
    
    func dismissCelebration() {
        showCelebration = false
    }
}

// MARK: - Particle System

struct ParticleSystem: View {
    let particleType: ParticleType
    @State private var particles: [ParticleData] = []
    @State private var isActive = false
    
    enum ParticleType {
        case gentle, sparkles, stars, fireworks, golden, celebration, premium, hearts
        
        var count: Int {
            switch self {
            case .gentle: return 12
            case .sparkles: return 20
            case .stars: return 30
            case .fireworks: return 50
            case .golden: return 40
            case .celebration: return 60
            case .premium: return 35
            case .hearts: return 25
            }
        }
        
        var colors: [Color] {
            switch self {
            case .gentle: return [.white, .blue.opacity(0.8), .purple.opacity(0.6)]
            case .sparkles: return [.yellow, .orange, .white]
            case .stars: return [.yellow, .gold, .orange]
            case .fireworks: return [.red, .blue, .green, .yellow, .purple, .orange]
            case .golden: return [.yellow, .gold, .orange, .white]
            case .celebration: return [.red, .pink, .purple, .blue, .green, .yellow]
            case .premium: return [.purple, .gold, .white, .blue]
            case .hearts: return [.red, .pink, .white]
            }
        }
        
        var symbols: [String] {
            switch self {
            case .gentle: return ["sparkles", "star.fill", "circle.fill"]
            case .sparkles: return ["sparkles", "star", "diamond.fill"]
            case .stars: return ["star.fill", "star.circle.fill", "sparkles"]
            case .fireworks: return ["star.fill", "sparkles", "diamond.fill", "circle.fill"]
            case .golden: return ["star.fill", "crown.fill", "diamond.fill"]
            case .celebration: return ["star.fill", "heart.fill", "diamond.fill", "circle.fill"]
            case .premium: return ["crown.fill", "diamond.fill", "star.fill"]
            case .hearts: return ["heart.fill", "heart.circle.fill", "sparkles"]
            }
        }
    }
    
    struct ParticleData: Identifiable {
        let id = UUID()
        var position: CGPoint
        var velocity: CGPoint
        var rotation: Double
        var rotationSpeed: Double
        var scale: CGFloat
        var opacity: Double
        var color: Color
        var symbol: String
        var lifetime: Double
    }
    
    var body: some View {
        ZStack {
            ForEach(particles) { particle in
                Image(systemName: particle.symbol)
                    .font(.system(size: 16 * particle.scale, weight: .bold))
                    .foregroundColor(particle.color)
                    .opacity(particle.opacity)
                    .rotationEffect(.degrees(particle.rotation))
                    .scaleEffect(particle.scale)
                    .position(particle.position)
            }
        }
        .onAppear {
            generateParticles()
            animateParticles()
        }
    }
    
    private func generateParticles() {
        let screenWidth = UIScreen.main.bounds.width
        let screenHeight = UIScreen.main.bounds.height
        
        particles = (0..<particleType.count).map { _ in
            ParticleData(
                position: CGPoint(
                    x: CGFloat.random(in: 50...(screenWidth - 50)),
                    y: CGFloat.random(in: 100...(screenHeight - 100))
                ),
                velocity: CGPoint(
                    x: CGFloat.random(in: -100...100),
                    y: CGFloat.random(in: -150...50)
                ),
                rotation: Double.random(in: 0...360),
                rotationSpeed: Double.random(in: -180...180),
                scale: CGFloat.random(in: 0.5...1.5),
                opacity: Double.random(in: 0.8...1.0),
                color: particleType.colors.randomElement() ?? .white,
                symbol: particleType.symbols.randomElement() ?? "star.fill",
                lifetime: Double.random(in: 2.0...4.0)
            )
        }
    }
    
    private func animateParticles() {
        let animationDuration: Double = 3.0
        
        withAnimation(.linear(duration: animationDuration)) {
            for index in particles.indices {
                particles[index].position.x += particles[index].velocity.x * 0.02
                particles[index].position.y += particles[index].velocity.y * 0.02
                particles[index].rotation += particles[index].rotationSpeed * 0.02
                particles[index].opacity = 0
                particles[index].scale *= 0.5
            }
        }
    }
}

// MARK: - Celebration Overlay View

struct CelebrationOverlay: View {
    let celebration: CelebrationManager.CelebrationType
    let onDismiss: () -> Void
    @State private var showContent = false
    @State private var showParticles = false
    @State private var titleScale: CGFloat = 0
    @State private var messageOpacity: Double = 0
    
    var body: some View {
        ZStack {
            // Background
            Color.black.opacity(0.7)
                .ignoresSafeArea()
                .onTapGesture {
                    dismissCelebration()
                }
            
            VStack(spacing: 30) {
                Spacer()
                
                // Main celebration content
                if showContent {
                    VStack(spacing: 20) {
                        // Title
                        Text(celebration.title)
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .scaleEffect(titleScale)
                            .glow(color: .white, intensity: 0.5)
                        
                        // Message
                        Text(celebration.message)
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.white.opacity(0.9))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                            .opacity(messageOpacity)
                    }
                }
                
                Spacer()
                
                // Dismiss instruction
                if showContent {
                    Text("Tap anywhere to continue")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                        .opacity(messageOpacity)
                        .scaleBounce()
                }
            }
            
            // Particle system
            if showParticles {
                ParticleSystem(particleType: celebration.particleType)
            }
        }
        .onAppear {
            startCelebrationSequence()
        }
    }
    
    private func startCelebrationSequence() {
        // Show particles first
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            showParticles = true
        }
        
        // Show content
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            showContent = true
            
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                titleScale = 1.0
            }
        }
        
        // Show message
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.easeInOut(duration: 0.8)) {
                messageOpacity = 1.0
            }
        }
        
        // Auto-dismiss after 5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            dismissCelebration()
        }
    }
    
    private func dismissCelebration() {
        withAnimation(.easeInOut(duration: 0.3)) {
            titleScale = 0
            messageOpacity = 0
            showParticles = false
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onDismiss()
        }
    }
}

// MARK: - Quick Toast Celebrations

struct ToastCelebration: View {
    let title: String
    let icon: String
    let color: Color
    @State private var isVisible = false
    @State private var offset: CGFloat = 50
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(color)
            
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 25)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 25)
                        .stroke(color.opacity(0.3), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
        .offset(y: offset)
        .opacity(isVisible ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                isVisible = true
                offset = 0
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isVisible = false
                    offset = -50
                }
            }
        }
    }
}

// MARK: - Progress Ring with Celebration

struct CelebrationProgressRing: View {
    let progress: Double
    let goal: Double
    let category: String
    @State private var animatedProgress: Double = 0
    @State private var showCelebration = false
    @State private var celebrationParticles: [CGPoint] = []
    
    var isComplete: Bool {
        progress >= goal
    }
    
    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .stroke(Color.gray.opacity(0.3), lineWidth: 8)
            
            // Progress circle
            Circle()
                .trim(from: 0, to: min(animatedProgress / goal, 1.0))
                .stroke(
                    isComplete ? 
                    LinearGradient(colors: [.green, .blue], startPoint: .leading, endPoint: .trailing) :
                    LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing),
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 1.0), value: animatedProgress)
            
            // Center content
            VStack(spacing: 4) {
                Text("\(Int(progress))")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.primary)
                
                Text("/ \(Int(goal))")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                
                Text(category)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }
            
            // Celebration particles
            if showCelebration {
                ForEach(Array(celebrationParticles.enumerated()), id: \.offset) { index, point in
                    Image(systemName: "star.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.yellow)
                        .position(point)
                        .opacity(showCelebration ? 1 : 0)
                        .animation(
                            .easeOut(duration: 1.0)
                            .delay(Double(index) * 0.1),
                            value: showCelebration
                        )
                }
            }
        }
        .frame(width: 120, height: 120)
        .onChange(of: progress) { newProgress in
            withAnimation(.easeInOut(duration: 0.5)) {
                animatedProgress = newProgress
            }
            
            if newProgress >= goal && !showCelebration {
                triggerCompletion()
            }
        }
        .onAppear {
            animatedProgress = progress
        }
    }
    
    private func triggerCompletion() {
        PremiumHaptics.safeCelebrationBurst()
        
        // Generate particle positions around the circle
        let center = CGPoint(x: 60, y: 60)
        celebrationParticles = (0..<8).map { index in
            let angle = Double(index) * .pi / 4
            return CGPoint(
                x: center.x + cos(angle) * 80,
                y: center.y + sin(angle) * 80
            )
        }
        
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
            showCelebration = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeOut(duration: 0.5)) {
                showCelebration = false
            }
        }
    }
}

// MARK: - View Extensions for Celebrations

extension View {
    func celebrationOverlay(
        isPresented: Binding<Bool>,
        celebration: CelebrationManager.CelebrationType
    ) -> some View {
        self.overlay(
            Group {
                if isPresented.wrappedValue {
                    CelebrationOverlay(
                        celebration: celebration,
                        onDismiss: {
                            isPresented.wrappedValue = false
                        }
                    )
                }
            }
        )
    }
}