//
//  StreamlinedSpiritualWarfareFlow.swift
//  SpeakLife
//
//  Optimized spiritual warfare onboarding - fewer, better screens
//

import SwiftUI
import FirebaseAnalytics
import UserNotifications

// MARK: - New Faith Growth Onboarding (8 slides + burst/subscription)
enum StreamlinedSpiritualTab: Int {
    case patternInterrupt = 0     // Your Faith Grows Where Your Attention Goes
    case authorityAnchor = 1      // Jesus Said It First (Mark 4:24)
    case convictionGap = 2        // Most Believers Want Strong Faith
    case mindRenewalBridge = 3    // Transformation Starts in the Mind
    case introduceSystem = 4      // Train Your Faith Daily
    case personalSelection = 5    // What Do You Need Most?
    case outcomeVisualization = 6 // Imagine Responding Like Jesus
    case prePaywallClose = 7      // Start Increasing Today
    case dailyBurst = 8          // Daily Burst feature intro
    case subscription = 9
    case notification = 10
}

// MARK: - Main View
struct StreamlinedSpiritualWarfareFlow: View {
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var timerViewModel: TimerViewModel
    @Environment(\.colorScheme) var colorScheme
    
    @State var selection: StreamlinedSpiritualTab = .patternInterrupt
    @State private var selectedCategories: Set<DeclarationCategory> = []
    
    let impactMed = UIImpactFeedbackGenerator(style: .soft)
    
    var body: some View {
        GeometryReader { geometry in
            TabView(selection: $selection) {
                
                // Slide 1: Pattern Interrupt
                PatternInterruptScreen(size: geometry.size) {
                    advance()
                }
                .tag(StreamlinedSpiritualTab.patternInterrupt)
                
                // Slide 2: Authority Anchor
                AuthorityAnchorScreen(size: geometry.size) {
                    advance()
                }
                .tag(StreamlinedSpiritualTab.authorityAnchor)
                
                // Slide 3: Conviction Gap
                ConvictionGapScreen(size: geometry.size) {
                    advance()
                }
                .tag(StreamlinedSpiritualTab.convictionGap)
                
                // Slide 4: Mind Renewal Bridge
                MindRenewalBridgeScreen(size: geometry.size) {
                    advance()
                }
                .tag(StreamlinedSpiritualTab.mindRenewalBridge)
                
                // Slide 5: Introduce System
                IntroduceSystemScreen(size: geometry.size) {
                    advance()
                }
                .tag(StreamlinedSpiritualTab.introduceSystem)
                
                // Slide 6: Personal Selection
                PersonalSelectionScreen(
                    size: geometry.size,
                    selectedCategories: $selectedCategories
                ) {
                    advance()
                }
                .tag(StreamlinedSpiritualTab.personalSelection)
                
                // Slide 7: Outcome Visualization
                OutcomeVisualizationScreen(size: geometry.size) {
                    advance()
                }
                .tag(StreamlinedSpiritualTab.outcomeVisualization)
                
                // Slide 7: Pre-Paywall Close
                PrePaywallCloseScreen(size: geometry.size) {
                    advance()
                }
                .tag(StreamlinedSpiritualTab.prePaywallClose)
                
                // Screen 8: Daily Burst Introduction
                OnboardingDailyBurstScreen(
                    size: geometry.size,
                    onContinue: advance
                )
                .tag(StreamlinedSpiritualTab.dailyBurst)
                
                // Screen 9: Subscription
                OptimizedSubscriptionView(callback: {
                    // This callback is only called on successful purchase
                    advance()
                })
                .tag(StreamlinedSpiritualTab.subscription)
                
                // Screen 10: Notifications
                NotificationOnboarding(size: geometry.size) {
                    askNotificationPermission()
                }
                .tag(StreamlinedSpiritualTab.notification)
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
            case .patternInterrupt:
                selection = .authorityAnchor
            case .authorityAnchor:
                selection = .convictionGap
            case .convictionGap:
                selection = .mindRenewalBridge
            case .mindRenewalBridge:
                selection = .introduceSystem
            case .introduceSystem:
                selection = .personalSelection
            case .personalSelection:
                selection = .outcomeVisualization
            case .outcomeVisualization:
                selection = .prePaywallClose
            case .prePaywallClose:
                selection = .dailyBurst
            case .dailyBurst:
                selection = .subscription
            case .subscription:
                selection = .notification
            case .notification:
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
       // Analytics.logEvent("StreamlinedOnboarding_Completed")
        withAnimation {
            appState.isOnboarded = true
            LifecycleNotificationService.shared.scheduleLifecycleNotifications()
        }
        
        // Start the timer now that onboarding is complete
       // timerViewModel.startTimerAfterOnboarding()
    }
}

// MARK: - Slide 1: Pattern Interrupt
struct PatternInterruptScreen: View {
    let size: CGSize
    let onContinue: () -> Void
    @State private var contentOpacity = 0.0
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    
    var body: some View {
        ZStack {
            // Background
            Image(subscriptionStore.onboardingBGImage)
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
                .overlay(Color.black.opacity(0.3))
                .frame(width: size.width, height: size.height)
            
            VStack(spacing: 0) {
                Spacer()
                    .frame(height: size.height * 0.25)
                
                VStack(spacing: 24) {
                    Text("Your Faith Is Only As Strong As What You Hear Daily.")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                    
                    Text("Spiritual strength isn’t automatic. It’s trained.")
                        .font(.system(size: 18))
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 30)
                .opacity(contentOpacity)
                
                Spacer()
                
                Button(action: onContinue) {
                    Text("Continue")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: size.width * 0.85, height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 25)
                                .fill(Color(red: 0.4, green: 0.5, blue: 0.9))
                        )
                }
                .padding(.bottom, 60)
            }
        }
        .frame(width: size.width)
        .onAppear {
            withAnimation(.easeIn(duration: 0.8)) {
                contentOpacity = 1
            }
        }
    }
}

// MARK: - Slide 2: Authority Anchor
struct AuthorityAnchorScreen: View {
    let size: CGSize
    let onContinue: () -> Void
    @State private var contentOpacity = 0.0
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    
    var body: some View {
        ZStack {
            Image(subscriptionStore.onboardingBGImage)
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
                .overlay(Color.black.opacity(0.3))
                .frame(width: size.width, height: size.height)
            
            VStack(spacing: 0) {
                Spacer()
                    .frame(height: size.height * 0.20)
                
                VStack(spacing: 30) {
                    Text("Jesus Said It First.")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                    
                    VStack(spacing: 16) {
                        Text("\"With the measure you use,\nit will be measured to you\n— and even more.\"")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.white.opacity(0.9))
                            .multilineTextAlignment(.center)
                            .italic()
                        
                        Text("— Mark 4:24")
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    
                    Text("The attention you give God's Word\ndetermines the strength you walk in.")
                        .font(.system(size: 17))
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 30)
                .opacity(contentOpacity)
                
                Spacer()
                
                Button(action: onContinue) {
                    Text("That Makes Sense")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: size.width * 0.85, height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 25)
                                .fill(Color(red: 0.4, green: 0.5, blue: 0.9))
                        )
                }
                .padding(.bottom, 60)
            }
        }
        .frame(width: size.width)
        .onAppear {
            withAnimation(.easeIn(duration: 0.8)) {
                contentOpacity = 1
            }
        }
    }
}

// MARK: - Slide 3: Conviction Gap
struct ConvictionGapScreen: View {
    let size: CGSize
    let onContinue: () -> Void
    @State private var contentOpacity = 0.0
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    
    var body: some View {
        ZStack {
            Image(subscriptionStore.onboardingBGImage)
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
                .overlay(Color.black.opacity(0.3))
                .frame(width: size.width, height: size.height)
            
            VStack(spacing: 0) {
                Spacer()
                    .frame(height: size.height * 0.20)
                
                VStack(spacing: 32) {
                    Text("Most Believers Want Strong Faith.")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                    
                    VStack(spacing: 20) {
                        Text("But faith doesn't grow by accident.")
                            .font(.system(size: 18))
                            .foregroundColor(.white.opacity(0.9))
                            .multilineTextAlignment(.center)
                        
                        VStack(spacing: 12) {
                            Text("If you give God's Word occasional attention,\nyou get occasional strength.")
                                .font(.system(size: 16))
                                .foregroundColor(.white.opacity(0.8))
                                .multilineTextAlignment(.center)
                            
                            Text("Daily attention builds daily power.")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                        }
                    }
                }
                .padding(.horizontal, 30)
                .opacity(contentOpacity)
                
                Spacer()
                
                Button(action: onContinue) {
                    Text("I Want Strong Faith")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: size.width * 0.85, height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 25)
                                .fill(Color(red: 0.4, green: 0.5, blue: 0.9))
                        )
                }
                .padding(.bottom, 60)
            }
        }
        .frame(width: size.width)
        .onAppear {
            withAnimation(.easeIn(duration: 0.8)) {
                contentOpacity = 1
            }
        }
    }
}

// MARK: - Slide 4: Mind Renewal Bridge
struct MindRenewalBridgeScreen: View {
    let size: CGSize
    let onContinue: () -> Void
    @State private var contentOpacity = 0.0
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    
    var body: some View {
        ZStack {
            Image(subscriptionStore.onboardingBGImage)
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
                .overlay(Color.black.opacity(0.3))
                .frame(width: size.width, height: size.height)
            
            VStack(spacing: 0) {
                Spacer()
                    .frame(height: size.height * 0.20)
                
                VStack(spacing: 32) {
                    Text("Transformation Starts\nin the Mind.")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                    
                    VStack(spacing: 20) {
                        Text("\"Be transformed by the\nrenewing of your mind.\"")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.white.opacity(0.9))
                            .multilineTextAlignment(.center)
                            .italic()
                        
                        Text("— Romans 12:2")
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.7))
                        
                        Text("When truth becomes your first response,\nvictory becomes natural.")
                            .font(.system(size: 17))
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal, 30)
                .opacity(contentOpacity)
                
                Spacer()
                
                Button(action: onContinue) {
                    Text("Keep Going")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: size.width * 0.85, height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 25)
                                .fill(Color(red: 0.4, green: 0.5, blue: 0.9))
                        )
                }
                .padding(.bottom, 60)
            }
        }
        .frame(width: size.width)
        .onAppear {
            withAnimation(.easeIn(duration: 0.8)) {
                contentOpacity = 1
            }
        }
    }
}

// MARK: - Slide 5: Introduce System
struct IntroduceSystemScreen: View {
    let size: CGSize
    let onContinue: () -> Void
    @State private var contentOpacity = 0.0
    @State private var featuresVisible: [Bool] = [false, false, false]
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    
    let features = [
        ("7", "Scripture Declarations a Day"),
        ("🎧", "Christ-Centered Audio Reinforcement"),
        ("💪", "Daily Victory Conditioning")
    ]
    
    var body: some View {
        ZStack {
            Image(subscriptionStore.onboardingBGImage)
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
                .overlay(Color.black.opacity(0.3))
                .frame(width: size.width, height: size.height)
            
            VStack(spacing: 0) {
                Spacer()
                    .frame(height: size.height * 0.18)
                
                VStack(spacing: 32) {
                    Text("Train Your Faith Daily.")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                    
                    VStack(spacing: 18) {
                        Text("SpeakLife helps you give God's Word\ndaily attention through:")
                            .font(.system(size: 17))
                            .foregroundColor(.white.opacity(0.9))
                            .multilineTextAlignment(.center)
                        
                        VStack(spacing: 16) {
                            ForEach(0..<features.count, id: \.self) { index in
                                if featuresVisible[index] {
                                    HStack(spacing: 16) {
                                        Text(features[index].0)
                                            .font(.system(size: 24, weight: .semibold))
                                            .foregroundColor(Color(red: 0.4, green: 0.5, blue: 0.9))
                                            .frame(width: 40, alignment: .center)
                                        
                                        Text(features[index].1)
                                            .font(.system(size: 16))
                                            .foregroundColor(.white.opacity(0.9))
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    .padding(.horizontal, 40)
                                    .transition(.move(edge: .leading).combined(with: .opacity))
                                }
                            }
                        }
                    }
                    
                    Text("Faith grows with repetition.")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 30)
                .opacity(contentOpacity)
                
                Spacer()
                
                Button(action: onContinue) {
                    Text("This Is Powerful")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: size.width * 0.85, height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 25)
                                .fill(Color(red: 0.4, green: 0.5, blue: 0.9))
                        )
                }
                .padding(.bottom, 60)
            }
        }
        .frame(width: size.width)
        .onAppear {
            withAnimation(.easeIn(duration: 0.8)) {
                contentOpacity = 1
            }
            
            // Animate features appearing
            for i in 0..<features.count {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.3 + 0.5) {
                    withAnimation(.spring()) {
                        featuresVisible[i] = true
                    }
                }
            }
        }
    }
}

// MARK: - Slide 6: Outcome Visualization
struct OutcomeVisualizationScreen: View {
    let size: CGSize
    let onContinue: () -> Void
    @State private var contentOpacity = 0.0
    @State private var outcomesVisible: [Bool] = [false, false, false]
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    
    let outcomes = ["Anxiety shrinks.", "Boldness grows.", "Peace becomes instinct."]
    
    var body: some View {
        ZStack {
            Image(subscriptionStore.onboardingBGImage)
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
                .overlay(Color.black.opacity(0.3))
                .frame(width: size.width, height: size.height)
            
            VStack(spacing: 0) {
                Spacer()
                    .frame(height: size.height * 0.20)
                
                VStack(spacing: 32) {
                    Text("Imagine Responding Like Jesus\nUnder Pressure.")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                    
                    VStack(spacing: 20) {
                        ForEach(0..<outcomes.count, id: \.self) { index in
                            if outcomesVisible[index] {
                                Text(outcomes[index])
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(.white.opacity(0.9))
                                    .multilineTextAlignment(.center)
                                    .transition(.move(edge: .leading).combined(with: .opacity))
                            }
                        }
                        
                        if outcomesVisible[2] {
                            VStack(spacing: 12) {
                                Text("Because truth is already in you.")
                                    .font(.system(size: 17))
                                    .foregroundColor(.white.opacity(0.8))
                                    .multilineTextAlignment(.center)
                                    .transition(.scale.combined(with: .opacity))
                            }
                        }
                    }
                }
                .padding(.horizontal, 30)
                .opacity(contentOpacity)
                
                Spacer()
                
                Button(action: onContinue) {
                    Text("I'm Ready")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: size.width * 0.85, height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 25)
                                .fill(Color(red: 0.3, green: 0.7, blue: 0.4))
                        )
                }
                .padding(.bottom, 60)
            }
        }
        .frame(width: size.width)
        .onAppear {
            withAnimation(.easeIn(duration: 0.8)) {
                contentOpacity = 1
            }
            
            // Animate outcomes appearing
            for i in 0..<outcomes.count {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.4 + 0.5) {
                    withAnimation(.spring()) {
                        outcomesVisible[i] = true
                    }
                }
            }
        }
    }
}

// MARK: - Slide 7: Pre-Paywall Close
struct PrePaywallCloseScreen: View {
    let size: CGSize
    let onContinue: () -> Void
    @State private var contentOpacity = 0.0
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    
    var body: some View {
        ZStack {
            Image(subscriptionStore.onboardingBGImage)
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
                .overlay(Color.black.opacity(0.3))
                .frame(width: size.width, height: size.height)
            
            VStack(spacing: 0) {
                Spacer()
                    .frame(height: size.height * 0.22)
                
                VStack(spacing: 32) {
                    Text("Start Increasing Today.")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                    
                    VStack(spacing: 20) {
                        Text("The more attention you give His Word,\nthe more strength you walk in.")
                            .font(.system(size: 18))
                            .foregroundColor(.white.opacity(0.9))
                            .multilineTextAlignment(.center)
                        
                        Text("Give God's Word your daily measure.")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal, 30)
                .opacity(contentOpacity)
                
                Spacer()
                
                Button(action: onContinue) {
                    Text("Build My Faith")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: size.width * 0.85, height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 25)
                                .fill(Color(red: 0.4, green: 0.5, blue: 0.9))
                        )
                }
                .padding(.bottom, 60)
            }
        }
        .frame(width: size.width)
        .onAppear {
            withAnimation(.easeIn(duration: 0.8)) {
                contentOpacity = 1
            }
        }
    }
}

// MARK: - Slide 6: Personal Selection
struct PersonalSelectionScreen: View {
    let size: CGSize
    @Binding var selectedCategories: Set<DeclarationCategory>
    let onContinue: () -> Void
    @State private var contentOpacity = 0.0
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    
    // Top 6 most relevant categories for faith-focused onboarding
    private let topCategories: [DeclarationCategory] = [
        .faith,        // Strengthen Faith
        .anxiety,
        .health,
        .grace,
        .identity,
        .addiction,
        .destiny,// Anxiety & Worry
        //.fear,         // Fear & Doubt
        .rest,         // Rest & Peace
        .confidence,   // Confidence
        .joy          // Joy & Happiness
    ]
    
    var body: some View {
        ZStack {
            Image(subscriptionStore.onboardingBGImage)
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
                .overlay(Color.black.opacity(0.3))
                .frame(width: size.width, height: size.height)
            
            VStack(spacing: 0) {
                Spacer()
                    .frame(height: size.height * 0.18)
                
                VStack(spacing: 32) {
                    Text("What Do You Need Most?")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                    
                    VStack(spacing: 20) {
                        Text("Select the areas where you'd like to see breakthrough")
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.9))
                            .multilineTextAlignment(.center)
                        
                        // Category selection grid
                        LazyVGrid(columns: [
                            GridItem(.flexible(), spacing: 8),
                            GridItem(.flexible(), spacing: 8)
                        ], spacing: 12) {
                            ForEach(topCategories, id: \.self) { category in
                                CategorySelectionButton(
                                    category: category,
                                    isSelected: selectedCategories.contains(category)
                                ) {
                                    if selectedCategories.contains(category) {
                                        selectedCategories.remove(category)
                                    } else {
                                        selectedCategories.insert(category)
                                    }
                                    
                                    // Haptic feedback
                                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                    impactFeedback.impactOccurred()
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
                .padding(.horizontal, 30)
                .opacity(contentOpacity)
                
                Spacer()
                
                VStack(spacing: 12) {
                    if !selectedCategories.isEmpty {
                        Text("\(selectedCategories.count) selected")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    
                    Button(action: {
                        // Track selections for personalization
                        for category in selectedCategories {
                            UserPreferencesTracker.shared.trackCategorySelection(category.rawValue)
                        }
                        
                        // If nothing selected, default to faith
                        if selectedCategories.isEmpty {
                            selectedCategories.insert(.faith)
                            selectedCategories.insert(.grace)
                            selectedCategories.insert(.identity)
                            UserPreferencesTracker.shared.trackCategorySelection("faith")
                        }
                        
                        onContinue()
                    }) {
                        Text(selectedCategories.isEmpty ? "Continue" : "Personalize My Experience")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: size.width * 0.85, height: 50)
                            .background(
                                RoundedRectangle(cornerRadius: 25)
                                    .fill(Color(red: 0.4, green: 0.5, blue: 0.9))
                            )
                    }
                    
                    // Skip option
                    Button(action: {
                        selectedCategories.insert(.faith)
                        UserPreferencesTracker.shared.trackCategorySelection("faith")
                        onContinue()
                    }) {
                        Text("Skip for now")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
                .padding(.bottom, 60)
            }
        }
        .frame(width: size.width)
        .onAppear {
            withAnimation(.easeIn(duration: 0.8)) {
                contentOpacity = 1
            }
        }
    }
}

struct CategorySelectionButton: View {
    let category: DeclarationCategory
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: category.iconName)
                    .font(.system(size: 16))
                    .foregroundColor(isSelected ? .white : .white.opacity(0.8))
                    .frame(width: 20)
                
                Text(category.displayName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(isSelected ? .white : .white.opacity(0.9))
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(isSelected ? Color(red: 0.4, green: 0.5, blue: 0.9) : Color.white.opacity(0.12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(
                                isSelected ? Color(red: 0.4, green: 0.5, blue: 0.9) : Color.white.opacity(0.25), 
                                lineWidth: 1
                            )
                    )
            )
        }
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
    }
}

