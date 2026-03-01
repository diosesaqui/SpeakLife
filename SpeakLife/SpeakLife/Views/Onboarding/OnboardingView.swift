//
//  OnboardingView.swift
//  Dios Es Aqui
//
//  Created by Riccardo Washington on 2/7/22.
//

import SwiftUI
import FirebaseAnalytics

struct OnboardingView: View  {
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var viewModel: DeclarationViewModel
    @EnvironmentObject var streakViewModel: StreakViewModel
    @Environment(\.colorScheme) var colorScheme
    
    @State var selection: Tab = .testimonials
    @AppStorage("onboardingTab") var onboardingTab = Tab.testimonials.rawValue
    @State private var isTextVisible = false
   
    let impactMed = UIImpactFeedbackGenerator(style: .soft)
    
    var body: some View {
        GeometryReader { geometry in
            TabView(selection: $selection) {
                
                // SCREEN 1: Testimonials
                TestimonialsOnboardingView(size: geometry.size) {
                    withAnimation {
                        advance()
                    }
                }
                .tag(Tab.testimonials)
                
                // SCREEN 2: Scripture Anchor
                ScriptureAnchorScreen(size: geometry.size) {
                    withAnimation {
                        advance()
                    }
                }
                .tag(Tab.scriptureAnchor)
                
                // SCREEN 3: Reframe Problem
                ReframeProblemScreen(size: geometry.size) {
                    withAnimation {
                        advance()
                    }
                }
                .tag(Tab.reframeProblem)
                
                // SCREEN 4: Jesus Method
                JesusMethodScreen(size: geometry.size) {
                    withAnimation {
                        advance()
                    }
                }
                .tag(Tab.jesusMethod)
                
                // SCREEN 5: Self-Diagnosis
                SelfDiagnosisScreen(size: geometry.size) {
                    withAnimation {
                        advance()
                    }
                }
                .tag(Tab.selfDiagnosis)
                
                // SCREEN 6: Truth Gap
                TruthGapScreen(size: geometry.size) {
                    withAnimation {
                        advance()
                    }
                }
                .tag(Tab.truthGap)
                
                // SCREEN 7: Application
                ApplicationScreen(size: geometry.size) {
                    withAnimation {
                        advance()
                    }
                }
                .tag(Tab.application)
                
                // SCREEN 8: Micro-Commitment
                MicroCommitmentScreen(size: geometry.size) {
                    withAnimation {
                        advance()
                    }
                }
                .tag(Tab.microCommitment)
                
                // SCREEN 9: Position SpeakLife
                PositionSpeakLifeScreen(size: geometry.size) {
                    withAnimation {
                        advance()
                    }
                }
                .tag(Tab.positionSpeakLife)
                
                // Subscription Screen
                subscriptionScene(size: geometry.size)
                    .tag(Tab.subscription)
                    
                // Notification Screen
                NotificationOnboarding(size: geometry.size) {
                    withAnimation {
                        askNotificationPermission()
                    }
                }
                .tag(Tab.notification)
                
                
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .font(.headline)
            .ignoresSafeArea()
        }
        .ignoresSafeArea()
        .preferredColorScheme(.light)
      
        .onAppear {
            setSelection()
            UIScrollView.appearance().isScrollEnabled = false
            setupAppearance()
            Analytics.logEvent(Event.freshInstall, parameters: nil)
        }
    }

    private func setSelection() {
        guard let tab = Tab(rawValue: onboardingTab) else { return }
        selection = tab
    }
    
    // MARK: - Private Views
    
    private func subscriptionScene(size: CGSize) -> some View  {
        ZStack {
            OptimizedSubscriptionView() {
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
                case .testimonials:
                    impactMed.impactOccurred()
                    selection = .scriptureAnchor
                    onboardingTab = selection.rawValue
                    Analytics.logEvent("TestimonialsDone", parameters: nil)
                    
                case .scriptureAnchor:
                    impactMed.impactOccurred()
                    selection = .reframeProblem
                    onboardingTab = selection.rawValue
                    Analytics.logEvent("ScriptureAnchorDone", parameters: nil)
                    
                case .reframeProblem:
                    impactMed.impactOccurred()
                    selection = .jesusMethod
                    onboardingTab = selection.rawValue
                    Analytics.logEvent("ReframeProblemDone", parameters: nil)
                    
                case .jesusMethod:
                    impactMed.impactOccurred()
                    selection = .selfDiagnosis
                    onboardingTab = selection.rawValue
                    Analytics.logEvent("JesusMethodDone", parameters: nil)
                    
                case .selfDiagnosis:
                    impactMed.impactOccurred()
                    selection = .truthGap
                    onboardingTab = selection.rawValue
                    Analytics.logEvent("SelfDiagnosisDone", parameters: nil)
                    
                case .truthGap:
                    impactMed.impactOccurred()
                    selection = .application
                    onboardingTab = selection.rawValue
                    Analytics.logEvent("TruthGapDone", parameters: nil)
                    
                case .application:
                    impactMed.impactOccurred()
                    selection = .microCommitment
                    onboardingTab = selection.rawValue
                    Analytics.logEvent("ApplicationDone", parameters: nil)
                    
                case .microCommitment:
                    impactMed.impactOccurred()
                    selection = .positionSpeakLife
                    onboardingTab = selection.rawValue
                    Analytics.logEvent("MicroCommitmentDone", parameters: nil)
                    
                case .positionSpeakLife:
                    impactMed.impactOccurred()
                    selection = .subscription
                    onboardingTab = selection.rawValue
                    Analytics.logEvent("PositionSpeakLifeDone", parameters: nil)
                    
                case .subscription:
                    impactMed.impactOccurred()
                    selection = .notification
                    onboardingTab = selection.rawValue
                    Analytics.logEvent("SubscriptionScreenDone", parameters: nil)
                    
                case .notification:
                    Analytics.logEvent("NotificationScreenDone", parameters: nil)
                    impactMed.impactOccurred()
                    dismissOnboarding()
        }
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
            LifecycleNotificationService.shared.scheduleLifecycleNotifications()
            Analytics.logEvent("onBoardingFinished", parameters: nil)
        }
    }
    
    private func registerNotifications() {
        if appState.notificationEnabled {
            // Set default categories for new onboarding flow
            let defaultCategories: Set<DeclarationCategory> = [.faith, .confidence, .wisdom, .speaklife]
            appState.selectedNotificationCategories = defaultCategories.map { $0.rawValue }.joined(separator: ",")
            viewModel.save(defaultCategories)
            
            NotificationManager.shared.registerNotifications(count: appState.notificationCount,
                                                             startTime: appState.startTimeIndex,
                                                             endTime: appState.endTimeIndex,
                                                             categories: defaultCategories)
            appState.lastNotificationSetDate = Date()
        }
    }
}


struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView()
    }
}

// MARK: - Elegant Close Button Component
public struct ElegantCloseButton: View {
    // MARK: - Configuration
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
    
    // MARK: - Properties
    private let action: () -> Void
    private let configuration: Configuration
    private let isVisible: Bool
    private let enableHaptics: Bool
    
    // MARK: - Initialization
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
    
    // MARK: - View Body
    public var body: some View {
        Button(action: handleAction) {
            buttonContent
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isVisible ? 1.0 : 0.8)
        .opacity(isVisible ? 1.0 : 0.0)
    }
    
    // MARK: - Private Views
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
    
    // MARK: - Computed Properties
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
    
    // MARK: - Actions
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

