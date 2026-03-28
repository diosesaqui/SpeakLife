//
//  DailyDeclarationBurstView.swift
//  SpeakLife
//
//  Daily burst feature for morning declarations - Enhanced Version
//

import SwiftUI
import FirebaseAnalytics

struct DailyDeclarationBurstView: View {
    @EnvironmentObject var viewModel: DeclarationViewModel
    @EnvironmentObject var themeViewModel: ThemeViewModel
    @EnvironmentObject var timerViewModel: TimerViewModel
    @EnvironmentObject var streakViewModel: EnhancedStreakViewModel
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    @Environment(\.colorScheme) var colorScheme
    
    @StateObject private var burstTracker = BurstCompletionTracker.shared
    @State private var currentDeclarationIndex = 0
    @State private var showCompletionView = false
    @State private var startTime = Date()
    @State private var declarationOpacity = 0.0
    @State private var isTransitioning = false
    @State private var showSpiritualGraph = false
    @State private var morningDeclarations: [(text: String, verse: String, category: String)] = []
    @State private var isLoadingDeclarations = true
    @State private var showIntroScreen = true
    
    // Animation states for completion screen
    @State private var checkmarkScale: CGFloat = 0.0
    @State private var checkmarkRotation: Double = 0.0
    @State private var starOpacity: Double = 0.0
    @State private var confettiOpacity: Double = 0.0
    @State private var statsScale: CGFloat = 0.0
    @State private var shareButtonOpacity: Double = 0.0
    
    // Configuration for burst session
    private let burstDeclarationCount = 7
    private let favoriteWeight = 2  // Favorites appear 3x more likely
    private let customWeight = 3    // Custom declarations 2x more likely
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Solid base — prevents the underlying view from bleeding through
                // on iPad where fullScreenCover presentations can be transparent.
                Color.black.ignoresSafeArea()

                // Background
                Image(subscriptionStore.onboardingBGImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .opacity(0.8)
                    .ignoresSafeArea()
                
                if showIntroScreen {
                    introScreenView(geometry: geometry)
                } else if !showCompletionView {
                    burstContentView(geometry: geometry)
                } else {
                    completionView(geometry: geometry)
                }
            }
            .ignoresSafeArea()
        }
        .preferredColorScheme(.dark)
        .onAppear {
            loadDynamicDeclarations()
        }
    }
    
    // MARK: - Dynamic Declaration Selection
    
    private func loadDynamicDeclarations() {
        var selectedDeclarations: [(text: String, verse: String, category: String)] = []
        
        // 1. Get favorites from viewModel
        let favorites = viewModel.favorites
        
        // 2. Get custom declarations
        let customDeclarations = viewModel.createOwn.filter({ $0.contentType == .affirmation })
        
        // 3. Get current category declarations
        let categoryDeclarations = viewModel.declarations
        
        // 4. Build weighted pool
        var pool: [Declaration] = []
        
        // Add favorites with higher weight
        for _ in 0..<favoriteWeight {
            pool.append(contentsOf: favorites)
        }
        
        // Add custom declarations with weight
        for _ in 0..<customWeight {
            pool.append(contentsOf: customDeclarations)
        }
        
        // Add current category declarations
        pool.append(contentsOf: categoryDeclarations)
        
        // 5. Shuffle and select unique declarations
        pool.shuffle()
        var usedIds = Set<String>()
        
        for declaration in pool {
            if usedIds.contains(declaration.id) { continue }
            if selectedDeclarations.count >= burstDeclarationCount { break }
            
            let text = declaration.text
            let verse = declaration.book ?? ""
            let categoryName = declaration.category.name
            selectedDeclarations.append((text, verse, categoryName))
            usedIds.insert(declaration.id)
        }
        
        // 6. Fallback if needed
        if selectedDeclarations.count < burstDeclarationCount {
            let fallbackDeclarations = [
                ("I am loved by God unconditionally", "Romans 8:38-39", "Love & Belonging"),
                ("My God supplies all my needs according to His riches", "Philippians 4:19", "Wealth"),
                ("I have the mind of Christ", "1 Corinthians 2:16", "Wisdom"),
                ("Greater is He that is in me than he that is in the world", "1 John 4:4", "Warfare & Victory"),
                ("I can do all things through Christ who strengthens me", "Philippians 4:13", "Faith"),
                ("The joy of the Lord is my strength", "Nehemiah 8:10", "Joy"),
                ("I am fearfully and wonderfully made", "Psalm 139:14", "Identity")
            ]
            
            let needed = burstDeclarationCount - selectedDeclarations.count
            let toAdd = Array(fallbackDeclarations.prefix(needed))
            selectedDeclarations.append(contentsOf: toAdd)
        }
        
        morningDeclarations = selectedDeclarations
        isLoadingDeclarations = false
        
        // Log selection for debugging
        print("📱 Daily Burst: Selected \(morningDeclarations.count) declarations")
        print("  - Favorites: \(favorites.count)")
        print("  - Custom: \(customDeclarations.count)")
        print("  - Category: \(viewModel.selectedCategory)")
        print("  - Final pool size: \(pool.count)")
    }
    
    // MARK: - Intro Screen View
    
    private func introScreenView(geometry: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            // Close button
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.white.opacity(0.6))
                }
                .padding(.leading, 20)
                .padding(.top, 60)
                Spacer()
            }
            
            Spacer()
            
            // Content
            VStack(spacing: 40) {
                // Icon with animated glow
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color(red: 1.0, green: 0.58, blue: 0.0).opacity(0.3), Color(red: 1.0, green: 0.34, blue: 0.13).opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 120, height: 120)
                        .blur(radius: 20)
                    
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color(red: 1.0, green: 0.58, blue: 0.0).opacity(0.2), Color(red: 1.0, green: 0.34, blue: 0.13).opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 100, height: 100)
                    
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 50, weight: .bold))
                        .foregroundColor(.white)
                }
                
                VStack(spacing: 16) {
                    Text("Daily Victory Burst")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("Speak life over your day with 7 powerful declarations")
                        .font(.system(size: 18))
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
            }
            
            Spacer()
            
            // CTA Button
            Button(action: {
                // Haptic feedback
                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                impactFeedback.prepare()
                impactFeedback.impactOccurred()
                
                withAnimation(.easeInOut(duration: 0.5)) {
                    showIntroScreen = false
                }
                startBurst()
            }) {
                HStack(spacing: 12) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 20, weight: .bold))
                    Text("Start Daily Burst")
                        .font(.system(size: 18, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(width: geometry.size.width * 0.85, height: 56)
                .background(
                    RoundedRectangle(cornerRadius: 28)
                        .fill(
                            LinearGradient(
                                colors: [Color(red: 1.0, green: 0.58, blue: 0.0), Color(red: 1.0, green: 0.34, blue: 0.13)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
            }
            .padding(.bottom, 60)
        }
    }
    
    // MARK: - Burst Content View
    
    private func burstContentView(geometry: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            if isLoadingDeclarations {
                // Loading state
                VStack(spacing: 20) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)
                    
                    Text("Preparing your personalized declarations...")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
            // Header
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.white.opacity(0.6))
                }
                
                Spacer()
                
                Text("Daily Victory")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
                
                Spacer()
                
                // Progress indicator
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.2), lineWidth: 3)
                        .frame(width: 40, height: 40)
                    
                    Circle()
                        .trim(from: 0, to: CGFloat(currentDeclarationIndex + 1) / CGFloat(morningDeclarations.count))
                        .stroke(
                            LinearGradient(
                                colors: [Color(red: 1.0, green: 0.58, blue: 0.0), Color(red: 1.0, green: 0.34, blue: 0.13)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 3, lineCap: .round)
                        )
                        .frame(width: 40, height: 40)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut, value: currentDeclarationIndex)
                    
                    Text("\(currentDeclarationIndex + 1)")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 60)
            
            Spacer()
            
            // Declaration Content
            VStack(spacing: 24) {
                // Category label with orange gradient background
                Text(morningDeclarations[currentDeclarationIndex].2.uppercased())
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(
                                LinearGradient(
                                    colors: [Color(red: 1.0, green: 0.58, blue: 0.0), Color(red: 1.0, green: 0.34, blue: 0.13)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    )
                    .opacity(declarationOpacity)
                    .scaleEffect(declarationOpacity)
                
                VStack(spacing: 20) {
                    Text(morningDeclarations[currentDeclarationIndex].0)
                        .font(.system(size: 28, weight: .bold, design: .serif))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 30)
                        .opacity(declarationOpacity)
                    
                    Text(morningDeclarations[currentDeclarationIndex].1)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.6))
                        .opacity(declarationOpacity)
                }
            }
            
            Spacer()
            
            // Bottom Section
            VStack(spacing: 20) {
                Text("Speak this truth aloud")
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.8))
                
                HStack(spacing: 8) {
                    ForEach(0..<morningDeclarations.count, id: \.self) { index in
                        Circle()
                            .fill(index <= currentDeclarationIndex ? Color(red: 1.0, green: 0.58, blue: 0.0) : Color.white.opacity(0.3))
                            .frame(width: 8, height: 8)
                    }
                }
                
                Button(action: nextDeclaration) {
                    Text(currentDeclarationIndex < morningDeclarations.count - 1 ? "Next Declaration" : "Complete Burst")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: geometry.size.width * 0.85, height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 25)
                                .fill(
                                    LinearGradient(
                                        colors: [Color(red: 1.0, green: 0.58, blue: 0.0), Color(red: 1.0, green: 0.34, blue: 0.13)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        )
                }
                .disabled(isTransitioning)
            }
            .padding(.bottom, 50)
            } // Close else for loading check
        }
    }
    
    // MARK: - Completion View
    
    private func completionView(geometry: GeometryProxy) -> some View {
        ZStack {
            // Animated background particles
            ForEach(0..<20, id: \.self) { index in
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.yellow.opacity(0.6), Color.orange.opacity(0.4)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: CGFloat.random(in: 2...6))
                    .position(
                        x: CGFloat.random(in: 0...geometry.size.width),
                        y: CGFloat.random(in: 0...geometry.size.height)
                    )
                    .opacity(confettiOpacity)
                    .animation(
                        Animation.easeInOut(duration: 2)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.1),
                        value: confettiOpacity
                    )
            }
            
            VStack(spacing: 0) {
                Spacer()
                
                VStack(spacing: 30) {
                    // Success Animation with multiple layers
                    ZStack {
                        // Outer pulsing ring
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [Color.yellow.opacity(0.3), Color.orange.opacity(0.2)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                            .frame(width: 160, height: 160)
                            .scaleEffect(checkmarkScale * 1.3)
                            .opacity(starOpacity)
                        
                        // Middle glow
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [Color.orange.opacity(0.5), Color.clear],
                                    center: .center,
                                    startRadius: 5,
                                    endRadius: 60
                                )
                            )
                            .frame(width: 140, height: 140)
                            .scaleEffect(checkmarkScale * 1.1)
                            .blur(radius: 10)
                        
                        // Stars around the checkmark
                        ForEach(0..<8, id: \.self) { index in
                            Image(systemName: "star.fill")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.yellow)
                                .offset(
                                    x: cos(CGFloat(index) * .pi / 4) * 70,
                                    y: sin(CGFloat(index) * .pi / 4) * 70
                                )
                                .rotationEffect(.degrees(Double(index) * 45 + checkmarkRotation))
                                .scaleEffect(starOpacity)
                                .opacity(starOpacity)
                        }
                        
                        // Main checkmark with gradient
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color(red: 1.0, green: 0.8, blue: 0.2), Color(red: 1.0, green: 0.6, blue: 0.1)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 100, height: 100)
                                .scaleEffect(checkmarkScale)
                                .shadow(color: .orange, radius: 20, x: 0, y: 5)
                            
                            Image(systemName: "checkmark")
                                .font(.system(size: 50, weight: .bold))
                                .foregroundColor(.white)
                                .scaleEffect(checkmarkScale)
                                .rotationEffect(.degrees(checkmarkRotation))
                        }
                    }
                    
                    // Dynamic title with gradient
                    Text(getVictoryMessage())
                        .font(.system(size: 34, weight: .black))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.white, Color(red: 1.0, green: 0.9, blue: 0.7)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .scaleEffect(checkmarkScale)
                        .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 2)
                    
                    VStack(spacing: 20) {
                        Text(getMotivationalMessage())
                            .font(.system(size: 19, weight: .medium))
                            .foregroundColor(.white.opacity(0.95))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                            .scaleEffect(statsScale)
                        
                        // Streak only — the one stat that actually matters
                        StatCard(
                            value: "\(burstTracker.currentStreak)",
                            label: burstTracker.currentStreak == 1 ? "Day Streak" : "Day Streak",
                            icon: "flame.fill",
                            scale: statsScale,
                            highlight: burstTracker.currentStreak >= 7
                        )
                        .padding(.top, 8)
                        
                        // Milestone callout
                        if burstTracker.currentStreak % 7 == 0 && burstTracker.currentStreak > 0 {
                            Text("🎉 \(burstTracker.currentStreak / 7) WEEK\(burstTracker.currentStreak == 7 ? "" : "S") STRONG!")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.yellow)
                                .opacity(starOpacity)
                        }
                    }
                    .padding(.horizontal, 30)
                }
                
                Spacer()
                
                VStack(spacing: 16) {
                    // Share Victory Button
                    Button(action: shareVictory) {
                        HStack(spacing: 10) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 17, weight: .semibold))
                            Text("Share Your Victory")
                                .font(.system(size: 17, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(width: geometry.size.width * 0.85, height: 50)
                        .background(
                            ZStack {
                                RoundedRectangle(cornerRadius: 25)
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.purple.opacity(0.8), Color.blue.opacity(0.8)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                
                                RoundedRectangle(cornerRadius: 25)
                                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
                            }
                        )
                        .shadow(color: .purple.opacity(0.3), radius: 10, x: 0, y: 5)
                    }
                    .scaleEffect(shareButtonOpacity)
                    .opacity(shareButtonOpacity)
                    
                    HStack(spacing: 12) {
                        Button(action: { showSpiritualGraph = true }) {
                            HStack {
                                Image(systemName: "chart.line.uptrend.xyaxis")
                                    .font(.system(size: 16))
                                Text("Growth")
                                    .font(.system(size: 15, weight: .medium))
                            }
                            .foregroundColor(Color(red: 0.9, green: 0.7, blue: 0.3))
                            .frame(width: geometry.size.width * 0.4, height: 44)
                            .background(
                                RoundedRectangle(cornerRadius: 22)
                                    .stroke(Color(red: 0.9, green: 0.7, blue: 0.3), lineWidth: 1)
                            )
                        }
                        
                        Button(action: completeBurst) {
                            Text("Continue")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: geometry.size.width * 0.4, height: 44)
                                .background(
                                    RoundedRectangle(cornerRadius: 22)
                                        .fill(
                                            LinearGradient(
                                                colors: [Color(red: 1.0, green: 0.58, blue: 0.0), Color(red: 1.0, green: 0.34, blue: 0.13)],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                )
                                .shadow(color: .orange.opacity(0.3), radius: 10, x: 0, y: 5)
                        }
                    }
                }
                .padding(.bottom, 50)
            }
        }
        .onAppear {
            triggerCompletionAnimations()
        }
        .sheet(isPresented: $showSpiritualGraph) {
            SpiritualStrengthGraph(tracker: burstTracker)
        }
    }
    
    // MARK: - Completion Helper Views
    
    private struct StatCard: View {
        let value: String
        let label: String
        let icon: String
        let scale: CGFloat
        var highlight: Bool = false
        
        var body: some View {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: highlight ? [.orange, .red] : [Color(red: 1.0, green: 0.8, blue: 0.3).opacity(0.3), Color(red: 1.0, green: 0.6, blue: 0.2).opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: icon)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(highlight ? .white : Color(red: 1.0, green: 0.8, blue: 0.3))
                }
                
                Text(value)
                    .font(.system(size: 28, weight: .black))
                    .foregroundColor(.white)
                
                Text(label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
            }
            .scaleEffect(scale)
            .animation(
                .spring(response: 0.5, dampingFraction: 0.6)
                    .delay(0.1),
                value: scale
            )
        }
    }
    
    // MARK: - Completion Helpers
    
    private func getVictoryMessage() -> String {
        let messages = [
            "Victory Declared! 🔥",
            "Champion Status! 💪",
            "Warrior Mode ON! ⚡",
            "Faith Activated! 🙏",
            "Power Released! 🚀",
            "Kingdom Strength! 👑"
        ]
        
        if burstTracker.currentStreak >= 30 {
            return "UNSTOPPABLE! 🌟"
        } else if burstTracker.currentStreak >= 21 {
            return "LEGENDARY! 🏆"
        } else if burstTracker.currentStreak >= 7 {
            return messages.randomElement() ?? "Victory Declared! 🔥"
        } else {
            return ["Victory Claimed!", "Day Conquered!", "Truth Spoken!"].randomElement() ?? "Victory!"
        }
    }
    
    private func getMotivationalMessage() -> String {
        let messages = [
            "You just armed yourself with heaven's ammunition!",
            "Your spirit is stronger than yesterday!",
            "You're building an unshakeable foundation!",
            "Today's battles are already won!",
            "You've activated divine power for your day!",
            "Your faith just leveled up!",
            "You're walking in supernatural authority!"
        ]
        
        if burstTracker.currentStreak >= 7 {
            return "You're unstoppable! \(burstTracker.currentStreak) days of declaring victory!"
        } else {
            return messages.randomElement() ?? "You've aligned your morning with God's truth!"
        }
    }
    
    private func triggerCompletionAnimations() {
        // Trigger haptic feedback
        let successFeedback = UINotificationFeedbackGenerator()
        successFeedback.prepare()
        successFeedback.notificationOccurred(.success)
        
        // Cascade animations
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
            checkmarkScale = 1.0
        }
        
        // Single rotation animation for the checkmark
        withAnimation(.easeInOut(duration: 1.5)) {
            checkmarkRotation = 360
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                starOpacity = 1.0
                confettiOpacity = 1.0
            }
            
            // Medium haptic
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.prepare()
            impactFeedback.impactOccurred()
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                statsScale = 1.0
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            // Light haptic
            let lightFeedback = UIImpactFeedbackGenerator(style: .light)
            lightFeedback.prepare()
            lightFeedback.impactOccurred()
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                shareButtonOpacity = 1.0
            }
        }
    }
    
    private func shareVictory() {
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.prepare()
        impactFeedback.impactOccurred()
        
        let message = "I just completed my Daily Victory Burst on SpeakLife! 🔥\n\n✅ \(morningDeclarations.count) Declarations Spoken\n🔥 \(burstTracker.currentStreak) Day Streak\n💪 \(burstTracker.currentStrengthScore)% Spiritual Strength\n\nJoin me in speaking life daily!"
        
        // Get the active window scene
        guard let windowScene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive || $0.activationState == .foregroundInactive }) as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            print("Could not find root view controller for sharing")
            return
        }
        
        // Find the topmost view controller
        var topController = rootViewController
        while let presentedController = topController.presentedViewController {
            topController = presentedController
        }
        
        let activityVC = UIActivityViewController(
            activityItems: [message],
            applicationActivities: nil
        )
        
        // For iPad
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = topController.view
            popover.sourceRect = CGRect(x: topController.view.bounds.midX, y: topController.view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        
        topController.present(activityVC, animated: true)
        
        Analytics.logEvent("daily_burst_shared", parameters: [
            "streak": burstTracker.currentStreak,
            "strength_score": burstTracker.currentStrengthScore
        ])
    }
    
    // MARK: - Actions
    
    private func startBurst() {
        Analytics.logEvent("DailyBurst_Started", parameters: nil)
        withAnimation(.easeIn(duration: 0.5)) {
            declarationOpacity = 1
        }
    }
    
    private func nextDeclaration() {
        guard !isTransitioning else { return }
        
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.prepare()
        impactFeedback.impactOccurred()
        
        if currentDeclarationIndex < morningDeclarations.count - 1 {
            isTransitioning = true
            
            withAnimation(.easeOut(duration: 0.3)) {
                declarationOpacity = 0
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                currentDeclarationIndex += 1
                withAnimation(.easeIn(duration: 0.3)) {
                    declarationOpacity = 1
                }
                isTransitioning = false
            }
        } else {
            // Complete the burst with success haptic
            let successFeedback = UINotificationFeedbackGenerator()
            successFeedback.prepare()
            successFeedback.notificationOccurred(.success)
            
            let timeSpent = Date().timeIntervalSince(startTime)
            burstTracker.recordBurstCompletion(
                declarationCount: morningDeclarations.count,
                timeSpent: timeSpent
            )
            
            // Cancel the evening "complete your burst" reminder since it's now done
            DailyDeclarationReminderService.shared.cancelEveningReminderAfterBurstCompletion()
            
            // Automatically complete the daily burst task
            streakViewModel.completeTask(taskId: "complete_daily_burst")
            
            withAnimation(.spring()) {
                showCompletionView = true
            }
            
            Analytics.logEvent("DailyBurst_Completed", parameters: [
                "declarations_count": morningDeclarations.count,
                "time_spent": Int(timeSpent),
                "streak": burstTracker.currentStreak
            ])
        }
    }
    
    private func completeBurst() {
        // Haptic feedback on complete
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.prepare()
        impactFeedback.impactOccurred()
        
        dismiss()
        
        // Update streak if needed
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // Streak will update automatically through BurstCompletionTracker
        }
    }
}
