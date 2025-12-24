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
    
    @State var selection: Tab = .hook
    @StateObject var improvementViewModel = ImprovementViewModel()
    @AppStorage("onboardingTab") var onboardingTab = Tab.hook.rawValue
    @State private var isTextVisible = false
   
    let impactMed = UIImpactFeedbackGenerator(style: .soft)
    
    var body: some View {
        GeometryReader { geometry in
            TabView(selection: $selection) {
                
                // STEP 1: Hook Screen
                HookScene(size: geometry.size) {
                    withAnimation {
                        advance()
                    }
                }
                .tag(Tab.hook)
                
                // Category selection screen
                CombinedPersonalizationScene(
                    size: geometry.size,
                    viewModel: improvementViewModel
                ) {
                    withAnimation {
                        advance()
                    }
                }
                .tag(Tab.transformedLife)
                
                // STEP 2: Personalization Summary Screen
                PersonalizationSummaryScene(
                    size: geometry.size,
                    selectedCategories: improvementViewModel.selectedExperiences
                ) {
                    withAnimation {
                        advance()
                    }
                }
                .tag(Tab.personalizationSummary)
                
                NotificationOnboarding(size: geometry.size) {
                    withAnimation {
                        askNotificationPermission()
                    }
                }
                .tag(Tab.notification)

                subscriptionScene(size: geometry.size)
                    .tag(Tab.subscription)
                
                
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
                case .hook:
                    impactMed.impactOccurred()
                    selection = .transformedLife
                    onboardingTab = selection.rawValue
                    Analytics.logEvent("HookScreenDone", parameters: nil)
                    
                case .transformedLife:
                    // Category selection completed
                    impactMed.impactOccurred()
                    selection = .personalizationSummary
                    onboardingTab = selection.rawValue
                    decodeCategories(improvementViewModel.selectedExperiences)
                    Analytics.logEvent("CombinedPersonalizationDone", parameters: [
                        "categories_count": improvementViewModel.selectedExperiences.count
                    ])
                    
                case .personalizationSummary:
                    impactMed.impactOccurred()
                    selection = .notification
                    onboardingTab = selection.rawValue
                    Analytics.logEvent("PersonalizationSummaryDone", parameters: nil)
                    
                case .improvement:
                    // This case won't be used with new flow
                    impactMed.impactOccurred()
                    selection = .notification
                    onboardingTab = selection.rawValue
                    decodeCategories(improvementViewModel.selectedExperiences)
                    Analytics.logEvent("ImprovementScreenDone", parameters: nil)
                    
                    
                case .notification:
                    impactMed.impactOccurred()
                    selection = .subscription
                    onboardingTab = selection.rawValue
                    Analytics.logEvent("NotificationScreenDone", parameters: nil)
                    
                case .review:
                    impactMed.impactOccurred()
                    selection = .subscription
                    onboardingTab = selection.rawValue
                    Analytics.logEvent("ReviewScreenDone", parameters: nil)
                    
                case .subscription:
                    Analytics.logEvent("SubscriptionScreenDone", parameters: nil)
                    impactMed.impactOccurred()
                    dismissOnboarding()
        }
    }
    
    private func decodeCategories(_ categories: [DeclarationCategory]) {
        let uniqueCategories = Set(categories)
        let categoriesString = uniqueCategories.map { $0.rawValue }.joined(separator: ",")
        appState.selectedNotificationCategories = categoriesString
        viewModel.save(uniqueCategories)
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
            Analytics.logEvent(Event.onBoardingFinished, parameters: nil)
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


struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView()
    }
}

// MARK: - Elegant Close Button Component
private struct ElegantCloseButton: View {
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
    var body: some View {
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

