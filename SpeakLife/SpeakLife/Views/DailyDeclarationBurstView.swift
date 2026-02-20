//
//  DailyDeclarationBurstView.swift
//  SpeakLife
//
//  Daily burst feature for morning declarations
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
    
    // Configuration for burst session
    private let burstDeclarationCount = 7
    private let favoriteWeight = 2  // Favorites appear 3x more likely
    private let customWeight = 3    // Custom declarations 2x more likely
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
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
        
//        // If pool is still small, get more from all categories
//        if pool.count < burstDeclarationCount * 2 {
//            // Use allAvailableDeclarations if accessible, otherwise use what we have
//            let additionalDeclarations = categoryDeclarations
//                .shuffled()
//                .prefix(20)
//            pool.append(contentsOf: additionalDeclarations)
//        }
        
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
                    .font(.system(size: 13, weight: .bold))
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
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 30)
                        .opacity(declarationOpacity)
                    
                    Text(morningDeclarations[currentDeclarationIndex].1)
                        .font(.system(size: 14))
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
        VStack(spacing: 0) {
            Spacer()
            
            VStack(spacing: 30) {
                // Success Animation
                ZStack {
                    Circle()
                        .fill(Color(red: 0.9, green: 0.7, blue: 0.3).opacity(0.2))
                        .frame(width: 120, height: 120)
                        .scaleEffect(1.2)
                        .animation(
                            Animation.easeInOut(duration: 1.5)
                                .repeatForever(autoreverses: true),
                            value: showCompletionView
                        )
                    
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(Color(red: 0.9, green: 0.7, blue: 0.3))
                }
                
                Text("Victory Declared!")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)
                
                VStack(spacing: 12) {
                    Text("You've aligned your morning with God's truth")
                        .font(.system(size: 18))
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                    
                    // Stats
                    HStack(spacing: 40) {
                        VStack(spacing: 4) {
                            Text("\(morningDeclarations.count)")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(Color(red: 0.9, green: 0.7, blue: 0.3))
                            Text("Declarations")
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.7))
                        }
                        
                        VStack(spacing: 4) {
                            Text("\(burstTracker.currentStreak)")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(Color(red: 0.9, green: 0.7, blue: 0.3))
                            Text("Day Streak")
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.7))
                        }
                        
                        VStack(spacing: 4) {
                            Text("\(burstTracker.currentStrengthScore)%")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(Color(red: 0.9, green: 0.7, blue: 0.3))
                            Text("Strength")
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                    .padding(.top, 20)
                }
                .padding(.horizontal, 30)
                
                // Spiritual Strength Level
                HStack(spacing: 12) {
                    Image(systemName: burstTracker.strengthLevel.icon)
                        .font(.system(size: 24))
                        .foregroundColor(burstTracker.strengthLevel.color)
                    
                    Text("Spiritual Level: \(burstTracker.strengthLevel.rawValue)")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 24)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(burstTracker.strengthLevel.color.opacity(0.2))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(burstTracker.strengthLevel.color, lineWidth: 1)
                        )
                )
                .padding(.top, 10)
            }
            
            Spacer()
            
            VStack(spacing: 12) {
                Button(action: { showSpiritualGraph = true }) {
                    HStack {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 18))
                        Text("View Spiritual Growth")
                            .font(.system(size: 16, weight: .medium))
                    }
                    .foregroundColor(Color(red: 0.9, green: 0.7, blue: 0.3))
                    .frame(width: geometry.size.width * 0.85, height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 22)
                            .stroke(Color(red: 0.9, green: 0.7, blue: 0.3), lineWidth: 1)
                    )
                }
                
                Button(action: completeBurst) {
                    Text("Complete")
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
            }
            .padding(.bottom, 50)
        }
        .sheet(isPresented: $showSpiritualGraph) {
            SpiritualStrengthGraph(tracker: burstTracker)
        }
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

// MARK: - Preview

//struct DailyDeclarationBurstView_Previews: PreviewProvider {
//    static var previews: some View {
//        DailyDeclarationBurstView()
//            .environmentObject(DeclarationViewModel())
//            .environmentObject(ThemeViewModel())
//            .environmentObject(TimerViewModel())
//            .environmentObject(EnhancedStreakViewModel())
//    }
//}
