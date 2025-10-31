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
    
    @State var selection: Tab = .transformedLife
    @StateObject var improvementViewModel = ImprovementViewModel()
    @AppStorage("onboardingTab") var onboardingTab = Tab.transformedLife.rawValue
    @State private var isTextVisible = false
   
    let impactMed = UIImpactFeedbackGenerator(style: .soft)
    
    var body: some View {
        GeometryReader { geometry in
            TabView(selection: $selection) {
                
                // OPTION 1: Use new combined scene (recommended)
                CombinedPersonalizationScene(
                    size: geometry.size,
                    viewModel: improvementViewModel
                ) {
                    withAnimation {
                        advance()
                    }
                }
                .tag(Tab.transformedLife)
                
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
                    Button(action: advance) {
                        Image(systemName: "xmark.circle.fill")
                            .resizable()
                            .frame(width: 30, height: 30)
                            .foregroundColor(.white)
                            .opacity(isTextVisible ? 1 : 0)
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
        DispatchQueue.main.asyncAfter(deadline: .now()) {
            withAnimation {
                isTextVisible = true
            }
        }
    }
    
    // MARK: - Private methods
    
    private func advance() {
        switch selection {
                case .transformedLife:
                    // Now combines both intro and improvement
                    impactMed.impactOccurred()
                    selection = .notification  // Skip directly to notification
                    onboardingTab = selection.rawValue
                    decodeCategories(improvementViewModel.selectedExperiences)
                    Analytics.logEvent("CombinedPersonalizationDone", parameters: [
                        "categories_count": improvementViewModel.selectedExperiences.count
                    ])
                    
                case .improvement:
                    // This case won't be used with combined scene
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

