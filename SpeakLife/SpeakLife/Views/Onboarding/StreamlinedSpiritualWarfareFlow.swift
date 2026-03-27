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
// Ordering: pain hook first → personal selection → teaching → paywall
enum StreamlinedSpiritualTab: Int {
    case patternInterrupt = 0     // "You Pray. You Believe. And Still — Fear Shows Up First." (empathy hook)
    case personalSelection = 1    // What Do You Need Most? (emotionally warm, now feels personal)
    case authorityAnchor = 2      // Jesus Said It First (Mark 4:24)
    case convictionGap = 3        // Most Believers Want Strong Faith
    case mindRenewalBridge = 4    // Transformation Starts in the Mind
    case introduceSystem = 5      // Train Your Faith Daily
    case prePaywallClose = 6      // You don't have to wake up anxious anymore
    case subscription = 7
    case notification = 8
    case rating = 9
}

// MARK: - Main View
struct StreamlinedSpiritualWarfareFlow: View {
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    @EnvironmentObject var declarationStore: DeclarationViewModel
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var timerViewModel: TimerViewModel
    @Environment(\.colorScheme) var colorScheme

    @State var selection: StreamlinedSpiritualTab = .patternInterrupt
    @State private var selectedCategories: Set<DeclarationCategory> = []

    let impactMed = UIImpactFeedbackGenerator(style: .soft)

    var body: some View {
        GeometryReader { geometry in
            TabView(selection: $selection) {

                // Slide 1: Pattern Interrupt — empathy hook, name their pain first
                PatternInterruptScreen(size: geometry.size) {
                    advance()
                }
                .tag(StreamlinedSpiritualTab.patternInterrupt)

                // Slide 2: Personal Selection — emotionally primed, now feels personal not clinical
                PersonalSelectionScreen(
                    size: geometry.size,
                    selectedCategories: $selectedCategories
                ) {
                    saveSelectedCategories()
                    advance()
                }
                .tag(StreamlinedSpiritualTab.personalSelection)

                // Slide 3: Authority Anchor
                AuthorityAnchorScreen(size: geometry.size) {
                    advance()
                }
                .tag(StreamlinedSpiritualTab.authorityAnchor)

                // Slide 4: Conviction Gap
                ConvictionGapScreen(size: geometry.size) {
                    advance()
                }
                .tag(StreamlinedSpiritualTab.convictionGap)

                // Slide 5: Mind Renewal Bridge
                MindRenewalBridgeScreen(size: geometry.size) {
                    advance()
                }
                .tag(StreamlinedSpiritualTab.mindRenewalBridge)

                // Slide 6: Introduce System
                IntroduceSystemScreen(size: geometry.size) {
                    advance()
                }
                .tag(StreamlinedSpiritualTab.introduceSystem)

                // Slide 7: Pre-Paywall Close
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
            case .patternInterrupt:
                selection = .personalSelection
            case .personalSelection:
                selection = .authorityAnchor
            case .authorityAnchor:
                selection = .convictionGap
            case .convictionGap:
                selection = .mindRenewalBridge
            case .mindRenewalBridge:
                selection = .introduceSystem
            case .introduceSystem:
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
                    Text("You Pray. You Believe. And Still — Fear Shows Up First.")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)

                    Text("That's not a faith failure. That's an enemy who got there first.")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 30)
                .opacity(contentOpacity)

                Spacer()

                Button(action: onContinue) {
                    Text("That's Exactly Where I Am")
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
                    Text("Your Mind Is the Battlefield. And the Enemy Knows It.")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)

                    VStack(spacing: 16) {
                        Text("\"God has not given us a spirit of fear,\nbut of power, love,\nand a sound mind.\"")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.white.opacity(0.9))
                            .multilineTextAlignment(.center)
                            .italic()

                        Text("- 2 Timothy 1:7")
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.7))
                    }

                    Text("That sound mind is yours.\nYou just have to speak it every day.")
                        .font(.system(size: 17))
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 30)
                .opacity(contentOpacity)

                Spacer()

                Button(action: onContinue) {
                    Text("I'm Ready to Fight Back")
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
                    Text("Anxiety isn't random.\nIt's what you've been repeating.")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)

                    VStack(spacing: 20) {
                        Text("Change what you repeat.")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)

                        VStack(spacing: 12) {
                            Text("SpeakLife gives you God's promises\nto declare every single morning.")
                                .font(.system(size: 16))
                                .foregroundColor(.white.opacity(0.8))
                                .multilineTextAlignment(.center)

                            Text("2 minutes. Real peace.")
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
                    Text("I Want What's Already Mine")
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

                        Text("- Romans 12:2")
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
                    Text("Teach Me to Speak to My Mountains")
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
    @State private var featuresVisible: [Bool] = [false, false, false, false]
    @EnvironmentObject var subscriptionStore: SubscriptionStore

    let features = [
        ("🛡️", "Protection — speak God's shield over your life and family"),
        ("❤️", "Health — declare healing over your body. Daily."),
        ("☮️", "Peace — silence anxiety with the Word in under 5 minutes"),
        ("✨", "Provision — speak abundance and breakthrough over your finances")
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
                    Text("That's Exactly What SpeakLife Is Built For.")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)

                    VStack(spacing: 18) {
                        Text("Faith is a skill. Every declaration you speak is a rep. The stronger you train, the less anything can shake you.")
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

                    Text("Train daily. Level up. Become unshakable.")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 30)
                .opacity(contentOpacity)

                Spacer()

                Button(action: onContinue) {
                    Text("This Is What I Need")
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
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.25 + 0.5) {
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

    let outcomes = ["Anxiety doesn't own your mornings anymore.", "Your body, your peace, your finances — aligned with what God says.", "A renewed mind. An unshakable life. — Romans 12:2"]

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
                    Text("30 Days From Now — Nothing Shakes You the Same Way.")
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


                    }
                }
                .padding(.horizontal, 30)
                .opacity(contentOpacity)

                Spacer()

                Button(action: onContinue) {
                    Text("I Want to Wake Up Like That")
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
                    Text("You don't have to wake up\nanxious anymore.")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                    
                    VStack(spacing: 20) {
                        Text("100,000+ believers have taken their\npeace back — one declaration at a time.")
                            .font(.system(size: 18))
                            .foregroundColor(.white.opacity(0.9))
                            .multilineTextAlignment(.center)
                        
                        Text("Start yours today.")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal, 30)
                .opacity(contentOpacity)
                
                Spacer()
                
                Button(action: onContinue) {
                    Text("Become Unshakable →")
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

