//
//  HomeView.swift
//  SpeakLife
//
//  Created by Riccardo Washington on 12/17/22.
//

import SwiftUI
import FacebookCore
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
            2: "bible",
            3: "create_your_own",
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
   
   
    @State var showGiftView = false
    @State private var isPresented = false
    @State var showSubscription = false
    @State private var showTriggeredPaywall = false
    @StateObject private var paywallTrigger = PaywallTriggerManager.shared
    @State private var showDeclarationPrompt = false
    @AppStorage("hasCreatedFirstDeclaration") private var hasCreatedFirstDeclaration = false
    @AppStorage("lastDeclarationPromptDate") private var lastDeclarationPromptDate: Double = 0
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
                                Task {
                                    if devotionalViewModel.shouldFetchNewDevotional() {
                                            print("HomeView: Fetching devotional with version: \(subscriptionStore.currentDevotionalVersion)")
                                            await devotionalViewModel.fetchDevotional(remoteVersion: subscriptionStore.currentDevotionalVersion)
                                            devotionalViewModel.lastFetchDate = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .none)
                                        }
                                }
                                if appState.firstOpen {
                                    appState.firstOpen = false
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
                                        print("HomeView: Fetching devotional after config update with version: \(subscriptionStore.currentDevotionalVersion)")
                                        await devotionalViewModel.fetchDevotional(remoteVersion: subscriptionStore.currentDevotionalVersion)
                                        devotionalViewModel.lastFetchDate = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .none)
                                    }
                                }
                            }
                            .sheet(isPresented: $appState.needEmail) {
                                EmailCaptureView()
                            }
                            .sheet(isPresented: $showSubscription, content: {
                                GeometryReader { proxy in
                                    OptimizedSubscriptionView {
                                        showSubscription = false
                                    }
                                    .frame(height:  UIScreen.main.bounds.height * 0.9)
                                }
                            })
                            .sheet(isPresented: $showTriggeredPaywall) {
                                GeometryReader { proxy in
                                    OptimizedSubscriptionView {
                                        showTriggeredPaywall = false
                                        paywallTrigger.dismissPaywall()
                                    }
                                    .frame(height:  UIScreen.main.bounds.height * 0.9)
                                }
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
                                    print("📖 HomeView: Received devotional version update notification: v\(version)")
                                    Task {
                                        await devotionalViewModel.forceRefreshDevotional(remoteVersion: version)
                                        devotionalViewModel.lastFetchDate = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .none)
                                    }
                                }
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
                                print("🎉 Global streak celebration triggered for day \(celebrationStreakCount)")
                            }
                  
                } else {
                    // Choose between original and enhanced onboarding based on flag
                    if appState.useEnhancedOnboarding {
                        EnhancedOnboardingViewRefactored()
                            .onAppear {
                                viewModel.requestPermission { granted in
                                    // Handle permission result if needed
                                    print("ATT Permission granted: \(granted)")
                                }
                            }
                    } else {
                        OnboardingView()
                            .onAppear {
                                viewModel.requestPermission { granted in
                                    // Handle permission result if needed
                                    print("ATT Permission granted: \(granted)")
                                }
                            }
                    }
                }
            }
        
    }
    
    @ViewBuilder
    var homeView: some View {
        ZStack {
            TabView(selection: $tabViewModel.selectedTab) {
                declarationView
                audioView
               // bibleView
                // dailyChecklistView // Moved to DeclarationView
                createYourOwnView
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
                    UIScrollView.appearance().isScrollEnabled = true
                }
                .background(Color.clear)
                .environment(\.colorScheme, .dark)
                .ignoresSafeArea()
            
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
    
    var bibleView: some View {
        BibleView()
            .tag(2)
            .tabItem {
                Image(systemName: "book.closed.fill")
                    .renderingMode(.original)
            }
    }
    
    var profileView: some View {
        ProfileView()
            .tag(4)
            .tabItem {
                Image(systemName: "line.3.horizontal")
                    .renderingMode(.original)
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
    
    private func checkForNewVersion() {
        let lastVersion = UserDefaults.standard.string(forKey: "lastVersion") ?? "0.0.0"
        if lastVersion != currentVersion {
            isPresented = true
            UserDefaults.standard.set(currentVersion, forKey: "lastVersion")
       }
        if currentVersion == "3.0.42" {
            declarationStore.cleanUpSelectedCategories { selectedCategories in
                let categoryString = selectedCategories.map { $0.name }.joined(separator: ",")
                appState.selectedNotificationCategories = categoryString
                declarationStore.save(selectedCategories)
            }
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
        
        if ATTrackingManager.trackingAuthorizationStatus == .notDetermined {
            TrackingManager.shared.requestTrackingPermission { status in
                switch status {
                case .notDetermined:
                    Settings.shared.isAdvertiserIDCollectionEnabled = false
                    completion(false)
                case .restricted:
                    Settings.shared.isAdvertiserIDCollectionEnabled = false
                    completion(false)
                case .denied:
                    Settings.shared.isAdvertiserIDCollectionEnabled = false
                    completion(false)
                case .authorized:
                    Settings.shared.isAdvertiserIDCollectionEnabled = true
                    completion(true)
                @unknown default: break
                }
            }
        }
    }
}
