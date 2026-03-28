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

    let impactMed = UIImpactFeedbackGenerator(style: .soft)

    var body: some View {
        GeometryReader { geometry in
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

                // SCREEN 3: Live Declaration Preview (declaration + why to declare)
                LiveDeclarationPreviewScreen(size: geometry.size) {
                    withAnimation { advance() }
                }
                .tag(Tab.livePreview)

                // SCREEN 4: Audio Feature — Faith comes by hearing
                AudioFeatureScreen(size: geometry.size) {
                    withAnimation { advance() }
                }
                .tag(Tab.audioFeature)

                // SCREEN 5: Daily Devotional Feature — God's love for you
                DailyDevotionalFeatureScreen(size: geometry.size) {
                    withAnimation { advance() }
                }
                .tag(Tab.devotionalFeature)

                // SCREEN 6: Warrior Room — community prayer & testimonies
                WarriorRoomFeatureScreen(size: geometry.size) {
                    withAnimation { advance() }
                }
                .tag(Tab.warriorRoom)

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
            selection = .audioFeature
            onboardingTab = selection.rawValue
            Analytics.logEvent("onboarding_preview_done", parameters: nil)

        case .audioFeature:
            impactMed.impactOccurred()
            selection = .devotionalFeature
            onboardingTab = selection.rawValue
            Analytics.logEvent("onboarding_audio_feature_done", parameters: nil)

        case .devotionalFeature:
            impactMed.impactOccurred()
            selection = .warriorRoom
            onboardingTab = selection.rawValue
            Analytics.logEvent("onboarding_devotional_feature_done", parameters: nil)

        case .warriorRoom:
            impactMed.impactOccurred()
            selection = .subscription
            onboardingTab = selection.rawValue
            Analytics.logEvent("onboarding_warrior_room_done", parameters: nil)

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
