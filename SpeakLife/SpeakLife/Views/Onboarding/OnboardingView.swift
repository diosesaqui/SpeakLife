//
//  OnboardingView.swift
//  SpeakLife
//
//  5-screen high-conversion onboarding
//  Flow: emotionalHook → categorySelect → livePreview → socialProof → subscription → notification
//

import SwiftUI
import FirebaseAnalytics

struct OnboardingView: View {
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var viewModel: DeclarationViewModel
    @EnvironmentObject var streakViewModel: StreakViewModel

    @State var selection: Tab = .emotionalHook
    @AppStorage("onboardingTab") var onboardingTab = Tab.emotionalHook.rawValue
    @State private var isTextVisible = false
    @State private var selectedCategories: [DeclarationCategory] = []
    @State private var savedDeclaration: PersonalDeclaration? = nil
    @State private var showNewDeclarationSheet = false

    let impactMed = UIImpactFeedbackGenerator(style: .soft)

    // Progress mapping — only show dots on pre-paywall screens
    private var progressStep: Int? {
        switch selection {
        case .emotionalHook:    return 1
        case .categorySelect:   return 2
        case .livePreview:      return 3
        case .socialProof:      return 4
        case .dailyCommitment:  return 5
        default:                return nil
        }
    }
    private let totalSteps = 5

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                TabView(selection: $selection) {

                    // SCREEN 1: Emotional Hook
                    EmotionalHookScreen(size: geometry.size) {
                        withAnimation { advance() }
                    }
                    .tag(Tab.emotionalHook)

                    // SCREEN 2: Category Selection
                    CategorySelectScreen(size: geometry.size) {
                        withAnimation { advance() }
                    }
                    .tag(Tab.categorySelect)

                    // SCREEN 3: Live Declaration Preview — personalized to selected category
                    LiveDeclarationPreviewScreen(size: geometry.size) {
                        withAnimation { advance() }
                    }
                    .tag(Tab.livePreview)

                    // SCREEN 4: Social Proof — before/after transformation stories
                    TransformationSocialProofScreen(size: geometry.size) {
                        withAnimation { advance() }
                    }
                    .tag(Tab.socialProof)

                    // SCREEN 5: Daily Commitment — sets expectation before paywall
                    DailyCommitmentScreen(size: geometry.size) {
                        Analytics.logEvent("onboarding_commitment_done", parameters: nil)
                        advance()
                    }
                    .tag(Tab.dailyCommitment)

                    // SCREEN 6: Personal Declaration — "What's one thing you're trusting God for?"
                    PersonalDeclarationOnboardingView(
                        viewModel: DIContainer.shared.makePersonalDeclarationViewModel(),
                        size: geometry.size,
                        flow: "legacy"
                    ) { declaration in
                        savedDeclaration = declaration
                        withAnimation { advance() }
                    }
                    .tag(Tab.personalDeclaration)

                    // SCREEN 7: Subscription / Paywall
                    subscriptionScene(size: geometry.size)
                        .tag(Tab.subscription)

                    // POST-PAYWALL: Notification Permission
                    NotificationOnboarding(size: geometry.size) {
                        withAnimation { askNotificationPermission() }
                    }
                    .tag(Tab.notification)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .font(.headline)
                .ignoresSafeArea()

                // Progress dots — visible on pre-paywall screens only
                if let step = progressStep {
                    HStack(spacing: 6) {
                        ForEach(1...totalSteps, id: \.self) { i in
                            Capsule()
                                .fill(i <= step ? Color.white : Color.white.opacity(0.25))
                                .frame(width: i == step ? 20 : 6, height: 6)
                                .animation(.spring(response: 0.4, dampingFraction: 0.7), value: step)
                        }
                    }
                    .padding(.top, geometry.safeAreaInsets.top + 12)
                }
            }
        }
        .ignoresSafeArea()
        .preferredColorScheme(.light)
        .onAppear {
            setSelection()
            UIScrollView.appearance().isScrollEnabled = false
            setupAppearance()
            Analytics.logEvent(Event.freshInstall, parameters: nil)
            // Start background music on onboarding launch
            AudioPlayerService.shared.playSound(files: resources)
        }
    }

    // MARK: - Subscription Scene

    private func subscriptionScene(size: CGSize) -> some View {
        OptimizedSubscriptionView() {
            advance()
        }
        .frame(height: UIScreen.main.bounds.height * 0.96)
    }

    private func revealText() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            withAnimation(.easeIn(duration: 0.8)) {
                isTextVisible = true
            }
        }
    }

    // MARK: - Navigation

    private func advance() {
        switch selection {
        case .emotionalHook:
            impactMed.impactOccurred()
            selection = .categorySelect
            onboardingTab = selection.rawValue
            Analytics.logEvent("onboarding_hook_done", parameters: nil)

        case .categorySelect:
            impactMed.impactOccurred()
            selection = .livePreview
            onboardingTab = selection.rawValue
            Analytics.logEvent("onboarding_category_done", parameters: nil)

        case .livePreview:
            impactMed.impactOccurred()
            selection = .socialProof
            onboardingTab = selection.rawValue
            Analytics.logEvent("onboarding_preview_done", parameters: nil)

        case .socialProof:
            impactMed.impactOccurred()
            selection = .dailyCommitment
            onboardingTab = selection.rawValue
            Analytics.logEvent("onboarding_social_proof_done", parameters: nil)

        case .dailyCommitment:
            impactMed.impactOccurred()
            selection = .personalDeclaration
            onboardingTab = selection.rawValue
            Analytics.logEvent("onboarding_commitment_done", parameters: nil)

        case .personalDeclaration:
            impactMed.impactOccurred()
            selection = .subscription
            onboardingTab = selection.rawValue
            Analytics.logEvent("onboarding_personal_declaration_done", parameters: nil)

        case .subscription:
            impactMed.impactOccurred()
            selection = .notification
            onboardingTab = selection.rawValue
            Analytics.logEvent("onboarding_subscription_done", parameters: nil)

        case .notification:
            impactMed.impactOccurred()
            Analytics.logEvent("onboarding_notification_done", parameters: nil)
            dismissOnboarding()
        }
    }

    // MARK: - Helpers

    private func setSelection() {
        guard let tab = Tab(rawValue: onboardingTab) else { return }
        selection = tab
    }

    private func setupAppearance() {
        UIPageControl.appearance().currentPageIndicatorTintColor = UIColor(Constants.DALightBlue)
        UIPageControl.appearance().pageIndicatorTintColor = UIColor(Constants.DALightBlue).withAlphaComponent(0.2)
    }

    private func askNotificationPermission() {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .authorized, .provisional:
                // Already granted — just advance
                DispatchQueue.main.async {
                    appState.notificationEnabled = true
                    registerNotifications()
                    withAnimation { advance() }
                }
            case .notDetermined:
                // Ask for permission
                center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                    DispatchQueue.main.async {
                        appState.notificationEnabled = granted
                        if granted {
                            UIApplication.shared.registerForRemoteNotifications()
                            registerNotifications()
                        }
                        withAnimation { advance() }
                    }
                }
            default:
                // Denied or restricted — advance anyway, don't block onboarding
                DispatchQueue.main.async {
                    withAnimation { advance() }
                }
            }
        }
    }

    private func registerNotifications() {
        if appState.notificationEnabled {
            let defaultCategories: Set<DeclarationCategory> = [.faith, .confidence, .wisdom, .speaklife]
            appState.selectedNotificationCategories = defaultCategories.map { $0.rawValue }.joined(separator: ",")
            viewModel.save(defaultCategories)
            NotificationManager.shared.registerNotifications(
                count: appState.notificationCount,
                startTime: appState.startTimeIndex,
                endTime: appState.endTimeIndex,
                categories: defaultCategories
            )
            appState.lastNotificationSetDate = Date()
        }
    }

    private func dismissOnboarding() {
        // Stop onboarding music — main app will restart it via SpeakLifeApp
        AudioPlayerService.shared.stopMusic()
        withAnimation {
            appState.isOnboarded = true
            LifecycleNotificationService.shared.scheduleLifecycleNotifications()
            Analytics.logEvent("onBoardingFinished", parameters: nil)
        }
    }
}

struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView()
    }
}

// MARK: - Elegant Close Button (preserved from original)
public struct ElegantCloseButton: View {
    struct Configuration {
        let size: CGFloat
        let iconSize: CGFloat
        let shadowRadius: CGFloat
        let shadowOffset: CGSize
        let animationResponse: Double
        let animationDamping: Double

        static let `default` = Configuration(
            size: 36, iconSize: 16, shadowRadius: 8,
            shadowOffset: CGSize(width: 0, height: 4),
            animationResponse: 0.4, animationDamping: 0.6
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

    public var body: some View {
        Button(action: handleAction) { buttonContent }
            .buttonStyle(PlainButtonStyle())
            .scaleEffect(isVisible ? 1.0 : 0.8)
            .opacity(isVisible ? 1.0 : 0.0)
    }

    private var buttonContent: some View {
        ZStack { backgroundView; iconView }
            .frame(width: configuration.size, height: configuration.size)
            .shadow(color: Color.black.opacity(0.1), radius: configuration.shadowRadius,
                    x: configuration.shadowOffset.width, y: configuration.shadowOffset.height)
    }

    private var backgroundView: some View {
        Circle()
            .fill(LinearGradient(gradient: Gradient(colors: [Color.white.opacity(0.25), Color.white.opacity(0.1)]),
                                 startPoint: .topLeading, endPoint: .bottomTrailing))
            .background(Circle().fill(.ultraThinMaterial))
            .overlay(Circle().stroke(
                LinearGradient(gradient: Gradient(colors: [Color.white.opacity(0.3), Color.white.opacity(0.1)]),
                               startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1))
    }

    private var iconView: some View {
        Image(systemName: "xmark")
            .font(.system(size: configuration.iconSize, weight: .semibold, design: .rounded))
            .foregroundStyle(LinearGradient(gradient: Gradient(colors: [Color.white.opacity(0.9), Color.white.opacity(0.7)]),
                                            startPoint: .topLeading, endPoint: .bottomTrailing))
    }

    private func handleAction() {
        if enableHaptics { UIImpactFeedbackGenerator(style: .soft).impactOccurred() }
        withAnimation(.spring(response: configuration.animationResponse, dampingFraction: configuration.animationDamping)) {
            action()
        }
    }
}
