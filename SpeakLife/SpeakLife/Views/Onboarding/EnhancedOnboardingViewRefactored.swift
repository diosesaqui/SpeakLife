//
//  EnhancedOnboardingViewRefactored.swift
//  SpeakLife
//
//  Refactored enhanced onboarding flow using reusable components
//

import SwiftUI
import FirebaseAnalytics
import UserNotifications

struct EnhancedOnboardingViewRefactored: View {
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var viewModel: DeclarationViewModel
    @EnvironmentObject var streakViewModel: StreakViewModel
    @Environment(\.colorScheme) var colorScheme
    
    @State var selection: EnhancedTab = .emotionalRecognition
    @StateObject var userJourney = OnboardingUserJourneyViewModel()
    @AppStorage("enhancedOnboardingTab") var enhancedOnboardingTab = EnhancedTab.emotionalRecognition.rawValue
    @State private var isTextVisible = false
   
    let impactMed = UIImpactFeedbackGenerator(style: .soft)
    
    var body: some View {
        GeometryReader { geometry in
            TabView(selection: $selection) {
                
                // Screen 1: Emotional Recognition
                GenericOnboardingScreen(
                    content: OnboardingContentProvider.emotionalRecognition,
                    size: geometry.size
                ) { selections in
                    userJourney.emotionalNeeds = selections
                    advance()
                }
                .tag(EnhancedTab.emotionalRecognition)
                
                // Screen 2: Internal Experience
                GenericOnboardingScreen(
                    content: OnboardingContentProvider.internalExperience,
                    size: geometry.size
                ) { selections in
                    userJourney.internalExperience = selections.first ?? ""
                    advance()
                }
                .tag(EnhancedTab.internalExperience)
                
                // Screen 3: Belief Gap
                GenericOnboardingScreen(
                    content: OnboardingContentProvider.beliefGap,
                    size: geometry.size
                ) { selections in
                    userJourney.beliefGap = selections.first ?? ""
                    advance()
                }
                .tag(EnhancedTab.beliefGap)
                
                // Screen 4: Authority Reframe
                GenericOnboardingScreen(
                    content: OnboardingContentProvider.authorityReframe,
                    size: geometry.size
                ) { selections in
                    userJourney.authorityReframe = selections.first ?? ""
                    advance()
                }
                .tag(EnhancedTab.authorityReframe)
                
                // Screen 5: Practice Awareness
                GenericOnboardingScreen(
                    content: OnboardingContentProvider.practiceAwareness,
                    size: geometry.size
                ) { selections in
                    userJourney.practiceLevel = selections.first ?? ""
                    advance()
                }
                .tag(EnhancedTab.practiceAwareness)
                
                // Screen 6: Aha Moment
                GenericOnboardingScreen(
                    content: OnboardingContentProvider.ahaMoment,
                    size: geometry.size
                ) { _ in
                    advance()
                }
                .tag(EnhancedTab.ahaMoment)
                
                // Screen 7: Identity Aspiration
                GenericOnboardingScreen(
                    content: OnboardingContentProvider.identityAspiration,
                    size: geometry.size
                ) { selections in
                    userJourney.desiredIdentity = selections.first ?? ""
                    advance()
                }
                .tag(EnhancedTab.identityAspiration)
                
                // Screen 8: Future Pacing
                GenericOnboardingScreen(
                    content: OnboardingContentProvider.futurePacing,
                    size: geometry.size
                ) { selections in
                    userJourney.futureOutcome = selections.first ?? ""
                    advance()
                }
                .tag(EnhancedTab.futurePacing)
                
                // Screen 9: Core Message Lock-In
                GenericOnboardingScreen(
                    content: OnboardingContentProvider.coreMessage,
                    size: geometry.size
                ) { _ in
                    advance()
                }
                .tag(EnhancedTab.coreMessage)
                
                
                GenericOnboardingScreen(
                    content: OnboardingContentProvider.transitionToPaywall(journey: userJourney.journey),
                    size: geometry.size
                ) { _ in
                    advance()
                }
                .tag(EnhancedTab.transitionToPaywall)
                
                subscriptionScene(size: geometry.size)
                    .tag(EnhancedTab.subscription)
                
                // Existing screens (notifications, rating, subscription)
                NotificationOnboarding(size: geometry.size) {
                    withAnimation {
                        askNotificationPermission()
                    }
                }
                .tag(EnhancedTab.notification)
                
                RatingView(size: geometry.size) {
                    withAnimation {
                        advance()
                    }
                }
                .tag(EnhancedTab.review)
                
                

                
            }
            .ignoresSafeArea()
            .tabViewStyle(.page(indexDisplayMode: .never))
            .font(.headline)
        }
        .preferredColorScheme(.light)
        .onAppear {
            setSelection()
            UIScrollView.appearance().isScrollEnabled = false
            setupAppearance()
            Analytics.logEvent("EnhancedOnboardingStarted", parameters: nil)
        }
    }

    private func setSelection() {
        guard let tab = EnhancedTab(rawValue: enhancedOnboardingTab) else { return }
        selection = tab
    }
    
    // MARK: - Private Views
    
    private func subscriptionScene(size: CGSize) -> some View  {
        ZStack {
            OptimizedSubscriptionView {
                advance()
            }
            .frame(height: UIScreen.main.bounds.height * 0.96)
            
            VStack  {
                HStack  {
                    ElegantCloseButton(isVisible: isTextVisible) {
                        advance()
                    }
                    Spacer()
                }
                .padding()
                Spacer()
            }
        }
        .onAppear {
            revealText()
        }
    }
   
    func revealText() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            withAnimation(.easeIn(duration: 0.8)) {
                isTextVisible = true
            }
        }
    }
    
    // MARK: - Private methods
    
    private func advance() {
        switch selection {
        case .emotionalRecognition:
            impactMed.impactOccurred()
            selection = .internalExperience
            enhancedOnboardingTab = selection.rawValue
            
        case .internalExperience:
            impactMed.impactOccurred()
            selection = .beliefGap
            enhancedOnboardingTab = selection.rawValue
            
        case .beliefGap:
            impactMed.impactOccurred()
            selection = .authorityReframe
            enhancedOnboardingTab = selection.rawValue
            
        case .authorityReframe:
            impactMed.impactOccurred()
            selection = .practiceAwareness
            enhancedOnboardingTab = selection.rawValue
            
        case .practiceAwareness:
            impactMed.impactOccurred()
            selection = .ahaMoment
            enhancedOnboardingTab = selection.rawValue
            
        case .ahaMoment:
            impactMed.impactOccurred()
            selection = .identityAspiration
            enhancedOnboardingTab = selection.rawValue
            
        case .identityAspiration:
            impactMed.impactOccurred()
            selection = .futurePacing
            enhancedOnboardingTab = selection.rawValue
            
        case .futurePacing:
            impactMed.impactOccurred()
            selection = .coreMessage
            enhancedOnboardingTab = selection.rawValue
            
        case .coreMessage:
            impactMed.impactOccurred()
            selection = .transitionToPaywall
            enhancedOnboardingTab = selection.rawValue
            
        case .transitionToPaywall:
            impactMed.impactOccurred()
            selection = .subscription
            enhancedOnboardingTab = selection.rawValue
            // Map user journey to categories for notifications
            mapJourneyToCategories()
            
        case .notification:
            impactMed.impactOccurred()
            selection = .review
            enhancedOnboardingTab = selection.rawValue
            
        case .review:
            impactMed.impactOccurred()
            dismissOnboarding()
            
        case .subscription:
//            mapJourneyToCategories()
            Analytics.logEvent("EnhancedOnboardingCompleted", parameters: [
                "emotional_needs": userJourney.emotionalNeeds.joined(separator: ","),
                "internal_experience": userJourney.internalExperience,
                "belief_gap": userJourney.beliefGap,
                "authority_reframe": userJourney.authorityReframe,
                "practice_level": userJourney.practiceLevel,
                "desired_identity": userJourney.desiredIdentity,
                "future_outcome": userJourney.futureOutcome
            ])
            impactMed.impactOccurred()
            selection = .notification
            
        }
    }
    
    private func mapJourneyToCategories() {
        var categories: Set<DeclarationCategory> = []
        
        // Map emotional needs to categories
        for need in userJourney.emotionalNeeds {
            if need.contains("Peace") {
                categories.insert(.rest)
            }
            if need.contains("Healing") {
                categories.insert(.health)
            }
            if need.contains("Direction") {
                categories.insert(.wisdom)
            }
            if need.contains("Freedom from fear") || need.contains("anxiety") {
                categories.insert(.anxiety)
                categories.insert(.fear)
            }
            if need.contains("Confidence") {
                categories.insert(.confidence)
            }
            if need.contains("Provision") || need.contains("financial") {
                categories.insert(.wealth)
            }
            if need.contains("close to God") {
                categories.insert(.faith)
            }
        }
        
        // Map desired identity to categories
        if userJourney.desiredIdentity.contains("Calm") {
            categories.insert(.rest)
        }
        if userJourney.desiredIdentity.contains("Confident") {
            categories.insert(.confidence)
        }
        if userJourney.desiredIdentity.contains("Bold") {
            categories.insert(.faith)
        }
        if userJourney.desiredIdentity.contains("Peaceful") {
            categories.insert(.rest)
        }
        
        // If no categories mapped, use general
        if categories.isEmpty {
            categories.insert(.general)
        }
        
        // Save categories
        let categoriesString = categories.map { $0.rawValue }.joined(separator: ",")
        appState.selectedNotificationCategories = categoriesString
        viewModel.save(categories)
    }
    
    private func askNotificationPermission() {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            guard (settings.authorizationStatus == .authorized) ||
                    (settings.authorizationStatus == .provisional) else {
                center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                    DispatchQueue.main.async {
                        appState.notificationEnabled = granted
                        
                        if granted {
                            UIApplication.shared.registerForRemoteNotifications()
                            registerNotifications()
                        }
                        
                        withAnimation {
                            advance()
                        }
                    }
                }
                return
            }
        }
    }
    
    private func setupAppearance() {
        UIPageControl.appearance().currentPageIndicatorTintColor = UIColor(Constants.DALightBlue)
        UIPageControl.appearance().pageIndicatorTintColor = UIColor(Constants.DALightBlue).withAlphaComponent(0.2)
    }
    
    private func dismissOnboarding() {
        withAnimation {
            appState.isOnboarded = true
            appState.hasCompletedEnhancedOnboarding = true
            Analytics.logEvent("EnhancedOnboardingFinished", parameters: nil)
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
}


// MARK: - Elegant Close Button Component
private struct ElegantCloseButton: View {
    struct Configuration {
        let size: CGFloat
        let iconSize: CGFloat
        let shadowRadius: CGFloat
        let shadowOffset: CGSize
        let animationResponse: Double
        let animationDamping: Double
        
        static let `default` = Configuration(
            size: 36,
            iconSize: 16,
            shadowRadius: 8,
            shadowOffset: CGSize(width: 0, height: 4),
            animationResponse: 0.4,
            animationDamping: 0.6
        )
    }
    
    private let action: () -> Void
    private let configuration: Configuration
    private let isVisible: Bool
    private let enableHaptics: Bool
    
    init(
        configuration: Configuration = .default,
        isVisible: Bool = true,
        enableHaptics: Bool = true,
        action: @escaping () -> Void
    ) {
        self.configuration = configuration
        self.isVisible = isVisible
        self.enableHaptics = enableHaptics
        self.action = action
    }
    
    var body: some View {
        Button(action: handleAction) {
            buttonContent
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isVisible ? 1.0 : 0.8)
        .opacity(isVisible ? 1.0 : 0.0)
    }
    
    private var buttonContent: some View {
        ZStack {
            backgroundView
            iconView
        }
        .frame(width: configuration.size, height: configuration.size)
        .shadow(
            color: Color.black.opacity(0.1),
            radius: configuration.shadowRadius,
            x: configuration.shadowOffset.width,
            y: configuration.shadowOffset.height
        )
    }
    
    private var backgroundView: some View {
        Circle()
            .fill(backgroundGradient)
            .background(Circle().fill(.ultraThinMaterial))
            .overlay(Circle().stroke(borderGradient, lineWidth: 1))
    }
    
    private var iconView: some View {
        Image(systemName: "xmark")
            .font(.system(size: configuration.iconSize, weight: .semibold, design: .rounded))
            .foregroundStyle(iconGradient)
    }
    
    private var backgroundGradient: LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [
                Color.white.opacity(0.25),
                Color.white.opacity(0.1)
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private var borderGradient: LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [
                Color.white.opacity(0.3),
                Color.white.opacity(0.1)
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private var iconGradient: LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [
                Color.white.opacity(0.9),
                Color.white.opacity(0.7)
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private func handleAction() {
        if enableHaptics {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        }
        
        withAnimation(.spring(
            response: configuration.animationResponse,
            dampingFraction: configuration.animationDamping
        )) {
            action()
        }
    }
}
