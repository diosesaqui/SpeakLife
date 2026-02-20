//
//  StreamlinedSpiritualWarfareFlow.swift
//  SpeakLife
//
//  Optimized spiritual warfare onboarding - fewer, better screens
//

import SwiftUI
import FirebaseAnalytics
import UserNotifications

// MARK: - Streamlined Tab Enum (Reduced from 15 to 9 screens)
enum StreamlinedSpiritualTab: Int {
    case testimonials = 0
    case battleIntro = 1  // Combines intro + enemy entry
    case thoughtSelection = 2  // Interactive, personalized
    case biblicalSolution = 3  // Victory + solution combined
    case transformation = 4  // Benefits + commitment
    case dailyBurst = 5  // Daily Burst feature intro
    case subscription = 6
    case notification = 7
    case complete = 8
}

// MARK: - Main View
struct StreamlinedSpiritualWarfareFlow: View {
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var timerViewModel: TimerViewModel
    @Environment(\.colorScheme) var colorScheme
    
    @State var selection: StreamlinedSpiritualTab = .testimonials
    @State private var selectedThoughts: Set<String> = []
    @State private var userName: String = ""
    
    let impactMed = UIImpactFeedbackGenerator(style: .soft)
    
    var body: some View {
        GeometryReader { geometry in
            TabView(selection: $selection) {
                
                // Screen 1: Social Proof
                TestimonialsOnboardingView(size: geometry.size) {
                    advance()
                }
                .tag(StreamlinedSpiritualTab.testimonials)
                
                // Screen 2: Problem Introduction (Combined)
                BattleIntroScreen(
                    size: geometry.size,
                    onContinue: advance
                )
                .tag(StreamlinedSpiritualTab.battleIntro)
                
                // Screen 3: Personalized Thought Selection
                ThoughtSelectionScreen(
                    size: geometry.size,
                    selectedThoughts: $selectedThoughts,
                    onContinue: advance
                )
                .tag(StreamlinedSpiritualTab.thoughtSelection)
                
                // Screen 4: Solution + Victory (Combined)
                VictorySolutionScreen(
                    size: geometry.size,
                    selectedThoughts: selectedThoughts,
                    onContinue: advance
                )
                .tag(StreamlinedSpiritualTab.biblicalSolution)
                
                // Screen 5: Transformation Promise
                TransformationScreen(
                    size: geometry.size,
                    onContinue: advance
                )
                .tag(StreamlinedSpiritualTab.transformation)
                
                // Screen 6: Daily Burst Introduction
                OnboardingDailyBurstScreen(
                    size: geometry.size,
                    onContinue: advance
                )
                .tag(StreamlinedSpiritualTab.dailyBurst)
                
                // Screen 7: Subscription
                OptimizedSubscriptionViewV2(callback: {
                    // This callback is only called on successful purchase
                    advance()
                })
                .tag(StreamlinedSpiritualTab.subscription)
                
                // Screen 8: Notifications
                NotificationOnboarding(size: geometry.size) {
                    askNotificationPermission()
                }
                .tag(StreamlinedSpiritualTab.notification)
                
                // Screen 9: Complete
                CompletionScreen(size: geometry.size) {
                    completeOnboarding()
                }
                .tag(StreamlinedSpiritualTab.complete)
            }
            .frame(width: geometry.size.width)
            .ignoresSafeArea()
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
        .preferredColorScheme(.dark)
        .onAppear {
            UIScrollView.appearance().isScrollEnabled = false
            Analytics.logEvent("StreamlinedOnboarding_Started", parameters: nil)
        }
    }
    
    private func advance() {
        withAnimation {
            switch selection {
            case .testimonials:
                selection = .battleIntro
            case .battleIntro:
                selection = .thoughtSelection
            case .thoughtSelection:
                if !selectedThoughts.isEmpty {
                    selection = .biblicalSolution
                }
            case .biblicalSolution:
                selection = .transformation
            case .transformation:
                selection = .dailyBurst
            case .dailyBurst:
                selection = .subscription
            case .subscription:
                selection = .notification
            case .notification:
                selection = .complete
            case .complete:
                completeOnboarding()
            }
        }
        impactMed.impactOccurred()
    }
    
    func askNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { success, error in
            Analytics.logEvent("notification_permission", parameters: ["granted": success])
            advance()
        }
    }
    
    private func completeOnboarding() {
        Analytics.logEvent("StreamlinedOnboarding_Completed", parameters: [
            "thoughts_selected": selectedThoughts.joined(separator: ",")
        ])
        withAnimation {
            appState.isOnboarded = true
        }
        
        // Start the timer now that onboarding is complete
        timerViewModel.startTimerAfterOnboarding()
    }
}

// MARK: - Screen 2: Battle Introduction (Combines multiple screens)
struct BattleIntroScreen: View {
    let size: CGSize
    let onContinue: () -> Void
    @State private var phase = 0
    @State private var contentOpacity = 0.0
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    
    var body: some View {
        ZStack {
            // Dynamic background
            backgroundView
            
            VStack(spacing: 0) {

                Spacer()
                    .frame(height: size.height * 0.20)
                
                // Dynamic content based on phase
                VStack(spacing: 30) {
                    if phase == 0 {
                        // Initial hook
                        VStack(spacing: 16) {
                            Text("Your mind is under attack")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(.white)
                            
                            Text("60,000 thoughts. Every day.")
                                .font(.system(size: 20))
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .transition(.scale.combined(with: .opacity))
                    } else if phase == 1 {
                        // The enemy's strategy
                        VStack(spacing: 20) {
                            Text("The enemy whispers lies")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.white)
                            
                            VStack(spacing: 8) {
                                LieExample(text: "\"You're not enough\"")
                                LieExample(text: "\"God forgot about you\"")
                                LieExample(text: "\"Nothing will change\"")
                            }
                        }
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                    } else {
                        // The consequence
                        VStack(spacing: 20) {
                            Text("When you agree,\nthey become reality")
                                .font(.system(size: 26, weight: .bold))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                
                                Text("That's how the enemy steals your")
                                    .font(.system(size: 16))
                                    .foregroundColor(.white.opacity(0.7))
                                    .multilineTextAlignment(.center)
                                Text("peace, joy, and victory")
                                    .font(.system(size: 16))
                                    .foregroundColor(.white.opacity(0.7))
                                    .multilineTextAlignment(.center)
    
                        }
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .padding(.horizontal, 30)
                .opacity(contentOpacity)
                
                Spacer()
                
                // Continue button
                Button(action: nextPhase) {
                    Text(phase < 2 ? "Continue →" : "How do I stop this? →")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: size.width * 0.85, height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 25)
                                .fill(Color(red: 0.4, green: 0.5, blue: 0.9))
                        )
                }
                .padding(.bottom, 40)
            }
        }.frame(width: size.width)
        .onAppear {
            withAnimation(.easeIn(duration: 0.8)) {
                contentOpacity = 1
            }
        }
    }
    
    private func nextPhase() {
        if phase < 2 {
            withAnimation(.easeInOut(duration: 0.5)) {
                contentOpacity = 0
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                phase += 1
                withAnimation(.easeIn(duration: 0.5)) {
                    contentOpacity = 1
                }
            }
        } else {
            onContinue()
        }
    }
    
    private var backgroundView: some View {
        ZStack {
            Image(subscriptionStore.onboardingBGImage)
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
            
            // Simple dark overlay
            Color.black.opacity(0.3)
                .ignoresSafeArea()
        }
    }
}

struct LieExample: View {
    let text: String
    
    var body: some View {
        Text(text)
            .font(.system(size: 17))
            .foregroundColor(.white.opacity(0.85))
            .multilineTextAlignment(.center)
    }
}

// MARK: - Screen 3: Interactive Thought Selection
struct ThoughtSelectionScreen: View {
    let size: CGSize
    @Binding var selectedThoughts: Set<String>
    let onContinue: () -> Void
    @State private var contentOpacity = 0.0
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    
    let thoughts = [
        ("heart.slash", "I'm not worthy of love"),
        ("lock.circle", "My situation won't change"),
        ("cloud.rain", "God's disappointed in me"),
        ("infinity.circle", "I'll always struggle"),
        ("bandage", "I'm too broken"),
        ("exclamationmark.triangle", "Fear of the future")
    ]
    
    var body: some View {
        ZStack {
            // Background
            Image(subscriptionStore.onboardingBGImage)
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
                .overlay(Color.black.opacity(0.4))
                .frame(width: size.width, height: size.height)
            
    
                VStack(spacing: 0) {
                    Spacer().frame(height: size.height * 0.20)
                    // Title
                    VStack(spacing: 8) {
                        Text("Which thoughts attack you?")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text("Select all that feel familiar")
                            .font(.system(size: 15))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .opacity(contentOpacity)
                    
                    // Thoughts grid - scrollable if needed
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 8) {
                            ForEach(thoughts, id: \.1) { icon, thought in
                                ThoughtButton(
                                    icon: icon,
                                    text: thought,
                                    isSelected: selectedThoughts.contains(thought)
                                ) {
                                    if selectedThoughts.contains(thought) {
                                        selectedThoughts.remove(thought)
                                    } else {
                                        selectedThoughts.insert(thought)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        .padding(.bottom, 100) // Space for button
                    }
                    .opacity(contentOpacity)
                    
                    Spacer()
                    
                    // Continue button - fixed at bottom
                    Button(action: onContinue) {
                        Text(selectedThoughts.isEmpty ? "Select at least one" : "God has answers for these →")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: size.width * 0.85, height: 50)
                            .background(
                                RoundedRectangle(cornerRadius: 25)
                                    .fill(Color(red: 0.4, green: 0.5, blue: 0.9).opacity(selectedThoughts.isEmpty ? 0.4 : 1))
                            )
                    }
                    .disabled(selectedThoughts.isEmpty)
                   // .padding(.bottom, geo.safeAreaInsets.bottom + 20)
               // }
            }
        }.frame(width: size.width)
        .onAppear {
            withAnimation(.easeIn(duration: 0.6)) {
                contentOpacity = 1
            }
        }
    }
}

struct ThoughtButton: View {
    let icon: String
    let text: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(isSelected ? Color(red: 0.4, green: 0.5, blue: 0.9) : .white.opacity(0.5))
                    .frame(width: 24)
                
                Text(text)
                    .font(.system(size: 15))
                    .foregroundColor(.white.opacity(isSelected ? 1 : 0.85))
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(Color(red: 0.4, green: 0.5, blue: 0.9))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(isSelected ? 0.15 : 0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? Color(red: 0.4, green: 0.5, blue: 0.9) : Color.white.opacity(0.15), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Screen 4: Victory + Solution Combined
struct VictorySolutionScreen: View {
    let size: CGSize
    let selectedThoughts: Set<String>
    let onContinue: () -> Void
    @State private var showSolution = false
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Background
                Image(subscriptionStore.onboardingBGImage)
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
                    .overlay(
                        Color.black.opacity(0.3)
                    )
                    .frame(width: size.width, height: size.height)
                
                VStack(spacing: 0) {
                    // Progress
                
                Spacer()
                
                if !showSolution {
                    // Victory message
                    VStack(spacing: 24) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 50))
                            .foregroundColor(Color(red: 0.9, green: 0.7, blue: 0.3))
                        
                        Text("THE TRUTH")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white.opacity(0.7))
                            .tracking(2)
                        
                        Text("Jesus already\ndefeated those lies")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                        
                        Text("You fight FROM victory,\nnot FOR victory")
                            .font(.system(size: 17))
                            .foregroundColor(.white.opacity(0.85))
                            .multilineTextAlignment(.center)
                    }
                    .transition(.scale.combined(with: .opacity))
                } else {
                    // Solution
                    VStack(spacing: 30) {
                        Text("Your weapon:")
                            .font(.system(size: 20))
                            .foregroundColor(.white.opacity(0.8))
                        
                        Text("\"Be transformed by the\nrenewing of your mind\"")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                        
                        Text("Romans 12:2")
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.7))
                        
                        Divider()
                            .background(Color.white.opacity(0.3))
                            .padding(.horizontal, 60)
                        
                        Text("SpeakLife trains you to\nreplace lies with God's truth")
                            .font(.system(size: 18))
                            .foregroundColor(.white.opacity(0.9))
                            .multilineTextAlignment(.center)
                    }
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                }
                
                Spacer()
                
                // Continue button
                Button(action: {
                    if !showSolution {
                        withAnimation(.easeInOut(duration: 0.6)) {
                            showSolution = true
                        }
                    } else {
                        onContinue()
                    }
                }) {
                    Text(showSolution ? "Show me how →" : "How do I use this victory? →")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: size.width * 0.85, height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 25)
                                .fill(Color(red: 0.9, green: 0.6, blue: 0.3))
                        )
                }
                .padding(.bottom, geo.safeAreaInsets.bottom + 20)
            }
            .padding(.horizontal, 30)
        }
        }
    }
}

// MARK: - Screen 5: Transformation Promise
struct TransformationScreen: View {
    let size: CGSize
    let onContinue: () -> Void
    @State private var visibleBenefits: [Bool] = [false, false, false, false]
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    
    let benefits = [
        ("7 days", "Anxiety starts fading", Color(red: 0.3, green: 0.7, blue: 0.4)),
        ("14 days", "Faith replaces fear", Color(red: 0.4, green: 0.5, blue: 0.9)),
        ("21 days", "Joy defeats darkness", Color(red: 0.9, green: 0.6, blue: 0.3)),
        ("Daily", "You walk in authority", Color(red: 0.6, green: 0.4, blue: 0.8))
    ]
    
    var body: some View {
        ZStack {
            // Background
            Image(subscriptionStore.onboardingBGImage)
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
                .overlay(Color.black.opacity(0.4))
                .frame(width: size.width, height: size.height)
            
            GeometryReader { geo in
                VStack(spacing: 0) {
                    // Progress - properly positioned within safe area
                    Spacer().frame(height: size.height * 0.2)
                    // Title
                    VStack(spacing: 8) {
                        Text("Your transformation timeline")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text("What happens when you renew daily")
                            .font(.system(size: 15))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .padding(.top, 30)
                    .padding(.horizontal, 20)
                    
                    Spacer()
                    
                    // Benefits timeline
                    VStack(spacing: 20) {
                        ForEach(0..<benefits.count, id: \.self) { index in
                            if visibleBenefits[index] {
                                HStack(spacing: 12) {
                                    Circle()
                                        .fill(benefits[index].2.opacity(0.2))
                                        .overlay(
                                            Circle()
                                                .stroke(benefits[index].2, lineWidth: 2)
                                        )
                                        .frame(width: 60, height: 60)
                                        .overlay(
                                            Text(benefits[index].0)
                                                .font(.system(size: 11, weight: .semibold))
                                                .foregroundColor(.white)
                                                .multilineTextAlignment(.center)
                                        )
                                    
                                    Text(benefits[index].1)
                                        .font(.system(size: 15))
                                        .foregroundColor(.white.opacity(0.9))
                                    
                                    Spacer()
                                }
                                .padding(.horizontal, 30)
                                .transition(.move(edge: .leading).combined(with: .opacity))
                            }
                        }
                    }
                    
                    Spacer()
                    
                    // CTA - fixed at bottom
                    Button(action: onContinue) {
                        Text("Start my transformation →")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: size.width * 0.85, height: 50)
                            .background(
                                RoundedRectangle(cornerRadius: 25)
                                    .fill(Color(red: 0.3, green: 0.7, blue: 0.4))
                            )
                    }
                    .padding(.bottom, geo.safeAreaInsets.bottom + 20)
                    .opacity(visibleBenefits[3] ? 1 : 0.3)
                    .disabled(!visibleBenefits[3])
                }
            }
        }
        .onAppear {
            // Animate benefits appearing
            for i in 0..<benefits.count {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.5) {
                    withAnimation(.spring()) {
                        visibleBenefits[i] = true
                    }
                }
            }
        }
    }
}

// MARK: - Completion Screen
struct CompletionScreen: View {
    let size: CGSize
    let onComplete: () -> Void
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    
    var body: some View {
        ZStack {
            Image(subscriptionStore.onboardingBGImage)
                .resizable()
                .scaledToFill()
                .frame(width: size.width, height: size.height)
   
                .opacity(0.8)
                .ignoresSafeArea()

            
            VStack(spacing: 30) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.green)
                
                Text("You're ready!")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)
                
                Text("Let's start winning the battle\nfor your mind")
                    .font(.system(size: 18))
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                onComplete()
            }
        }
    }
}
