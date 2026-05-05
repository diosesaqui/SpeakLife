//
//  HomeView.swift
//  SpeakLife
//
//  Created by Riccardo Washington on 12/17/22.
//

import SwiftUI
import FacebookCore
import FirebaseAnalytics
let resources: [MusicResources] = [.sethpiano, .washed, .rainstorm, .everpresent]

struct MusicResources {
    let name: String
    let artist: String
    let type: String
   
    static let sethpiano = MusicResources(name: "sethpiano", artist: "", type: "mp3")
    static let washed = MusicResources(name: "washed", artist: "Brock Hewitt", type: "mp3")
    static let rainstorm = MusicResources(name: "rainstorm", artist: "Brock Hewitt", type: "mp3")
    static let everpresent = MusicResources(name: "everpresent", artist: "Brock Hewitt", type: "mp3")
}

class TabViewModel: ObservableObject {
    @Published var selectedTab: Int = 0 {
        didSet {
            trackTabNavigation(from: oldValue, to: selectedTab)
        }
    }

    func goToAudio() {
        selectedTab = 1
    }
    
//    func goToChecklist() {
//        selectedTab = 2  // Daily Checklist is at position 2
//    }

    func resetToHome() {
        selectedTab = 0  // Go to Declarations (main home view)
    }
    
    private func trackTabNavigation(from previousTab: Int, to newTab: Int) {
        let tabNames = [
            0: "declarations",
            1: "audio",
            2: "create_your_own",
            3: "bible",
            4: "profile"
        ]
        
        guard let fromName = tabNames[previousTab],
              let toName = tabNames[newTab],
              previousTab != newTab else { return }
        
        AnalyticsService.shared.trackNavigation(
            from: fromName,
            to: toName,
            method: .tab
        )
        
        Event.trackScreen("\(toName)_tab", metadata: [
            "previous_tab": fromName,
            "tab_index": newTab
        ])
    }
}

struct HomeView: View {
    
    @EnvironmentObject var declarationStore: DeclarationViewModel
    @EnvironmentObject var themeStore: ThemeViewModel
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var devotionalViewModel: DevotionalViewModel
    @EnvironmentObject var timerViewModel: TimerViewModel
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    @EnvironmentObject var viewModel: FacebookTrackingViewModel
    @EnvironmentObject var audioDeclarationViewModel: AudioDeclarationViewModel
    @EnvironmentObject var tabViewModel: TabViewModel
    @EnvironmentObject var streakViewModel: EnhancedStreakViewModel
    @Binding var isShowingLanding: Bool
    @Binding var showDailyBurstOnLaunch: Bool
    @Binding var showDailyStructuredDayOnLaunch: Bool
   
   
    @State var showGiftView = false
    @State private var isPresented = false
    @State var showSubscription = false
    @State private var showTriggeredPaywall = false
    @StateObject private var paywallTrigger = PaywallTriggerManager.shared
    @State private var showDeclarationPrompt = false
    @AppStorage("hasCreatedFirstDeclaration") private var hasCreatedFirstDeclaration = false
    @AppStorage("lastDeclarationPromptDate") private var lastDeclarationPromptDate: Double = 0
    // Personal Declaration migration — show existing users the new feature on update
    @AppStorage("pd_migrationPromptShown") private var pdMigrationPromptShown = false
    @State private var showPDMigrationSheet = false
    @State private var showStreakCelebration = false
    @State private var celebrationStreakCount = 0
    
    private let currentVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"

    let data = [true, false]
    var body: some View {
        Group {
            if isShowingLanding {
                LandingView()
            } else if appState.isOnboarded {
                homeView
                    .onAppear() {
                                showSubscription = subscriptionStore.showSubscription && !subscriptionStore.isPremium && !appState.firstOpen
                                audioDeclarationViewModel.fetchAudio(version: subscriptionStore.audioRemoteVersion)
                                declarationStore.setRemoteDeclarationVersion(version: subscriptionStore.remoteVersion)
                                // Re-select the correct category seeded during onboarding.
                                // DeclarationViewModel initialises before onboarding writes the
                                // survey goal word to UserDefaults, so we need to pick it up here.
                                declarationStore.choose(declarationStore.selectedCategory) { _ in }
                                Task {
                                    if devotionalViewModel.shouldFetchNewDevotional() {
                                            // Fetching devotional with current version
                                            await devotionalViewModel.fetchDevotional(remoteVersion: subscriptionStore.currentDevotionalVersion)
                                            devotionalViewModel.lastFetchDate = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .none)
                                        }
                                }
                               
                                
                                // Check if user should see declaration prompt
                              //  checkForDeclarationPrompt()
                            }
                            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                               
                                Task {
                                    // Always fetch remote config when coming from background
                                    await subscriptionStore.fetchRemoteConfig()
                                    
                                    // Update audio and declaration versions with new remote values
                                    audioDeclarationViewModel.fetchAudio(version: subscriptionStore.audioRemoteVersion)
                                    declarationStore.setRemoteDeclarationVersion(version: subscriptionStore.remoteVersion)
                                    
                                    // Fetch devotional if needed
                                    if devotionalViewModel.shouldFetchNewDevotional() {
                                        // Fetching devotional after config update
                                        await devotionalViewModel.fetchDevotional(remoteVersion: subscriptionStore.currentDevotionalVersion)
                                        devotionalViewModel.lastFetchDate = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .none)
                                    }
                                }
                            }
                            .sheet(isPresented: $appState.needEmail) {
                                EmailCaptureView()
                            }
                            .sheet(isPresented: $subscriptionStore.showEmailCaptureAfterPurchase) {
                                EmailCaptureView(source: "post_purchase")
                                    .environmentObject(appState)
                            }
                            .sheet(isPresented: $subscriptionStore.showEmailConfirmAfterPurchase) {
                                EmailConfirmationView(storedEmail: appState.email, source: "post_purchase")
                                    .environmentObject(appState)
                                    .environmentObject(subscriptionStore)
                            }
                            .sheet(isPresented: $showSubscription, content: {
                                OptimizedSubscriptionView {
                                    showSubscription = false
                                }
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .presentationDetents([.large])
                            })
                            .sheet(isPresented: $showTriggeredPaywall) {
                                OptimizedSubscriptionView {
                                    showTriggeredPaywall = false
                                    paywallTrigger.dismissPaywall()
                                }
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .presentationDetents([.large])
                            }
//                            .fullScreenCover(isPresented: $showDeclarationPrompt) {
//                                FirstDeclarationGuideView(
//                                    size: UIScreen.main.bounds.size,
//                                    action: {
//                                        hasCreatedFirstDeclaration = true
//                                        showDeclarationPrompt = false
//                                    },
//                                    isDismissible: true
//                                )
//                                .environmentObject(declarationStore)
//                                .environmentObject(subscriptionStore)
//                            }
                            .onReceive(NotificationCenter.default.publisher(for: .devotionalVersionUpdated)) { notification in
                                if let version = notification.userInfo?["version"] as? Int {
                                    // Received devotional version update notification
                                    Task {
                                        await devotionalViewModel.forceRefreshDevotional(remoteVersion: version)
                                        devotionalViewModel.lastFetchDate = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .none)
                                    }
                                }
                            }
                            .onReceive(NotificationCenter.default.publisher(for: .declarationsVersionUpdated)) { notification in
                                if let version = notification.userInfo?["version"] as? Int {
                                    declarationStore.setRemoteDeclarationVersion(version: version)
                                }
                            }
                            // Cold-launch fix: subscriptionStore.remoteVersion is 0 at view-appear
                            // because RC.fetchAndActivate is async. The original .onAppear above
                            // fires too early, and updateConfigValues doesn't post the live notification
                            // so DeclarationViewModel never picks up the version. Observing the
                            // @Published property here catches the moment RC actually returns.
                            .onChange(of: subscriptionStore.remoteVersion) { newVersion in
                                guard newVersion > 0 else { return }
                                declarationStore.setRemoteDeclarationVersion(version: newVersion)
                            }
                            .onChange(of: paywallTrigger.shouldShowPaywall) { newValue in
                                if newValue && !subscriptionStore.isPremium {
                                    showTriggeredPaywall = true
                                }
                            }
                            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("StreakCompleted"))) { _ in
                                // Show celebration animation globally when timer completes
                                celebrationStreakCount = timerViewModel.currentStreak
                                showStreakCelebration = true
                                // Global streak celebration triggered
                            }
                            // Notification-triggered burst (push notification tap) — unchanged
                            // Personal Declaration migration — shown once to existing users on update
                            .fullScreenCover(isPresented: $showPDMigrationSheet) {
                                GeometryReader { geo in
                                    PersonalDeclarationOnboardingView(
                                        viewModel: DIContainer.shared.makePersonalDeclarationViewModel(),
                                        size: geo.size
                                    ) { declaration in
                                        if declaration != nil {
                                            appState.hasPersonalDeclaration = true
                                        }
                                        showPDMigrationSheet = false
                                    }
                                    .environmentObject(appState)
                                }
                                .ignoresSafeArea()
                            }
                            .fullScreenCover(isPresented: $showDailyBurstOnLaunch) {
                                DailyDeclarationBurstView()
                                    .environmentObject(declarationStore)
                                    .environmentObject(themeStore)
                                    .environmentObject(timerViewModel)
                                    .environmentObject(streakViewModel)
                                    .environmentObject(subscriptionStore)
                            }
                            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("ShowDailyDeclarationBurst"))) { _ in
                                showDailyBurstOnLaunch = true
                            }
                            // Daily first-open: show Structured Day plan instead of raw burst.
                            // The burst task is inside the checklist — users reach it naturally.
                            .fullScreenCover(isPresented: $showDailyStructuredDayOnLaunch) {
                                ModernDailyChecklistView(viewModel: streakViewModel)
                                    .environmentObject(appState)
                                    .environmentObject(subscriptionStore)
                                    .environmentObject(devotionalViewModel)
                                    .environmentObject(audioDeclarationViewModel)
                                    .environmentObject(tabViewModel)
                            }
                  
                } else {
                    SurveyOnboardingView(size: UIScreen.main.bounds.size) {
                        withAnimation {
                            appState.isOnboarded = true
                            LifecycleNotificationService.shared.scheduleLifecycleNotifications()
                            Analytics.logEvent("onBoardingFinished", parameters: nil)
                        }
                    }
                    .ignoresSafeArea()
                    .onAppear {
                        viewModel.requestPermission { granted in
                            // ATT Permission handled
                        }
                    }
                }
            }
        
    }
    
    @ViewBuilder
    var homeView: some View {
        ZStack(alignment: .top) {
            TabView(selection: $tabViewModel.selectedTab) {
                declarationView
                audioView
               // bibleView
                // dailyChecklistView // Moved to DeclarationView
                createYourOwnView
                communityView
                profileView
                    
                }
                .hideTabBar(if: appState.showScreenshotLabel)
                .sheet(isPresented: $isPresented) {
                    WhatsNewBottomSheet(isPresented: $isPresented, version: currentVersion)
                        .presentationDetents([.medium])
                        .presentationDragIndicator(.visible)
                }
                .accentColor(Constants.DAMidBlue)
                .onAppear {
                    checkForNewVersion()
                    checkForPersonalDeclarationMigration()
                    if appState.firstOpen {
                        appState.firstOpen = false
                    }
                    UIScrollView.appearance().isScrollEnabled = true

                    // Email capture / confirmation for existing premium users.
                    // Fires once only per path — guarded by separate UserDefaults keys.
                    if subscriptionStore.isPremium {
                        let alreadyCaptured    = UserDefaults.standard.bool(forKey: "hasShownEmailCapture")
                        let alreadyConfirmed   = UserDefaults.standard.bool(forKey: "hasConfirmedPostPurchaseEmail")
                        let hasStoredEmail     = !appState.email.isEmpty

                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            if hasStoredEmail && !alreadyConfirmed {
                                // Has email locally → show confirmation popup to tag as post_purchase
                                subscriptionStore.showEmailConfirmAfterPurchase = true
                            } else if !hasStoredEmail && !alreadyCaptured {
                                // No email at all → show capture sheet
                                subscriptionStore.showEmailCaptureAfterPurchase = true
                            }
                        }
                    }
                }
                .background(Color.clear)
                .environment(\.colorScheme, .dark)
                .ignoresSafeArea()
            
            // Trial ending banner
            VStack {
                TrialEndingBanner()
                Spacer()
            }

            // Global streak celebration overlay
            if showStreakCelebration {
                ZStack {
                    Color.black.opacity(0.85)
                        .ignoresSafeArea()
                        .transition(.opacity)
                    
                    VStack(spacing: 30) {
                        StreakCompletionCelebrationView(streakCount: celebrationStreakCount)
                            .frame(width: 250, height: 250)
                        
                        VStack(spacing: 10) {
                            Text("🔥 Day \(celebrationStreakCount) Complete!")
                                .font(.title.bold())
                                .foregroundColor(.white)
                            
                            Text("Keep the fire burning!")
                                .font(.headline)
                                .foregroundColor(.white.opacity(0.9))
                        }
                        
                        Button(action: {
                            withAnimation(.easeOut(duration: 0.3)) {
                                showStreakCelebration = false
                            }
                        }) {
                            Text("Continue")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding(.horizontal, 40)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 25)
                                        .fill(LinearGradient(
                                            colors: [.orange, .red],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        ))
                                )
                        }
                    }
                    .transition(.scale.combined(with: .opacity))
                }
                .onAppear {
                    // Auto dismiss after 6 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 6) {
                        withAnimation(.easeOut(duration: 0.3)) {
                            showStreakCelebration = false
                        }
                    }
                }
            }
        }
    }
    
    var declarationView: some View {
        DeclarationView()
            .id(appState.rootViewId)
            .tag(0)
            .tabItem {
                Image(systemName: "quote.bubble.fill")
                    .renderingMode(.original)
                Text("Home")
                
            }
    }
    
    var testimonyView: some View {
        TestimonyFeedView()
            .tabItem {
                Image(systemName: "quote.bubble")
                    .renderingMode(.original)
            }
    }
    
    var audioView: some View {
        AudioDeclarationView()
            .tag(1)
            .tabItem {
                if #available(iOS 17, *) {
                    Image(systemName: "waveform")
                        .renderingMode(.original)
                    Text("Audio")
                } else {
                    Image(systemName: "waveform")
                        .renderingMode(.original)
                }
            }
            .edgesIgnoringSafeArea(.all)
    }
    
    var createYourOwnView: some View {
        CreateYourOwnView()
            .tag(3)
            .tabItem {
                Image(systemName: "plus.bubble.fill")
                    .renderingMode(.original)
                Text("Yours")
            }
    }
    
    var devotionalView: some View {
        DevotionalView(viewModel:devotionalViewModel)
            .tag(4)
            .tabItem {
                if #available(iOS 17, *) {
                    Image(systemName: "book.pages.fill")
                        .renderingMode(.original)
                } else {
                    Image(systemName: "book.fill")
                        .renderingMode(.original)
                }
            }
    }
    
    var dailyChecklistView: some View {
        ModernDailyChecklistView(viewModel: streakViewModel)
            .tag(2)
            .tabItem {
                Image(systemName: "checklist")
                    .renderingMode(.original)
            }
    }
    
//    var bibleView: some View {
//        BibleView()
//            .tag(2)
//            .tabItem {
//                Image(systemName: "book.closed.fill")
//                    .renderingMode(.original)
//            }
//    }
    
    var communityView: some View {
        PrayerWallView()
            .tag(4)
            .tabItem {
                if #available(iOS 17, *) {
                    Image(systemName: "hands.and.sparkles.fill")
                        .renderingMode(.original)
                    Text("Warrior Room")
                } else {
                    Image(systemName: "person.2.fill")
                        .renderingMode(.original)
                }
            }
    }
    
    var bibleView: some View {
        BibleView()
            .tag(4)
            .tabItem {
                if #available(iOS 17, *) {
                    Image(systemName: "book.closed.fill")
                        .renderingMode(.original)
                    Text("Bible")
                } else {
                    Image(systemName: "person.2.fill")
                        .renderingMode(.original)
                }
            }
    }

    var profileView: some View {
        ProfileView()
            .tag(5)
            .tabItem {
                Image(systemName: "line.3.horizontal")
                    .renderingMode(.original)
                Text("Profile")
            }
    }
    
    func presentGiftView() {
        if appState.showGiftViewCount <= 5 {
            showGiftView.toggle()
            appState.showGiftViewCount += 1
        }
    }
    
    private func checkForDeclarationPrompt() {
        // Only show for users who have completed onboarding
        guard appState.isOnboarded else { return }
        
        // Don't show if user has already created a declaration or marked as created
        guard !hasCreatedFirstDeclaration else { return }
        
        // Don't show if subscription screen is showing
        guard !showSubscription else { return }
        
        // Check if user has any user-created declarations
        let hasUserDeclarations = declarationStore.createOwn.count > 0
        
        if hasUserDeclarations {
            // User has declarations, don't show prompt again
            hasCreatedFirstDeclaration = true
            return
        }
        
        // Check if we've shown the prompt recently (wait 3 days between prompts)
        let currentTime = Date().timeIntervalSince1970
        let daysSinceLastPrompt = (currentTime - lastDeclarationPromptDate) / 86400
        
        guard daysSinceLastPrompt >= 3 else { return }
        
        // Delay showing the prompt to let the app fully load
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            // Double-check onboarding is still complete and no other modals are showing
            guard appState.isOnboarded && !showSubscription else { return }
            
            showDeclarationPrompt = true
            lastDeclarationPromptDate = currentTime
        }
    }
    
    private func checkForPersonalDeclarationMigration() {
        // Only for existing onboarded users who haven't set a personal declaration yet
        guard appState.isOnboarded else { return }
        guard !appState.hasPersonalDeclaration else { return }
        guard !pdMigrationPromptShown else { return }
        guard !showSubscription else { return }

        // Delay slightly so the main app finishes loading first
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            guard appState.isOnboarded && !showSubscription else { return }
            pdMigrationPromptShown = true
            showPDMigrationSheet = true
        }
    }

    private func checkForNewVersion() {
        let lastVersion = UserDefaults.standard.string(forKey: "lastVersion") ?? "0.0.0"
        if lastVersion != currentVersion && !appState.firstOpen {
            isPresented = true
            UserDefaults.standard.set(currentVersion, forKey: "lastVersion")
       }
    }
}


import AppTrackingTransparency
import AdSupport

class TrackingManager {
    static let shared = TrackingManager()

    func requestTrackingPermission(completion: @escaping (ATTrackingManager.AuthorizationStatus) -> Void) {
        ATTrackingManager.requestTrackingAuthorization { status in
            DispatchQueue.main.async {
                completion(status)
            }
        }
    }
}

class FacebookTrackingViewModel: ObservableObject {
    
    func requestPermission(completion: @escaping (Bool) -> Void) {
        let currentStatus = ATTrackingManager.trackingAuthorizationStatus
        
        if currentStatus == .notDetermined {
            // First time: show the ATT prompt
            TrackingManager.shared.requestTrackingPermission { status in
                switch status {
                case .authorized:
                    // User granted — enable Meta advertiser ID collection
                    Settings.shared.isAdvertiserIDCollectionEnabled = true
                    completion(true)
                case .notDetermined, .restricted, .denied:
                    Settings.shared.isAdvertiserIDCollectionEnabled = false
                    completion(false)
                @unknown default:
                    Settings.shared.isAdvertiserIDCollectionEnabled = false
                    completion(false)
                }
            }
        } else {
            // Returning user — ATT already resolved. Sync isAdvertiserIDCollectionEnabled
            // so Meta doesn't run in limited mode on every re-launch after prior approval.
            let isAuthorized = currentStatus == .authorized
            Settings.shared.isAdvertiserIDCollectionEnabled = isAuthorized
            completion(isAuthorized)
        }
    }
}
