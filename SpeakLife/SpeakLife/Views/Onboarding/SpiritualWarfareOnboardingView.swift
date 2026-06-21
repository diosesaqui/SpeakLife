//
//  SpiritualWarfareOnboardingView.swift
//  SpeakLife
//
//  Spiritual warfare themed onboarding focusing on mind renewal
//

import SwiftUI
import FirebaseAnalytics
import UserNotifications

// MARK: - Spiritual Warfare Tab Enum
enum SpiritualWarfareTab: Int {
    case testimonials = 0
    case introduction = 1
    case enemyEntry = 2
    case thoughtAgreement = 3
    case biblicalSolution = 4
    case thoughtIdentification = 5
    case victoryPosition = 6
    case dailyRenewal = 7
    case speakLifeSolution = 8
    case mindRenewalBenefits = 9
    case commitmentCall = 10
    case transitionToPaywall = 11
    case subscription = 12
    case notification = 13
    case review = 14
}

// MARK: - Spiritual Warfare User Journey
class SpiritualWarfareJourneyViewModel: ObservableObject {
    @Published var identifiedThoughts: Set<String> = []
    @Published var selectedBenefit: String = ""
    @Published var commitment: String = ""
    
    var journey: SpiritualWarfareJourney {
        SpiritualWarfareJourney(
            identifiedThoughts: identifiedThoughts,
            selectedBenefit: selectedBenefit,
            commitment: commitment
        )
    }
}

struct SpiritualWarfareJourney {
    var identifiedThoughts: Set<String> = []
    var selectedBenefit: String = ""
    var commitment: String = ""
}

// MARK: - Main Spiritual Warfare Onboarding View
struct SpiritualWarfareOnboardingView: View {
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var viewModel: DeclarationViewModel
    @EnvironmentObject var streakViewModel: StreakViewModel
    @Environment(\.colorScheme) var colorScheme
    
    @State var selection: SpiritualWarfareTab = .testimonials
    @StateObject var userJourney = SpiritualWarfareJourneyViewModel()
    @AppStorage("spiritualWarfareOnboardingTab") var spiritualWarfareOnboardingTab = SpiritualWarfareTab.testimonials.rawValue
   
    let impactMed = UIImpactFeedbackGenerator(style: .soft)
    
    var body: some View {
        GeometryReader { geometry in
            TabView(selection: $selection) {
                
                // Screen 1: Testimonials - Social proof at the beginning
                TestimonialsOnboardingView(size: geometry.size) {
                    advance()
                }
                .tag(SpiritualWarfareTab.testimonials)
                
                // Screen 2: Introduction - Mind as battlefield (Custom)
                BattleStatsScreen(
                    size: geometry.size,
                    onContinue: advance
                )
                .tag(SpiritualWarfareTab.introduction)
                
                // Screen 2: Enemy Entry - How thoughts attack
                GenericOnboardingScreen(
                    content: OnboardingContentProvider.enemyEntry,
                    size: geometry.size
                ) { _ in
                    advance()
                }
                .tag(SpiritualWarfareTab.enemyEntry)
                
                // Screen 3: Thought Agreement - How we give power to lies
                GenericOnboardingScreen(
                    content: OnboardingContentProvider.thoughtAgreement,
                    size: geometry.size
                ) { _ in
                    advance()
                }
                .tag(SpiritualWarfareTab.thoughtAgreement)
                
                // Screen 4: Biblical Solution - Romans 12:2
                GenericOnboardingScreen(
                    content: OnboardingContentProvider.biblicalSolution,
                    size: geometry.size
                ) { _ in
                    advance()
                }
                .tag(SpiritualWarfareTab.biblicalSolution)
                
                // Screen 5: Thought Identification - Personal recognition
                GenericOnboardingScreen(
                    content: OnboardingContentProvider.thoughtIdentification,
                    size: geometry.size
                ) { selections in
                    userJourney.identifiedThoughts = selections
                    advance()
                }
                .tag(SpiritualWarfareTab.thoughtIdentification)
                
                // Screen 6: Victory Position - Fighting from victory (Custom)
                VictoryPositionScreen(
                    size: geometry.size,
                    onContinue: advance
                )
                .tag(SpiritualWarfareTab.victoryPosition)
                
                // Screen 7: Daily Renewal - The choice (Custom)
                TwoPathsScreen(
                    size: geometry.size,
                    onContinue: advance
                )
                .tag(SpiritualWarfareTab.dailyRenewal)
                
                // Screen 8: SpeakLife Solution
                GenericOnboardingScreen(
                    content: OnboardingContentProvider.speakLifeSolution,
                    size: geometry.size
                ) { _ in
                    advance()
                }
                .tag(SpiritualWarfareTab.speakLifeSolution)
                
                // Screen 9: Mind Renewal Benefits
                GenericOnboardingScreen(
                    content: OnboardingContentProvider.mindRenewalBenefits,
                    size: geometry.size
                ) { selections in
                    userJourney.selectedBenefit = selections.first ?? ""
                    advance()
                }
                .tag(SpiritualWarfareTab.mindRenewalBenefits)
                
                // Screen 10: Commitment Call
                GenericOnboardingScreen(
                    content: OnboardingContentProvider.commitmentCall,
                    size: geometry.size
                ) { selections in
                    userJourney.commitment = selections.first ?? ""
                    advance()
                }
                .tag(SpiritualWarfareTab.commitmentCall)
                
                // Transition to Paywall
                GenericOnboardingScreen(
                    content: createPersonalizedPaywallTransition(),
                    size: geometry.size
                ) { _ in
                    advance()
                }
                .tag(SpiritualWarfareTab.transitionToPaywall)
                
                // Subscription
                subscriptionScene(size: geometry.size)
                    .tag(SpiritualWarfareTab.subscription)
                
                // Notifications
                NotificationOnboarding(size: geometry.size) {
                    withAnimation {
                        askNotificationPermission()
                    }
                }
                .tag(SpiritualWarfareTab.notification)
                
                // Rating
                RatingView(size: geometry.size) {
                    withAnimation {
                        advance()
                    }
                }
                .tag(SpiritualWarfareTab.review)
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
            Analytics.logEvent("SpiritualWarfareOnboardingStarted", parameters: nil)
        }
    }

    private func setSelection() {
        guard let tab = SpiritualWarfareTab(rawValue: spiritualWarfareOnboardingTab) else { return }
        selection = tab
    }
    
    // MARK: - Private Views
    
    private func subscriptionScene(size: CGSize) -> some View  {
        Group {
            if subscriptionStore.useHighConversionPaywall {
                HighConversionPaywallView {
                    advance()
                }
            } else {
                OptimizedSubscriptionViewV2 {
                    advance()
                }
            }
        }
        .ignoresSafeArea()
    }
    
    // MARK: - Personalized Content Creation
    
    private func createPersonalizedPaywallTransition() -> OnboardingScreenContent {
        let title = getPersonalizedTitle()
        let features = getPersonalizedFeatures()
        
        let options = features.map { feature in
            OnboardingOption(title: feature, icon: "checkmark.circle.fill", color: .green)
        }
        
        return OnboardingScreenContent(
            title: title,
            subtitle: "Your mind is the gateway to your destiny. Guard it with God's Word.",
            options: options,
            buttonTitle: "Start My Transformation →",
            screenType: .nonInteractive(delay: 0),
            progressStep: 10,
            analyticsEvent: "SpiritualWarfare_TransitionToPaywall"
        )
    }
    
    private func getPersonalizedTitle() -> String {
        if let primaryThought = userJourney.identifiedThoughts.first {
            if primaryThought.contains("worthy") {
                return "Ready to know your true worth in Christ?"
            } else if primaryThought.contains("change") {
                return "Ready to break free from hopelessness?"
            } else if primaryThought.contains("disappointed") {
                return "Ready to experience God's delight in you?"
            } else if primaryThought.contains("broken") {
                return "Ready to see how God uses the broken?"
            } else if primaryThought.contains("Fear") {
                return "Ready to walk in fearless faith?"
            } else if primaryThought.contains("struggle") {
                return "Ready to break the cycle?"
            }
        }
        return "Ready to win the battle for your mind?"
    }
    
    private func getPersonalizedFeatures() -> [String] {
        var features: [String] = []
        
        // Add features based on identified thoughts
        if userJourney.identifiedThoughts.contains(where: { $0.contains("worthy") || $0.contains("love") }) {
            features.append("Daily identity affirmations from Scripture")
        }
        
        if userJourney.identifiedThoughts.contains(where: { $0.contains("Fear") || $0.contains("future") }) {
            features.append("Fear-breaking declarations")
        }
        
        if userJourney.identifiedThoughts.contains(where: { $0.contains("broken") || $0.contains("struggle") }) {
            features.append("Healing and restoration promises")
        }
        
        // Add benefit-based features
        if userJourney.selectedBenefit.contains("Peace") {
            features.append("Peace-speaking morning routines")
        } else if userJourney.selectedBenefit.contains("Faith") {
            features.append("Faith-building power declarations")
        } else if userJourney.selectedBenefit.contains("Joy") {
            features.append("Joy-restoring biblical truths")
        }
        
        // Standard features
        features.append("Thought-replacement training")
        features.append("Spiritual warfare strategies")
        features.append("Mind renewal accountability")
        features.append("Victory reminders throughout your day")
        
        return Array(features.prefix(5))
    }
    
    // MARK: - Helper Methods
    
    private func advance() {
        let nextTab = getNextTab()
        
        if nextTab == .subscription {
            // Track pre-subscription analytics
            Analytics.logEvent("SpiritualWarfare_PreSubscription", parameters: [
                "identified_thoughts": userJourney.identifiedThoughts.joined(separator: ","),
                "selected_benefit": userJourney.selectedBenefit,
                "commitment": userJourney.commitment
            ])
        }
        
        withAnimation {
            selection = nextTab
            spiritualWarfareOnboardingTab = nextTab.rawValue
            
            // End onboarding after review is completed
            if selection == .review {
                // Give time for review to show, then end onboarding
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    endOnboarding()
                }
            }
        }
        Juice.play(.tapLight)
    }
    
    private func getNextTab() -> SpiritualWarfareTab {
        switch selection {
        case .testimonials:
            return .introduction
        case .introduction:
            return .enemyEntry
        case .enemyEntry:
            return .thoughtAgreement
        case .thoughtAgreement:
            return .biblicalSolution
        case .biblicalSolution:
            return .thoughtIdentification
        case .thoughtIdentification:
            return .victoryPosition
        case .victoryPosition:
            return .dailyRenewal
        case .dailyRenewal:
            return .speakLifeSolution
        case .speakLifeSolution:
            return .mindRenewalBenefits
        case .mindRenewalBenefits:
            return .commitmentCall
        case .commitmentCall:
            return .transitionToPaywall
        case .transitionToPaywall:
            return .subscription
        case .subscription:
            return .notification 
        case .notification:
            return .review
        case .review:
            return .review // This shouldn't be called - endOnboarding() handles it
        }
    }
    
    func askNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { success, error in
            if success {
                Analytics.logEvent("notification_permission_granted", parameters: nil)
                advance()
            } else if let _ = error {
                Analytics.logEvent("notification_permission_error", parameters: nil)
                advance()
            } else {
                Analytics.logEvent("notification_permission_denied", parameters: nil)
                advance()
            }
        }
    }
    
    private func endOnboarding() {
        Analytics.logEvent("SpiritualWarfareOnboardingCompleted", parameters: [
            "identified_thoughts_count": userJourney.identifiedThoughts.count,
            "commitment": userJourney.commitment
        ])
        
        withAnimation {
            appState.isOnboarded = true
            LifecycleNotificationService.shared.scheduleLifecycleNotifications()
        }
    }
    
    private func setupAppearance() {
        UIPageControl.appearance().isHidden = true
    }
}
