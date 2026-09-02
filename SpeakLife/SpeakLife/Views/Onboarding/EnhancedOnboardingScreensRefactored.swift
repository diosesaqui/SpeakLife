//
//  EnhancedOnboardingScreensRefactored.swift
//  SpeakLife
//
//  Refactored emotionally-primed onboarding with reusable components
//

import SwiftUI
import UserNotifications

// MARK: - Screen Content Model
struct OnboardingScreenContent {
    let title: String
    let subtitle: String?
    let options: [OnboardingOption]
    let buttonTitle: String
    let screenType: OnboardingScreenType
    let progressStep: Int
    let analyticsEvent: String
    
    enum OnboardingScreenType: Equatable {
        case singleSelect
        case multiSelect(maxCount: Int)
        case autoAdvance
        case nonInteractive(delay: TimeInterval)
    }
}

struct OnboardingOption {
    let id = UUID()
    let title: String
    let icon: String?
    let color: Color
}

// MARK: - Generic Reusable Onboarding Screen
struct GenericOnboardingScreen: View {
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    
    let content: OnboardingScreenContent
    let size: CGSize
    let onContinue: (Set<String>) -> Void
    
    @State private var selectedOptions: Set<String> = []
    @State private var contentOpacity = 0.0
    @State private var showContinueButton = true
    
    private let totalSteps = 10
    
    var body: some View {
        GeometryReader { proxy in
            VStack(spacing: 0) {
                // Progress indicator
                HStack {
                    Spacer()
                    ProgressDots(current: content.progressStep, total: totalSteps)
                        .padding(.top, proxy.safeAreaInsets.top + 10)
                        .padding(.trailing, 20)
                }
                
                // Main content area
                ScrollView(showsIndicators: false) {
                    VStack(spacing: proxy.size.height < 700 ? 20 : 30) {
                        Spacer().frame(height: 20)
                        
                        // Title
                        Text(content.title)
                            .font(.system(size: proxy.size.height < 700 ? 24 : 28, weight: .bold, design: .rounded))
                            .multilineTextAlignment(.center)
                            .foregroundColor(.white)
                            .padding(.horizontal, 30)
                            .opacity(contentOpacity)
                        
                        // Subtitle if present
                        if let subtitle = content.subtitle {
                            Text(subtitle)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 30)
                                .opacity(contentOpacity)
                        }
                        
                        // Options
                        if !content.options.isEmpty {
                            VStack(spacing: 12) {
                                ForEach(content.options, id: \.id) { option in
                                    OptionButton(
                                        option: option,
                                        isSelected: selectedOptions.contains(option.title),
                                        isCompact: proxy.size.height < 700,
                                        screenType: content.screenType
                                    ) {
                                        handleOptionSelection(option.title)
                                    }
                                }
                            }
                            .padding(.horizontal, 30)
                            .opacity(contentOpacity)
                        }
                        
                        Spacer(minLength: 100)
                    }
                }
                
                // Continue button
                if showContinueButton {
                    VStack(spacing: 15) {
                        ShimmerButton(
                            colors: [.blue, .purple],
                            buttonTitle: dynamicButtonTitle,
                            action: handleContinue
                        )
                        .frame(width: size.width * 0.85, height: 54)
                        .opacity(canContinue ? 1.0 : 0.5)
                        .disabled(!canContinue)
                    }
                    .padding(.bottom, proxy.safeAreaInsets.bottom + 30)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .background(backgroundView)
        }
        .onAppear {
            animateContent()
            setupScreenBehavior()
        }
    }
    
    private var backgroundView: some View {
        ZStack {
            Image(subscriptionStore.onboardingBGImage)
                .resizable()
                .scaledToFill()
                .edgesIgnoringSafeArea(.all)
            Color.black.opacity(0.4)
                .edgesIgnoringSafeArea(.all)
        }
    }
    
    private func animateContent() {
        withAnimation(.easeIn(duration: 0.8)) {
            contentOpacity = 1.0
        }
    }
    
    private func setupScreenBehavior() {
        switch content.screenType {
        case .nonInteractive(let delay):
            showContinueButton = false
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                withAnimation {
                    showContinueButton = true
                }
            }
        case .autoAdvance:
            // Auto-advance is handled in selection
            break
        default:
            break
        }
    }
    
    private func handleOptionSelection(_ option: String) {
        switch content.screenType {
        case .singleSelect:
            selectedOptions = [option]
        case .multiSelect(let maxCount):
            if selectedOptions.contains(option) {
                selectedOptions.remove(option)
            } else if selectedOptions.count < maxCount {
                selectedOptions.insert(option)
            }
        case .autoAdvance:
            selectedOptions = [option]
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                handleContinue()
            }
        case .nonInteractive:
            break
        }
    }
    
    private func handleContinue() {
        guard canContinue else { return }
        
        AnalyticsService.shared.track(content.analyticsEvent, parameters: [
            "selections": selectedOptions.joined(separator: ",")
        ])
        
        onContinue(selectedOptions)
    }
    
    private var canContinue: Bool {
        switch content.screenType {
        case .nonInteractive:
            return showContinueButton
        case .autoAdvance:
            return true
        default:
            return !selectedOptions.isEmpty
        }
    }
    
    private var dynamicButtonTitle: String {
        if !canContinue {
            if case .nonInteractive = content.screenType {
                return content.buttonTitle
            }
            switch content.screenType {
            case .multiSelect(let maxCount):
                return "Select up to \(maxCount)"
            default:
                return "Select one"
            }
        }
        return content.buttonTitle
    }
}

// MARK: - Option Button Component
struct OptionButton: View {
    let option: OnboardingOption
    let isSelected: Bool
    let isCompact: Bool
    let screenType: OnboardingScreenContent.OnboardingScreenType
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                if let icon = option.icon {
                    Image(systemName: icon)
                        .font(.system(size: isCompact ? 18 : 20))
                        .frame(width: 20)
                }
                
                Text(option.title)
                    .font(.system(size: isCompact ? 15 : 16, weight: .medium))
                    .multilineTextAlignment(option.icon != nil ? .leading : .center)
                
                if option.icon != nil {
                    Spacer()
                }
                
                if case .multiSelect = screenType, isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.green)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, isCompact ? 14 : 16)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? option.color.opacity(0.2) : Color.white.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? option.color : Color.white.opacity(0.2), lineWidth: 1)
                    )
            )
            .foregroundColor(.white)
        }
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
    }
}

// MARK: - Screen Content Definitions
struct OnboardingContentProvider {
    
    static let emotionalRecognition = OnboardingScreenContent(
        title: "What area of your life needs God's love most today?",
        subtitle: "Select up to two.",
        options: [
            OnboardingOption(title: "Peace in my mind", icon: "brain.head.profile", color: .blue),
            OnboardingOption(title: "Healing in my body", icon: "heart.circle", color: .blue),
            OnboardingOption(title: "Direction for my future", icon: "location.north.line", color: .blue),
            OnboardingOption(title: "Freedom from fear or anxiety", icon: "shield.slash", color: .blue),
            OnboardingOption(title: "Confidence in who I am", icon: "person.fill.checkmark", color: .blue),
            OnboardingOption(title: "Provision and financial peace", icon: "dollarsign.circle", color: .blue),
            OnboardingOption(title: "Feeling close to God again", icon: "hands.sparkles", color: .blue)
        ],
        buttonTitle: "Continue →",
        screenType: .multiSelect(maxCount: 2),
        progressStep: 0,
        analyticsEvent: "EmotionalRecognition_Complete"
    )
    
    static let internalExperience = OnboardingScreenContent(
        title: "When pressure hits your life, what usually takes over?",
        subtitle: nil,
        options: [
            OnboardingOption(title: "My thoughts spiral", icon: nil, color: .blue),
            OnboardingOption(title: "I feel anxious or overwhelmed", icon: nil, color: .blue),
            OnboardingOption(title: "I shut down emotionally", icon: nil, color: .blue),
            OnboardingOption(title: "I try to stay strong but feel tired", icon: nil, color: .blue),
            OnboardingOption(title: "I feel distant from God", icon: nil, color: .blue)
        ],
        buttonTitle: "Continue →",
        screenType: .singleSelect,
        progressStep: 1,
        analyticsEvent: "InternalExperience_Complete"
    )
    
    static let beliefGap = OnboardingScreenContent(
        title: "Which feels most true right now?",
        subtitle: nil,
        options: [
            OnboardingOption(title: "I know God loves me, but I don't always feel it", icon: nil, color: .blue),
            OnboardingOption(title: "I believe God's Word, but struggle to live from it daily", icon: nil, color: .blue),
            OnboardingOption(title: "I want to live in faith, not fear", icon: nil, color: .blue)
        ],
        buttonTitle: "Continue →",
        screenType: .singleSelect,
        progressStep: 2,
        analyticsEvent: "BeliefGap_Complete"
    )
    
    static let authorityReframe = OnboardingScreenContent(
        title: "Do you feel more like you're reacting to life… or responding with truth?",
        subtitle: nil,
        options: [
            OnboardingOption(title: "Reacting most days", icon: nil, color: .blue),
            OnboardingOption(title: "Trying to respond with truth", icon: nil, color: .blue),
            OnboardingOption(title: "Learning how to respond with truth", icon: nil, color: .blue)
        ],
        buttonTitle: "Continue →",
        screenType: .singleSelect,
        progressStep: 3,
        analyticsEvent: "AuthorityReframe_Complete"
    )
    
    static let practiceAwareness = OnboardingScreenContent(
        title: "Have you ever spoken God's Word over your life before?",
        subtitle: nil,
        options: [
            OnboardingOption(title: "Yes — and it changed me", icon: nil, color: .blue),
            OnboardingOption(title: "Yes, but I wasn't consistent", icon: nil, color: .blue),
            OnboardingOption(title: "I've heard of it, but never made it a habit", icon: nil, color: .blue),
            OnboardingOption(title: "Not really", icon: nil, color: .blue)
        ],
        buttonTitle: "Continue →",
        screenType: .singleSelect,
        progressStep: 4,
        analyticsEvent: "PracticeAwareness_Complete"
    )
    
    static let ahaMoment = OnboardingScreenContent(
        title: "Your first response\nshapes everything.",
        subtitle: "Make it God's Word, not worry.",
        options: [],
        buttonTitle: "I'm ready →",
        screenType: .nonInteractive(delay: 3.0),
        progressStep: 5,
        analyticsEvent: "AhaMoment_Complete"
    )
    
    static let identityAspiration = OnboardingScreenContent(
        title: "How do you want to show up when life tests your faith?",
        subtitle: nil,
        options: [
            OnboardingOption(title: "Calm and anchored", icon: nil, color: .blue),
            OnboardingOption(title: "Confident in God's promises", icon: nil, color: .blue),
            OnboardingOption(title: "Spirit-led and disciplined", icon: nil, color: .blue),
            OnboardingOption(title: "Bold in faith and prayer", icon: nil, color: .blue),
            OnboardingOption(title: "Peaceful, not anxious", icon: nil, color: .blue)
        ],
        buttonTitle: "Yes, this is who I am →",
        screenType: .singleSelect,
        progressStep: 6,
        analyticsEvent: "IdentityAspiration_Complete"
    )
    
    static let futurePacing = OnboardingScreenContent(
        title: "If you spent a few minutes a day renewing your mind with God's truth… what would matter most to you?",
        subtitle: nil,
        options: [
            OnboardingOption(title: "Feeling calmer throughout the day", icon: nil, color: .teal),
            OnboardingOption(title: "Trusting God more deeply", icon: nil, color: .teal),
            OnboardingOption(title: "Speaking life instead of worry", icon: nil, color: .teal),
            OnboardingOption(title: "Staying rooted when life hits", icon: nil, color: .teal),
            OnboardingOption(title: "Hearing God's promises daily", icon: nil, color: .teal)
        ],
        buttonTitle: "This is what I want →",
        screenType: .singleSelect,
        progressStep: 7,
        analyticsEvent: "FuturePacing_Complete"
    )
    
    static let coreMessage = OnboardingScreenContent(
        title: "SpeakLife helps you stop reacting to life—and start responding with God's Word.",
        subtitle: "Truth changes how you think.\nSpeaking it changes how you live.",
        options: [],
        buttonTitle: "Show me how →",
        screenType: .nonInteractive(delay: 2.0),
        progressStep: 8,
        analyticsEvent: "CoreMessage_Complete"
    )
    
    // Simplified spiritual warfare intro - will use custom screen
    static let spiritualWarfare = OnboardingScreenContent(
        title: "Your mind is under attack",
        subtitle: "Every. Single. Day.",
        options: [], // Custom screen will handle visuals
        buttonTitle: "Show me how to fight back →",
        screenType: .nonInteractive(delay: 3.0),
        progressStep: 0,
        analyticsEvent: "SpiritualWarfare_Intro"
    )
    
    static let enemyEntry = OnboardingScreenContent(
        title: "Recognize these whispers?",
        subtitle: "\"You're not enough.\" \"God's forgotten you.\" \"Nothing will change.\" \"You'll always struggle.\"",
        options: [],
        buttonTitle: "Yes, I hear these lies →",
        screenType: .nonInteractive(delay: 3.0),
        progressStep: 1,
        analyticsEvent: "EnemyEntry_Complete"
    )
    
    static let thoughtAgreement = OnboardingScreenContent(
        title: "When you agree with those thoughts, they become your reality",
        subtitle: "That's how the enemy steals your peace, your joy, and your victory.",
        options: [],
        buttonTitle: "How do I stop this? →",
        screenType: .nonInteractive(delay: 2.5),
        progressStep: 2,
        analyticsEvent: "ThoughtAgreement_Complete"
    )
    
    static let biblicalSolution = OnboardingScreenContent(
        title: "God gave you the solution",
        subtitle: "\"Be transformed by the renewing of your mind\" - Romans 12:2",
        options: [],
        buttonTitle: "Show me how →",
        screenType: .nonInteractive(delay: 2.5),
        progressStep: 3,
        analyticsEvent: "BiblicalSolution_Complete"
    )
    
    static let thoughtIdentification = OnboardingScreenContent(
        title: "Which thoughts try to steal from you most?",
        subtitle: "Select all that feel familiar.",
        options: [
            OnboardingOption(title: "I'm not worthy of love", icon: "heart.slash", color: .red),
            OnboardingOption(title: "My situation won't change", icon: "lock.circle", color: .red),
            OnboardingOption(title: "God's disappointed in me", icon: "cloud.rain", color: .red),
            OnboardingOption(title: "I'll always struggle with this", icon: "infinity.circle", color: .red),
            OnboardingOption(title: "I'm too broken to be used", icon: "bandage", color: .red),
            OnboardingOption(title: "Fear of the future", icon: "exclamationmark.triangle", color: .red)
        ],
        buttonTitle: "These attack me →",
        screenType: .multiSelect(maxCount: 3),
        progressStep: 4,
        analyticsEvent: "ThoughtIdentification_Complete"
    )
    
    static let victoryPosition = OnboardingScreenContent(
        title: "Here's the truth that changes everything",
        subtitle: "Jesus already defeated those lies. You're not fighting FOR victory. You're fighting FROM victory.",
        options: [],
        buttonTitle: "I receive this truth →",
        screenType: .nonInteractive(delay: 3.0),
        progressStep: 5,
        analyticsEvent: "VictoryPosition_Complete"
    )
    
    static let dailyRenewal = OnboardingScreenContent(
        title: "Every morning, you have a choice",
        subtitle: "React to your thoughts and spiral... or respond with God's truth and rise.",
        options: [],
        buttonTitle: "I choose truth →",
        screenType: .nonInteractive(delay: 2.0),
        progressStep: 6,
        analyticsEvent: "DailyRenewal_Complete"
    )
    
    static let speakLifeSolution = OnboardingScreenContent(
        title: "SpeakLife trains you to win this battle",
        subtitle: "Recognize lies. Replace with truth. Renew your mind. Every single day.",
        options: [],
        buttonTitle: "Start my training →",
        screenType: .nonInteractive(delay: 2.0),
        progressStep: 7,
        analyticsEvent: "SpeakLifeSolution_Complete"
    )
    
    static let mindRenewalBenefits = OnboardingScreenContent(
        title: "In just 21 days of daily renewal",
        subtitle: "Peace replaces anxiety. Faith overcomes fear. Joy defeats darkness. You walk in authority.",
        options: [],
        buttonTitle: "I want this transformation →",
        screenType: .nonInteractive(delay: 2.5),
        progressStep: 8,
        analyticsEvent: "MindRenewalBenefits_Complete"
    )
    
    static let commitmentCall = OnboardingScreenContent(
        title: "Will you commit to renewing your mind?",
        subtitle: "Just a few minutes each day can break years of mental strongholds.",
        options: [],
        buttonTitle: "Yes, I'm ready →",
        screenType: .nonInteractive(delay: 2.0),
        progressStep: 9,
        analyticsEvent: "CommitmentCall_Complete"
    )
    
    static func transitionToPaywall(journey: OnboardingUserJourney) -> OnboardingScreenContent {
        let title = getPersonalizedTitle(journey: journey)
        let features = getPersonalizedFeatures(journey: journey)
        
        // Create options from features
        let options = features.map { feature in
            OnboardingOption(title: feature, icon: "checkmark.circle.fill", color: .green)
        }
        
        return OnboardingScreenContent(
            title: title,
            subtitle: "SpeakLife will guide you daily to declare God's promises, renew your mind, and respond to life with peace and authority.",
            options: options,
            buttonTitle: "Start Your Free Trial →",
            screenType: .nonInteractive(delay: 0),
            progressStep: 9,
            analyticsEvent: "TransitionToPaywall_Complete"
        )
    }
    
    private static func getPersonalizedTitle(journey: OnboardingUserJourney) -> String {
        if let primaryNeed = journey.emotionalNeeds.first {
            if primaryNeed.contains("Peace") {
                return "Ready to find the peace you're seeking?"
            } else if primaryNeed.contains("Healing") {
                return "Ready to speak healing over your life?"
            } else if primaryNeed.contains("Direction") {
                return "Ready to hear God's direction clearly?"
            } else if primaryNeed.contains("Freedom") {
                return "Ready to break free from anxiety?"
            } else if primaryNeed.contains("Confidence") {
                return "Ready to walk in confident faith?"
            }
        }
        return "Ready to start responding with God’s Word?"
    }
    
    private static func getPersonalizedFeatures(journey: OnboardingUserJourney) -> [String] {
        var features: [String] = []
        
        if journey.internalExperience.contains("spiral") || journey.internalExperience.contains("anxious") {
            features.append("Daily declarations to calm anxious thoughts")
        }
        
        if journey.desiredIdentity.contains("Calm") || journey.desiredIdentity.contains("Peaceful") {
            features.append("Peace-focused affirmations for every situation")
        }
        
        if journey.practiceLevel.contains("Not really") || journey.practiceLevel.contains("never practiced") {
            features.append("Beginner-friendly guided declarations")
        }
        
        features.append("Based on what you shared, this is designed for you.")
        features.append("Personalized daily reminders")
        features.append("Faith-Renewing Audio")
        features.append("Believers growing together")
        
        return features
    }
}
