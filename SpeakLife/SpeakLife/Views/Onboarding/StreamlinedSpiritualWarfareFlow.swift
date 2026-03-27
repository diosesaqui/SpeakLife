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
// Ordering: pain-first empathy hook → personal selection (slot 2) to capture investment ASAP
enum StreamlinedSpiritualTab: Int {
    case empathyHook = 0          // You believe. You pray. But something still feels stuck.
    case personalSelection = 1    // What Do You Need Most? (moved to slot 2 for max investment)
    case patternInterrupt = 2     // Your Faith Grows Where Your Attention Goes
    case authorityAnchor = 3      // Jesus Said It First (Mark 4:24)
    case convictionGap = 4        // Most Believers Want Strong Faith
    case mindRenewalBridge = 5    // Transformation Starts in the Mind
    case introduceSystem = 6      // Train Your Faith Daily
    case outcomeVisualization = 7 // Imagine Responding Like Jesus
    case prePaywallClose = 8      // Start Increasing Today
    case subscription = 9
    case notification = 10
    case rating = 11
}

// MARK: - Main View
struct StreamlinedSpiritualWarfareFlow: View {
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    @EnvironmentObject var declarationStore: DeclarationViewModel
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var timerViewModel: TimerViewModel
    @Environment(\.colorScheme) var colorScheme

    @State var selection: StreamlinedSpiritualTab = .empathyHook
    @State private var selectedCategories: Set<DeclarationCategory> = []

    let impactMed = UIImpactFeedbackGenerator(style: .soft)

    var body: some View {
        GeometryReader { geometry in
            TabView(selection: $selection) {

                // Slide 1: Empathy Hook — pain recognition, meet them where they are
                EmpathyHookScreen(size: geometry.size) {
                    advance()
                }
                .tag(StreamlinedSpiritualTab.empathyHook)

                // Slide 2: Personal Selection (moved early — user is already feeling seen)
                PersonalSelectionScreen(
                    size: geometry.size,
                    selectedCategories: $selectedCategories
                ) {
                    saveSelectedCategories()
                    advance()
                }
                .tag(StreamlinedSpiritualTab.personalSelection)

                // Slide 3: Pattern Interrupt
                PatternInterruptScreen(size: geometry.size) {
                    advance()
                }
                .tag(StreamlinedSpiritualTab.patternInterrupt)

                // Slide 4: Authority Anchor
                AuthorityAnchorScreen(size: geometry.size) {
                    advance()
                }
                .tag(StreamlinedSpiritualTab.authorityAnchor)

                // Slide 5: Conviction Gap
                ConvictionGapScreen(size: geometry.size) {
                    advance()
                }
                .tag(StreamlinedSpiritualTab.convictionGap)

                // Slide 6: Mind Renewal Bridge
                MindRenewalBridgeScreen(size: geometry.size) {
                    advance()
                }
                .tag(StreamlinedSpiritualTab.mindRenewalBridge)

                // Slide 7: Introduce System
                IntroduceSystemScreen(size: geometry.size) {
                    advance()
                }
                .tag(StreamlinedSpiritualTab.introduceSystem)

                // Slide 7: Outcome Visualization
                OutcomeVisualizationScreen(size: geometry.size) {
                    advance()
                }
                .tag(StreamlinedSpiritualTab.outcomeVisualization)

                // Slide 8: Pre-Paywall Close
                PrePaywallCloseScreen(size: geometry.size) {
                    advance()
                }
                .tag(StreamlinedSpiritualTab.prePaywallClose)

                // Slide 9: Subscription
                OptimizedSubscriptionView(callback: {
                    advance()
                })
                .tag(StreamlinedSpiritualTab.subscription)

                // Slide 10: Notifications
                NotificationOnboarding(size: geometry.size) {
                    askNotificationPermission()
                }
                .tag(StreamlinedSpiritualTab.notification)

                // Slide 11: Rating
                RatingView(size: geometry.size) {
                    advance()
                }
                .tag(StreamlinedSpiritualTab.rating)
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
            case .empathyHook:
                selection = .personalSelection
            case .personalSelection:
                selection = .patternInterrupt
            case .patternInterrupt:
                selection = .authorityAnchor
            case .authorityAnchor:
                selection = .convictionGap
            case .convictionGap:
                selection = .mindRenewalBridge
            case .mindRenewalBridge:
                selection = .introduceSystem
            case .introduceSystem:
                selection = .outcomeVisualization
            case .outcomeVisualization:
                selection = .prePaywallClose
            case .prePaywallClose:
                selection = .subscription
            case .subscription:
                selection = .notification
            case .notification:
                selection = .rating
            case .rating:
                completeOnboarding()
            }
        }
        impactMed.impactOccurred()
    }

    /// Persist user's category selections for notifications, declarations feed, and paywall personalization
    private func saveSelectedCategories() {
        var categories = selectedCategories
        if categories.isEmpty {
            categories = [.faith, .grace, .identity]
        }

        // Save to AppState for notifications
        appState.selectedNotificationCategories = categories.map { $0.rawValue }.joined(separator: ",")

        // Save to DeclarationViewModel for feed personalization
        declarationStore.save(categories)

        // Track each selection for paywall copy personalization
        for category in categories {
            UserPreferencesTracker.shared.trackCategorySelection(category.rawValue)
        }

        Analytics.logEvent("onboarding_categories_selected", parameters: [
            "categories": categories.map { $0.rawValue }.joined(separator: ","),
            "count": categories.count
        ])
    }
    
    func askNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { success, error in
            Analytics.logEvent("notification_permission", parameters: ["granted": success])
            DispatchQueue.main.async {
                appState.notificationEnabled = success
                
                if success {
                    UIApplication.shared.registerForRemoteNotifications()
                    registerNotifications()
                }
                advance()
            }
        }
    }
    
    private func registerNotifications() {
        if appState.notificationEnabled {
            let categories = Set(appState.selectedNotificationCategories.components(separatedBy: ",").compactMap({ DeclarationCategory($0) }))
            NotificationManager.shared.registerNotifications(count: appState.notificationCount,
                                                             startTime: appState.startTimeIndex,
                                                             endTime: appState.endTimeIndex,
                                                             categories: categories)
            appState.lastNotificationSetDate = Date()
        }
    }
    
    private func completeOnboarding() {
       // Analytics.logEvent("StreamlinedOnboarding_Completed")
        withAnimation {
            appState.isOnboarded = true
            LifecycleNotificationService.shared.scheduleLifecycleNotifications()
        }
        // Trigger Daily Declaration Burst immediately after onboarding
        UserDefaults.standard.set(true, forKey: "showBurstAfterOnboarding")
        
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

// MARK: - Slide 0: Empathy Hook (Pain Recognition)
// Lead with empathy — meet them where they are before teaching them anything
struct EmpathyHookScreen: View {
    let size: CGSize
    let onContinue: () -> Void
    @State private var headlineOpacity = 0.0
    @State private var subOpacity = 0.0
    @State private var buttonOpacity = 0.0
    @EnvironmentObject var subscriptionStore: SubscriptionStore

    var body: some View {
        ZStack {
            Image(subscriptionStore.onboardingBGImage)
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
                .overlay(Color.black.opacity(0.55))
                .frame(width: size.width, height: size.height)

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 36) {
                    // Pain hook — staggered lines land harder
                    VStack(spacing: 12) {
                        Text("You believe.")
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .foregroundColor(.white)

                        Text("You pray.")
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .foregroundColor(.white)

                        Text("But something still\nfeels stuck.")
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                    }
                    .opacity(headlineOpacity)
                    .offset(y: headlineOpacity == 1 ? 0 : 20)

                    Rectangle()
                        .fill(Color.white.opacity(0.25))
                        .frame(width: 50, height: 1)
                        .opacity(subOpacity)

                    // Empathy reframe — before the teaching
                    VStack(spacing: 8) {
                        Text("You're not weak.")
                            .font(.system(size: 19, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.9))

                        Text("You're not failing.")
                            .font(.system(size: 19, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.9))

                        Text("You're just missing one thing.")
                            .font(.system(size: 20, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                    }
                    .opacity(subOpacity)
                    .offset(y: subOpacity == 1 ? 0 : 16)
                }
                .padding(.horizontal, 32)

                Spacer()

                Button(action: {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    onContinue()
                }) {
                    Text("What is it?")
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundColor(.black)
                        .frame(width: size.width * 0.85, height: 54)
                        .background(Capsule().fill(Color.white))
                }
                .opacity(buttonOpacity)
                .padding(.bottom, 60)
            }
        }
        .frame(width: size.width)
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                headlineOpacity = 1
            }
            withAnimation(.easeOut(duration: 0.7).delay(0.6)) {
                subOpacity = 1
            }
            withAnimation(.easeOut(duration: 0.5).delay(1.1)) {
                buttonOpacity = 1
            }
            Analytics.logEvent("EmpathyHookScreenShown", parameters: nil)
        }
    }
}

