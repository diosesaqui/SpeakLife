//
//  OnboardingView.swift
//  Dios Es Aqui
//
//  Created by Riccardo Washington on 2/7/22.
//

import SwiftUI
import FirebaseAnalytics
import StoreKit

let onboardingBGImage2 = "pinkHueMountain"

import SwiftUI

struct OnboardingView: View  {
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var viewModel: DeclarationViewModel
    @EnvironmentObject var streakViewModel: StreakViewModel
    @Environment(\.colorScheme) var colorScheme
    
    @State var selection: Tab = .transformedLife
    @State var showLastChanceAlert = false
    @State var isDonePersonalization = false
    @StateObject var improvementViewModel = ImprovementViewModel()
    @AppStorage("onboardingTab") var onboardingTab = Tab.transformedLife.rawValue
    @State private var isTextVisible = false
    @State var valueProps: [Feature] = []
   
    let impactMed = UIImpactFeedbackGenerator(style: .soft)
    
    @ViewBuilder
    func loadingView(geometry: GeometryProxy) -> some View {
        if isDonePersonalization {
            
        } else {
            PersonalizationLoadingView(size: geometry.size, callBack: advance)
                .tag(Tab.loading)
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            TabView(selection: $selection) {
                
               
                IntroTipScene(
                    title: "God’s Promises for Every Battle",
                    bodyText: """
                    Life brings battles — but God already gave you promises to win them.

                    Every day, thousands open SpeakLife to declare His Word over fear, anxiety, and doubt.

                    Peace takes over. Faith rises. Purpose awakens. Breakthroughs begin.
                    """,
                    subtext: "",
                    ctaText: "Start My Breakthrough →",
                    showTestimonials: false,
                    isScholarship: false,
                    size: geometry.size)
                {
                    advance()
                }
                .tag(Tab.transformedLife)



                IntroTipScene(
                    title: "Step Into the Victory Already Won",
                    bodyText: """
                    You weren’t made to live defeated. Jesus already won the battle.

                    Every promise is already yours.

                    Speak it. Believe it. Receive it.
                    """,
                    subtext: "",
                    ctaText: "Step Into Victory ➔",
                    showTestimonials: false,
                    isScholarship: false,
                    size: geometry.size)
                {
                    advance()
                }
                .tag(Tab.victorious)

                IntroTipScene(
                    title: "Planted to Prosper Through Every Storm",
                    bodyText: """
                    Life's storms come to everyone — but here's the revelation:
                    
                    Those planted in God's Word don't just survive, they thrive.
                    
                    While others are shaken, you'll stand firm. While others fear, you'll flourish.
                    
                    His promises are your roots. His truth is your anchor.
                    """,
                    subtext: "",
                    ctaText: "Get Rooted in His Word ➔",
                    showTestimonials: false,
                    isScholarship: false,
                    size: geometry.size)
                {
                    advance()
                }
                .tag(Tab.seedHarvest)
                 
                
                ImprovementScene(size: geometry.size, viewModel: improvementViewModel) {
                    withAnimation {
                        advance()
                    }
                }
                .tag(Tab.improvement)
                
                DemoExperienceView(size: geometry.size) {
                    withAnimation {
                        advance()
                    }
                }
                .tag(Tab.demoExperience)
//                Job lost. Health issues. World in chaos. I had 91 days of savings left.
//                
//                So I did one thing differently: Every morning, I spoke Psalm 91 and Prosperity verses until I believed it.
//                
//                Day 7: Fear broke. Day 21: Million-dollar ideas came. Day 45: Opportunities appeared from nowhere. Day 91: Total healing, new income streams, unshakeable peace.
//                
//                The secret? God's Word doesn't just comfort you — it literally reprograms your reality.
//                
//                I built SpeakLife because this revelation shouldn't be hidden. 50,000+ are already experiencing their turnaround.
//                
//                Your breakthrough is 5 minutes away. Same words that changed my life are waiting for you.
                IntroTipScene(
                    title: "From Rock Bottom to Breakthrough: My Story",
                    bodyText: """
                    When everything collapsed — job gone, fear everywhere, health failing with Bell's palsy — I put all my faith into God's promises.
                    
                    Back against the wall, only God could save me.
                    
                    First came peace in chaos. Then divine ideas. Then supernatural opporunities. Finally, complete healing.
                    
                    I didn't just bounce back — I conquered.
                    
                    What worked for me will work for you. Same God. Same promises. Your turn.
                    """,
                    subtext: "Franchiz Washington - Founder",
                    ctaText: "Start My Turnaround Now →",
                    showTestimonials: false,
                    isScholarship: false,
                    size: geometry.size)
                {
                    advance()
                }
                .tag(Tab.life)
                
                RatingView(size: geometry.size) {
                    advance()
                } .tag(Tab.review)

                subscriptionScene(size: geometry.size)
                    .tag(Tab.subscription)
                
                
                NotificationOnboarding(size: geometry.size) {
                    withAnimation {
                        askNotificationPermission()
                    }
                }
                .tag(Tab.notification)
                
               
                
                
                

                
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

    
    private var foregroundColor: Color {
        colorScheme == .dark ? .white : Constants.DEABlack
    }
    
    private func setSelection() {
        guard let tab = Tab(rawValue: onboardingTab) else { return }
        selection = tab
    }
    
    // MARK: - Private Views
    
    
    private func categoryScene() -> some View {
        Text("category")
    }
    
    private func subscriptionScene(size: CGSize) -> some View  {
        
        ZStack {
            OptimizedSubscriptionView() { //}(size: size) {
                //withAnimation {
                    advance()
              //  }
            }.frame(height: UIScreen.main.bounds.height * 0.96)
            
            VStack  {
                HStack  {
                    Button(action:  advance) {
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
    
    
    func showAlertIfNeededAndDismissOnboarding() {
        if !subscriptionStore.isPremium {
            showLastChanceAlert = true
        } else {
            dismissOnboarding()
        }
    }
    
    // MARK: - Private methods
    
    private func advance() {
       // DispatchQueue.main.async {
           
           // withAnimation {
                switch selection {
                case .personalization:
                    impactMed.impactOccurred()
                    selection = .name
                    onboardingTab = selection.rawValue
                    Analytics.logEvent("WelcomeScreenDone", parameters: nil)
                case .name:
                    impactMed.impactOccurred()
                    selection = .improvement//appState.onBoardingTest ? .age : .habit
                    onboardingTab = selection.rawValue
                    Analytics.logEvent("NameScreenDone", parameters: nil)
                case .age:
                    impactMed.impactOccurred()
                    selection = .improvement
                    onboardingTab = selection.rawValue
                    Analytics.logEvent("AgeScreenDone", parameters: nil)
                case .gender:
                    impactMed.impactOccurred()
                    selection = appState.onBoardingTest ? .improvement : .habit
                    onboardingTab = selection.rawValue
                    Analytics.logEvent("GenderScreenDone", parameters: nil)
                case .habit:
                    selection = .improvement
                    onboardingTab = selection.rawValue
                    Analytics.logEvent("HabitScreenDone", parameters: nil)
                case .improvement:
                    impactMed.impactOccurred()
                    selection = .demoExperience
                    onboardingTab = selection.rawValue
                    
                    decodeCategories(improvementViewModel.selectedExperiences)
                   // valueProps = createValueProps(categories: improvementViewModel.selectedExperiences)
                    Analytics.logEvent("ImprovementScreenDone", parameters: nil)
                case .demoExperience:
                    impactMed.impactOccurred()
                    selection = .life
                    onboardingTab = selection.rawValue
                    Analytics.logEvent("DemoExperienceScreenDone", parameters: nil)
                case .intro:
                    impactMed.impactOccurred()
                    selection = .foe
                    onboardingTab = selection.rawValue
                    Analytics.logEvent("IntroScreenDone", parameters: nil)
                    
                case .foe:
                    impactMed.impactOccurred()
                    selection = .life
                    onboardingTab = selection.rawValue
                    Analytics.logEvent("IntroFoeDone", parameters: nil)
                    
                case .life:
                    impactMed.impactOccurred()
                    selection = .review
                    onboardingTab = selection.rawValue
                    Analytics.logEvent("IntroLifeDone", parameters: nil)
                case .tip:
                    impactMed.impactOccurred()
                    selection = .notification
                    onboardingTab = selection.rawValue
                    Analytics.logEvent("IntroTipScreenDone", parameters: nil)
                case .mindset:
                    impactMed.impactOccurred()
                    selection = .hearingFaith
                    onboardingTab = selection.rawValue
                    Analytics.logEvent("IntroMindsetScreenDone", parameters: nil)
                case .benefits:
                    selection = .notification
                    onboardingTab = selection.rawValue
                    Analytics.logEvent("BenefitScreenDone", parameters: nil)
                case .notification:
                    impactMed.impactOccurred()
                        dismissOnboarding()
                    Analytics.logEvent("NotificationScreenDone", parameters: nil)
                case .useCase:
                    selection = .unshakeableFaith
                    onboardingTab = selection.rawValue
                    
                case .helpGrow:
                    selection = .subscription
                    onboardingTab = selection.rawValue
                case .subscription:
                    Analytics.logEvent("SubscriptionScreenDone", parameters: nil)
                    impactMed.impactOccurred()
                    selection = .notification
                    onboardingTab = selection.rawValue
                    Analytics.logEvent("TransformedLifeScreenDone", parameters: nil)
                case .scholarship:
                    dismissOnboarding()
                case .widgets:
                    impactMed.impactOccurred()
                    selection = .notification
                    onboardingTab = selection.rawValue
                    Analytics.logEvent("WidgetsScreenDone", parameters: nil)
    
                case .loading:
                    Analytics.logEvent("LoadingScreenDone", parameters: nil)
                    selection = .subscription
                    isDonePersonalization = true
                case .discount:
                    Analytics.logEvent("Discount", parameters: nil)
                    if subscriptionStore.showSubscription && !subscriptionStore.showSubscriptionFirst {
                        selection = .subscription
                        onboardingTab = selection.rawValue
                    } else {
                        dismissOnboarding()
                    }
                case .transformedLife:
                    impactMed.impactOccurred()
                    selection = .victorious
                    onboardingTab = selection.rawValue
                    Analytics.logEvent("TransformedLifeScreenDone", parameters: nil)
                case .likeJesus:
                    impactMed.impactOccurred()
                    selection = .improvement
                    onboardingTab = selection.rawValue
                    Analytics.logEvent("LikeJesusScreenDone", parameters: nil)
                case .liveVictorious:
                    impactMed.impactOccurred()
                    selection = .rooted
                    onboardingTab = selection.rawValue
                    Analytics.logEvent("LiveVictoriousScreenDone", parameters: nil)
                case .unshakeableFaith:
                    impactMed.impactOccurred()
                    selection = .mindset
                    onboardingTab = selection.rawValue
                    Analytics.logEvent("UnshakeableFaithScreenDone", parameters: nil)
                case .confidence:
                    impactMed.impactOccurred()
                    selection = .liveVictorious
                    onboardingTab = selection.rawValue
                    Analytics.logEvent("ConfidenceScreenDone", parameters: nil)
                   
                case .review:
                    impactMed.impactOccurred()
                    selection = .subscription
                    onboardingTab = selection.rawValue
                    Analytics.logEvent("ReviewScreenDone", parameters: nil)
                   
                case .rooted:
                    impactMed.impactOccurred()
                    selection = .victorious
                    onboardingTab = selection.rawValue
                    Analytics.logEvent("rootedScreenDone", parameters: nil)
                case .victorious:
                    impactMed.impactOccurred()
                    selection = .seedHarvest
                    onboardingTab = selection.rawValue
                    Analytics.logEvent("victoriousScreenDone", parameters: nil)
                case .riverOfLife:
                    impactMed.impactOccurred()
                    selection = .seedHarvest
                    onboardingTab = selection.rawValue
                    Analytics.logEvent("riverOfLifeScreenDone", parameters: nil)
                case .dailyBread:
                    impactMed.impactOccurred()
                    selection = .seedHarvest
                    onboardingTab = selection.rawValue
                    Analytics.logEvent("dailyBreadScreenDone", parameters: nil)
                case .seedHarvest:
                    impactMed.impactOccurred()
                    selection = .improvement
                    onboardingTab = selection.rawValue
                    Analytics.logEvent("seedHarvestScreenDone", parameters: nil)
                case .hearingFaith:
                    impactMed.impactOccurred()
                    selection = .victorious
                    onboardingTab = selection.rawValue
                    Analytics.logEvent("seedHarvestScreenDone", parameters: nil)
                case .spiritualFood:
                    impactMed.impactOccurred()
                    selection = .victorious
                    onboardingTab = selection.rawValue
                    Analytics.logEvent("spiritualFoodScreenDone", parameters: nil)
                }
       // }
    }
    
    private func decodeCategories(_ categories: [DeclarationCategory]) {
        var temp = Set<DeclarationCategory>()
        for category in categories {
                temp.insert(category)
        }

        print(temp, "RWRW temp categories")
        let categories = temp.map { $0.rawValue }.joined(separator: ",")
        appState.selectedNotificationCategories = categories
        print(appState.selectedNotificationCategories, "RWRW notification categories")
        viewModel.save(temp)

    }
    
    
    private func askNotificationPermission()  {
        
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            guard (settings.authorizationStatus == .authorized) ||
                    (settings.authorizationStatus == .provisional) else {
                center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                    
                    DispatchQueue.main.async {
                        if let _ = error {
                            appState.notificationEnabled = false
                            //return
                            // Handle the error here.
                        }
                        
                        if granted {
                            DispatchQueue.main.async {
                                UIApplication.shared.registerForRemoteNotifications()
                            }
                            appState.notificationEnabled = true
                            registerNotifications()
                           // NotificationManager.shared.prepareDailyStreakNotification(with: appState.userName, streak: streakViewModel.currentStreak, hasCurrentStreak: streakViewModel.hasCurrentStreak)
                            
                        } else {
                            appState.notificationEnabled = false
                            // return
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
    
    private func moveToDiscount() {
        dismissOnboarding()
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

