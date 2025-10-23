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
                
               
                IntroTipScene(
                    title: "Walk in Your Authority in Christ",
                    bodyText: """
                    Jesus gave you power to trample on serpents and scorpions, and over all the power of the enemy. Nothing shall hurt you.

                    Every feature is designed to build your faith, declare His promises, and walk in the authority Christ purchased for you.

                    Rise up, believer. Your enemy is defeated. Your victory is secured in Jesus.
                    """,
                    subtext: "",
                    ctaText: "Walk in Victory →",
                    showTestimonials: false,
                    isScholarship: false,
                    size: geometry.size)
                {
                    advance()
                }
                .tag(Tab.transformedLife)
                
                AudioDevotionalsTutorial(size: geometry.size) {
                    advance()
                }
                .tag(Tab.audioSermons)
                
                AffirmationsTutorial(size: geometry.size) {
                    advance()
                }
                .tag(Tab.affirmations)
                
                CreateYourOwnTutorial(size: geometry.size) {
                    advance()
                }
                .tag(Tab.createYourOwn)
                
                DevotionalsTutorial(size: geometry.size) {
                    advance()
                }
                .tag(Tab.devotionals)

                NotificationOnboarding(size: geometry.size) {
                    withAnimation {
                        askNotificationPermission()
                    }
                }
                .tag(Tab.notification)
                
                ImprovementScene(size: geometry.size, viewModel: improvementViewModel) {
                    withAnimation {
                        advance()
                    }
                }
                .tag(Tab.improvement)
                
                
                RatingView(size: geometry.size) {
                    advance()
                } .tag(Tab.review)

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
                    impactMed.impactOccurred()
                    selection = .audioSermons
                    onboardingTab = selection.rawValue
                    Analytics.logEvent("TransformedLifeScreenDone", parameters: nil)
                    
                case .audioSermons:
                    impactMed.impactOccurred()
                    selection = .affirmations
                    onboardingTab = selection.rawValue
                    Analytics.logEvent("AudioSermonsScreenDone", parameters: nil)
                    
                case .affirmations:
                    impactMed.impactOccurred()
                    selection = .createYourOwn
                    onboardingTab = selection.rawValue
                    Analytics.logEvent("AffirmationsScreenDone", parameters: nil)
                    
                case .createYourOwn:
                    impactMed.impactOccurred()
                    selection = .devotionals
                    onboardingTab = selection.rawValue
                    Analytics.logEvent("CreateYourOwnScreenDone", parameters: nil)
                    
                case .devotionals:
                    impactMed.impactOccurred()
                    selection = .notification
                    onboardingTab = selection.rawValue
                    Analytics.logEvent("DevotionalsScreenDone", parameters: nil)
                    
                case .notification:
                    impactMed.impactOccurred()
                    selection = .improvement
                    onboardingTab = selection.rawValue
                    Analytics.logEvent("NotificationScreenDone", parameters: nil)
                    
                case .improvement:
                    impactMed.impactOccurred()
                    selection = .review
                    onboardingTab = selection.rawValue
                    decodeCategories(improvementViewModel.selectedExperiences)
                    Analytics.logEvent("ImprovementScreenDone", parameters: nil)
                    
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

