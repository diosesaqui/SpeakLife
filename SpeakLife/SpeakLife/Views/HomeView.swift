//
//  HomeView.swift
//  SpeakLife
//
//  Created by Riccardo Washington on 12/17/22.
//

import SwiftUI
import FacebookCore
import FirebaseAnalytics
import UserNotifications
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

    /// Tag of the declaration feed. It's the "Speak" tab (2) when the checklist
    /// owns home, but the home tab (0) when the checklist kill switch is off.
    /// HomeView sets this from the Remote Config flag.
    var feedTabTag: Int = 2

    func goToAudio() {
        selectedTab = 1
    }

    func goToChecklist() {
        selectedTab = 0  // "Today" checklist is the home tab (when enabled)
    }

    func goToDeclarations() {
        selectedTab = feedTabTag  // Swipeable declaration feed
    }

    func resetToHome() {
        selectedTab = 0  // Home tab — checklist when enabled, feed when not
    }

    private func trackTabNavigation(from previousTab: Int, to newTab: Int) {
        // Keys are the actual .tag() values used as selectedTab (not positions).
        let tabNames = [
            0: "today_checklist",
            1: "audio",
            2: "declarations",
            4: "bible_chat",
            5: "profile"
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
    /// Observed here only to route an App Intent launch to the Today tab, which
    /// owns the drill. See the `onChange` on the TabView.
    @ObservedObject private var takeItCaptiveService = TakeItCaptiveService.shared
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
    @State private var anniversaryMilestone: PremiumAnniversaryMilestone?
    @State private var yearInReviewStats: YearInReviewStats?
    // The Inbox, presented from the remote-message reader's
    // "See All SpeakLife Messages" CTA.
    @State private var showSpeakLifeMessages = false

    private let currentVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"

    private static let streakReviewMilestones: Set<Int> = [3, 7, 14, 30, 60, 100, 365]

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
                                // Skip when a notification tap is mid-flight — setDeclaration is
                                // already loading the category and pinning the tapped declaration
                                // at index 0; re-calling choose() here re-shuffles and clobbers it.
                                if !declarationStore.isProcessingNotification {
                                    declarationStore.choose(declarationStore.selectedCategory) { _ in }
                                }
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
                            // RC's premium entitlement (and its originalPurchaseDate) is fetched
                            // async on cold start; the .onAppear check above may run before the
                            // value lands. Re-run once RC populates it.
                            .onChange(of: subscriptionStore.premiumOriginalPurchaseDate) { _ in
                                checkForPremiumAnniversary()
                            }
                            .onChange(of: paywallTrigger.shouldShowPaywall) { newValue in
                                if newValue && !subscriptionStore.isPremium {
                                    showTriggeredPaywall = true
                                }
                            }
                            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("StreakCompleted"))) { _ in
                                let streak = timerViewModel.currentStreak
                                celebrationStreakCount = streak
                                showStreakCelebration = true

                                // Let the celebration animation breathe before the SK
                                // prompt lands on top of it.
                                if Self.streakReviewMilestones.contains(streak) {
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                                        appState.requestReviewIfEligible(trigger: .streakMilestone(streak))
                                    }
                                }
                            }
                            // Notification-triggered burst (push notification tap) — unchanged
                            // Personal Declaration migration — shown once to existing users on update
                            .fullScreenCover(isPresented: $showPDMigrationSheet) {
                                GeometryReader { geo in
                                    PersonalDeclarationOnboardingView(
                                        viewModel: DIContainer.shared.makePersonalDeclarationViewModel(),
                                        size: geo.size,
                                        flow: "migration"
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
                            // The Daily Burst is presented by DeclarationView's own
                            // fullScreenCover (the "fully wired" one). Listening for
                            // "ShowDailyDeclarationBurst" here too caused BOTH covers to
                            // fire on a single notification, and SwiftUI can only present
                            // one cover per context — so the burst appeared and was
                            // immediately dismissed, forcing the user to trigger it twice.
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
                            .fullScreenCover(item: $anniversaryMilestone) { milestone in
                                PremiumAnniversaryView(milestone: milestone)
                                    .environmentObject(subscriptionStore)
                                    .environmentObject(appState)
                            }
                            .fullScreenCover(item: $yearInReviewStats) { stats in
                                // Snapshot premium status into the view so a
                                // late StoreKit hydration can't mutate the
                                // slide list mid-presentation.
                                YearInReviewView(
                                    stats: stats,
                                    includesPremiumExtras: subscriptionStore.isPremium
                                )
                                .environmentObject(subscriptionStore)
                            }

                } else {
                    // Onboarding A/B: quiz | product | identity | outcomes | warfare
                    // | promises | closer, selected by Remote Config `onboardingVariant`. Hold
                    // the first render until Remote Config has activated so the LOCKED
                    // arm is the assigned experiment arm, not the in-app default — the
                    // race that put every fresh install into the baseline arm. Bounded
                    // by SubscriptionStore's readiness timeout so it can never hang.
                    // ATT is requested once from SpeakLifeApp (delayed until active);
                    // requesting it again here fired too early and dropped the prompt.
                    if subscriptionStore.remoteConfigReady {
                        onboardingFlow
                            .onAppear { logOnboardingStarted() }
                    } else {
                        onboardingLoadingView
                    }
                }
            }
            // iCloud restore: a returning user installing on a new device has
            // already been through onboarding — the synced "onboarded" flag
            // arrives with the first CloudKit import shortly after launch.
            // The moment it lands, skip onboarding and drop them straight
            // into their restored app. Attached at the container level so it
            // is live during the landing window and the onboarding branch.
            // Deliberately does NOT fire onboarding_finished, so the
            // onboarding A/B conversion funnel is not polluted with restores.
            .onReceive(NotificationCenter.default.publisher(for: SyncedSettingsStore.settingsDidChange)) { notification in
                guard !appState.isOnboarded,
                      let keys = notification.userInfo?["keys"] as? Set<String>,
                      keys.contains("onboarded"),
                      UserDefaults.standard.bool(forKey: "onboarded") else { return }
                AnalyticsService.shared.track("onboarding_bypassed_icloud_restore", parameters: [
                    "variant": subscriptionStore.onboardingVariantName
                ])
                withAnimation {
                    appState.isOnboarded = true
                }
                // Onboarding is the ONLY place the app requests notification
                // permission (AppDelegate deliberately never prompts at
                // launch), so a bypassed restore must ask here — otherwise
                // this install never registers with iOS: the app doesn't even
                // appear in Settings → Notifications and no reminder can ever
                // fire. Permission is per-device; the user already granted it
                // on their other device, so one prompt here is expected.
                requestNotificationPermissionForRestoredUser()
                // A restored user is likely a subscriber, but this device may
                // not have refreshed its App Store receipt yet (launch-time
                // syncPurchases posts an empty receipt on a device that never
                // purchased). Force a restore once so premium unlocks with
                // zero taps; harmless no-op for free users.
                Task {
                    let restored = await subscriptionStore.restore()
                    AnalyticsService.shared.track("icloud_restore_auto_restore_purchases", parameters: [
                        "restored_premium": restored
                    ])
                }
            }
            // Healing pass for devices already stuck in the restored-but-
            // never-asked state (the bypass above only fires the moment the
            // synced onboarded flag first arrives; a device that restored on
            // an earlier build missed the prompt forever). An onboarded user
            // whose iOS permission is still notDetermined can only be that
            // broken state — normal onboarding always resolves the prompt —
            // so ask once. Self-limiting: answering the prompt means
            // notDetermined never matches again. Delayed a few seconds so it
            // can never collide with the ATT prompt (iOS drops one of two
            // simultaneous system alerts).
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                guard appState.isOnboarded else { return }
                UNUserNotificationCenter.current().getNotificationSettings { settings in
                    guard settings.authorizationStatus == .notDetermined else { return }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                        requestNotificationPermissionForRestoredUser()
                    }
                }
            }
            // Personalized push message — its own reader screen, separate from the
            // declaration feed. Attached at the container level (not inside the
            // onboarded branch) so a tapped message still presents during the
            // launch/landing window and is never stranded if its branch is
            // unmounted. Dismissal clears appState.remoteMessage.
            // Driven by a `deepLink == "message"` notification tap.
            .sheet(item: $appState.remoteMessage) { message in
                RemoteMessageView(message: message) {
                    // "See All SpeakLife Messages": close the reader, then
                    // surface the Inbox history. Presented as a sheet rather
                    // than a tab switch so it still lands correctly when the
                    // reader was opened over onboarding or the landing window,
                    // before the tab bar exists.
                    AnalyticsService.shared.track("speaklife_messages_opened", parameters: [
                        "source": "notification_reader"
                    ])
                    appState.remoteMessage = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        showSpeakLifeMessages = true
                    }
                }
            }
            // The Inbox, reached from the reader CTA above (must be a separate
            // presentation so it can appear after the reader sheet dismisses).
            .sheet(isPresented: $showSpeakLifeMessages) {
                SpeakLifeInboxView()
                    .environmentObject(subscriptionStore)
            }

    }

    @State private var onboardingStartLogged = false

    // Brief hold shown only when Remote Config hasn't activated yet on a fresh
    // install (bounded by SubscriptionStore's readiness timeout). Prevents the
    // A/B arm from locking to the in-app default before the assigned arm lands.
    private var onboardingLoadingView: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                .scaleEffect(1.2)
        }
    }

    @ViewBuilder
    private var onboardingFlow: some View {
        switch subscriptionStore.resolvedOnboardingVariant {
        case .quiz:
            QuizOnboardingView(size: UIScreen.main.bounds.size) { finishOnboarding() }
                .ignoresSafeArea()
        case .product:
            ProductOnboardingView(size: UIScreen.main.bounds.size) { finishOnboarding() }
                .ignoresSafeArea()
        case .identity:
            IdentityOnboardingView(size: UIScreen.main.bounds.size) { finishOnboarding() }
                .ignoresSafeArea()
        case .outcomes:
            OutcomesOnboardingView(size: UIScreen.main.bounds.size) { finishOnboarding() }
                .ignoresSafeArea()
        case .warfare:
            WarfareOnboardingView(size: UIScreen.main.bounds.size) { finishOnboarding() }
                .ignoresSafeArea()
        case .promises:
            PromisesOnboardingView(size: UIScreen.main.bounds.size) { finishOnboarding() }
                .ignoresSafeArea()
        case .closer:
            CloserOnboardingView(size: UIScreen.main.bounds.size) { finishOnboarding() }
                .ignoresSafeArea()
        }
    }

    private func logOnboardingStarted() {
        guard !onboardingStartLogged else { return }
        onboardingStartLogged = true
        // Freeze the variant before logging so a late ad deep link can't swap the
        // flow mid-run or desync started vs finished.
        subscriptionStore.lockOnboardingVariant()
        let variant = subscriptionStore.onboardingVariantName
        // Persist the arm as a user/person property in BOTH PostHog and Firebase so
        // EVERY downstream event (retention, trial_started, subscription_started)
        // segments by variant — not just the onboarding events. This is what makes
        // retention/purchase breakdowns by arm possible.
        AnalyticsService.shared.setUserProperty("onboarding_variant", value: variant)
        // Routed through AnalyticsService so the event reaches PostHog (the A/B
        // funnel) and Firebase, not just Firebase.
        AnalyticsService.shared.track("onboarding_started", parameters: [
            "variant": variant
        ])
        // Canonical experiment-exposure / activation event to key the A/B analysis
        // off of. Fires once per install, after the arm is locked and assigned.
        AnalyticsService.shared.track("experiment_exposure", parameters: [
            "experiment": "onboarding_variant",
            "variant": variant
        ])
    }

    private func finishOnboarding() {
        // Conversion outcome for the onboarding A/B funnel. The paywall step has
        // already run by now, so isPremium/isInTrial reflect any purchase made
        // during onboarding. conversion_type: "trial" | "purchase" | "none".
        let converted = subscriptionStore.isPremium
        let conversionType = converted ? (subscriptionStore.isInTrial ? "trial" : "purchase") : "none"
        AnalyticsService.shared.track("onboarding_finished", parameters: [
            "variant": subscriptionStore.onboardingVariantName,
            "converted": converted,
            "conversion_type": conversionType
        ])
        withAnimation {
            appState.isOnboarded = true
            LifecycleNotificationService.shared.scheduleLifecycleNotifications()
            AnalyticsService.shared.track("onBoardingFinished")
        }
    }

    /// iCloud-restored users skip onboarding, which is the only flow that
    /// requests notification permission — so the bypass asks here instead.
    /// Once granted, reminders are scheduled from the SYNCED preferences
    /// (times/count/categories restored from the user's other device).
    private func requestNotificationPermissionForRestoredUser() {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .authorized, .provisional:
                DispatchQueue.main.async {
                    appState.notificationEnabled = true
                    scheduleRestoredNotifications()
                }
            case .notDetermined:
                center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                    DispatchQueue.main.async {
                        appState.notificationEnabled = granted
                        AnalyticsService.shared.track("icloud_restore_notification_permission", parameters: [
                            "granted": granted
                        ])
                        if granted {
                            UIApplication.shared.registerForRemoteNotifications()
                            scheduleRestoredNotifications()
                        }
                    }
                }
            default:
                // Denied/restricted on this device — nothing to schedule.
                break
            }
        }
    }

    private func scheduleRestoredNotifications() {
        // Prefer the reminder categories restored via settings sync; fall
        // back to onboarding's defaults when none have synced yet.
        let restored = appState.selectedNotificationCategories
            .split(separator: ",")
            .compactMap { DeclarationCategory(rawValue: String($0)) }
        let categories: Set<DeclarationCategory> = restored.isEmpty
            ? [.faith, .confidence, .wisdom, .speaklife]
            : Set(restored)
        NotificationManager.shared.registerNotifications(
            count: appState.notificationCount,
            startTime: appState.startTimeIndex,
            endTime: appState.endTimeIndex,
            categories: categories
        )
        appState.lastNotificationSetDate = Date()
        LifecycleNotificationService.shared.scheduleLifecycleNotifications()
    }

    @ViewBuilder
    var homeView: some View {
        ZStack(alignment: .top) {
            TabView(selection: $tabViewModel.selectedTab) {
                if subscriptionStore.checklistHomeEnabled {
                    // "Today" checklist owns the home tab (tag 0) — the daily-habit
                    // surface that gives a goal, a "done", and a reason to return.
                    // The feed is demoted to its own "Speak" tab (tag 2); it's still
                    // one tap away and is what the Daily Burst opens into.
                    dailyChecklistView
                    declarationTab(tag: 2, title: "Speak")
                    // Bible Chat sits in the CENTER slot (most-tapped real estate);
                    // enableAIFeatures kill-switch falls back to Warrior Room when off.
                    if subscriptionStore.enableAIFeatures || BibleChatLocal.isDebug {
                        bibleChatTabView
                    } else {
                        communityView
                    }
                    // Audio follows the center slot. Visual order only — tags are
                    // unchanged (audio=1, bibleChat=4) so routing (goToAudio, deep
                    // links) and analytics (trackTabNavigation) still resolve.
                    audioView
                    // createYourOwnView dropped from this layout's bar to stay within
                    // the 5-tab limit; still reachable from the feed and Profile.
                    profileView
                } else {
                    // Kill switch off (Remote Config): revert to the legacy
                    // feed-as-home layout so we can roll back if complaints spike.
                    declarationTab(tag: 0, title: "Home")
                    audioView
                    if subscriptionStore.enableAIFeatures || BibleChatLocal.isDebug {
                        bibleChatTabView
                    } else {
                        communityView
                    }
                    createYourOwnView
                    profileView
                }
                }
                .hideTabBar(if: appState.showScreenshotLabel)
                .sheet(isPresented: $isPresented) {
                    WhatsNewBottomSheet(isPresented: $isPresented, version: currentVersion)
                        .presentationDetents([.medium])
                        .presentationDragIndicator(.visible)
                }
                .accentColor(Constants.DAMidBlue)
                // Keep feed routing (notifications, deep links, Daily Burst) pointed
                // at the right tab as the Remote Config layout flag resolves.
                .onChange(of: subscriptionStore.checklistHomeEnabled) { enabled in
                    tabViewModel.feedTabTag = enabled ? 2 : 0
                }
                // Siri / Shortcuts / the lock screen asked for the Guard drill
                // while the app was already open. The drill lives on the Today
                // tab, so if the user is somewhere else we have to bring them
                // there — otherwise the intent looks like it did nothing. The
                // tab itself clears the request and presents the flow.
                .onChange(of: takeItCaptiveService.launchRequestedAt) { _, requested in
                    guard requested != nil, subscriptionStore.guardEnabled else { return }
                    tabViewModel.goToChecklist()
                }
                .onAppear {
                    PremiumHaptics.prepare() // warm the Taptic Engine so the first tap lands
                    tabViewModel.feedTabTag = subscriptionStore.checklistHomeEnabled ? 2 : 0
                    checkForNewVersion()
                    checkForPersonalDeclarationMigration()
                    checkForPremiumAnniversary()
                    checkForYearInReview()
                    if appState.firstOpen {
                        appState.firstOpen = false
                    }
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
                                .padding(.vertical, DS.Spacing.sm)
                                .background(
                                    RoundedRectangle(cornerRadius: 25)
                                        .fill(LinearGradient(
                                            colors: [.orange, .red],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        ))
                                )
                        }
                        .buttonStyle(.dsPressable(feel: .tapSolid))
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
    
    // The declaration feed, parameterized so it can be the "Speak" tab (tag 2)
    // under the checklist-home layout or the "Home" tab (tag 0) under the legacy
    // feed-home layout.
    func declarationTab(tag: Int, title: String) -> some View {
        DeclarationView()
            .id(appState.rootViewId)
            .tag(tag)
            .tabItem {
                Image(systemName: "quote.bubble.fill")
                    .renderingMode(.original)
                Text(title)
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
        ModernDailyChecklistView(viewModel: streakViewModel, isHomeTab: true)
            .tag(0)
            .tabItem {
                Image(systemName: "sun.max.fill")
                    .renderingMode(.original)
                Text("Today")
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

    var bibleChatTabView: some View {
        BibleChatConversationView()
            .tag(4) // keep tag 4 so existing deep-links/selection still resolve
            .tabItem {
                Image(systemName: "bubble.left.and.text.bubble.right.fill")
                    .renderingMode(.original)
                Text("Bible Chat")
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
            // Don't cover the deep-linked declaration when launched from a notification.
            // isProcessingNotification clears ~1s after setDeclaration completes (often
            // before this asyncAfter fires at t≈2.5s), so use the session-scoped flag.
            guard !declarationStore.didOpenFromNotificationThisSession else { return }
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

    /// Surfaces the Year in Review between Dec 15 and Jan 15. Auto-launches
    /// on cold start once per recap year. From Dec 15 → Dec 31 the recap is
    /// for the in-progress current year (Spotify Wrapped pattern); from
    /// Jan 1 → Jan 15 it's for the year that just closed.
    ///
    /// Everyone with meaningful activity gets the core recap; premium
    /// subscribers see an additional Strength Level slide and a Premium
    /// Warrior mark on the share card (handled inside YearInReviewView).
    private func checkForYearInReview() {
        guard appState.isOnboarded else { return }
        guard !showSubscription else { return }
        guard yearInReviewStats == nil else { return }

        let calendar = Calendar.current
        let now = Date()
        let month = calendar.component(.month, from: now)
        let day = calendar.component(.day, from: now)
        let currentYear = calendar.component(.year, from: now)

        let recapYear: Int
        if month == 12 && day >= 15 {
            recapYear = currentYear
        } else if month == 1 && day <= 15 {
            recapYear = currentYear - 1
        } else {
            return
        }

        let shownKey = "yearInReview_shown_\(recapYear)"
        guard !UserDefaults.standard.bool(forKey: shownKey) else { return }

        let stats = YearInReviewStats.build(for: recapYear)
        guard stats.hasMeaningfulActivity else { return }

        UserDefaults.standard.set(true, forKey: shownKey)

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            guard appState.isOnboarded && !showSubscription else { return }
            yearInReviewStats = stats
        }
    }

    /// Surfaces a one-time anniversary overlay for premium subscribers at 30,
    /// 90, and 365 days. If the user is past multiple unshown milestones at
    /// check time (e.g. when this feature first ships), only the highest is
    /// shown and the lower ones are marked-as-shown silently so they don't
    /// queue up.
    private func checkForPremiumAnniversary() {
        guard appState.isOnboarded else { return }
        guard subscriptionStore.isPremium else { return }
        guard let originalDate = subscriptionStore.premiumOriginalPurchaseDate else { return }
        guard !showSubscription else { return }
        guard anniversaryMilestone == nil else { return }

        let days = Calendar.current.dateComponents([.day], from: originalDate, to: Date()).day ?? 0
        guard days > 0 else { return }

        let defaults = UserDefaults.standard

        // RevenueCat's originalPurchaseDate survives reinstalls (tied to the
        // Apple ID), but our shownDefaultsKey flags don't. Without this guard,
        // any tester or returning subscriber whose Apple ID previously held the
        // entitlement instantly gets the highest milestone surfaced right after
        // onboarding. The first time THIS install ever observes the user as
        // premium, silently mark every already-crossed milestone as shown so
        // only milestones crossed during this install fire going forward.
        let initialSeenKey = "premiumAnniversary_initialSeenAt"
        if defaults.object(forKey: initialSeenKey) == nil {
            defaults.set(Date(), forKey: initialSeenKey)
            for milestone in PremiumAnniversaryMilestone.ascending where days >= milestone.days {
                defaults.set(true, forKey: milestone.shownDefaultsKey)
            }
            return
        }

        let crossedUnshown = PremiumAnniversaryMilestone.ascending
            .filter { days >= $0.days && !defaults.bool(forKey: $0.shownDefaultsKey) }
        guard let highest = crossedUnshown.last else { return }

        for milestone in crossedUnshown where milestone != highest {
            defaults.set(true, forKey: milestone.shownDefaultsKey)
        }
        defaults.set(true, forKey: highest.shownDefaultsKey)

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            guard appState.isOnboarded && !showSubscription else { return }
            anniversaryMilestone = highest
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
