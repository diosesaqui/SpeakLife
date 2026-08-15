//
//  AppDelegate.swift
//  Dios Es Aqui
//
//  Created by Riccardo Washington on 1/30/22.
//

import UIKit
import BackgroundTasks
import FirebaseCore
import FirebaseAnalytics
import UserNotifications
import FacebookCore
import AppTrackingTransparency
import FirebaseMessaging
import FirebaseRemoteConfigInternal
#if canImport(BranchSDK)
import BranchSDK
#endif
import TikTokBusinessSDK
import RevenueCat
import PostHog

final class AppDelegate: NSObject, MessagingDelegate {
    
    var appState: AppState?
    var declarationStore: DeclarationViewModel?
    var tabViewModel: TabViewModel?
    var updateAppState: (() -> Void)?
    
    override init() {
        FirebaseApp.configure()

        // ─── RevenueCat ──────────────────────────────────────────────────────
        // Configure as early as possible — before any purchase UI is shown.
        #if DEBUG
        Purchases.logLevel = .debug
        #endif
        Purchases.configure(withAPIKey: "appl_MUGzgdbuQuNIDtfDLiJtIdyYPqf")
        Purchases.shared.attribution.collectDeviceIdentifiers()
        Purchases.shared.attribution.setFBAnonymousID(AppEvents.shared.anonymousID)

        // Link RC attribution data to Firebase for campaign attribution
        if let instanceID = Analytics.appInstanceID() {
            Purchases.shared.attribution.setFirebaseAppInstanceID(instanceID)
        }

        // Sync purchases on every cold launch so RC re-validates receipts with Apple.
        // Prevents subscribers from being locked out when RC's cached entitlement
        // state goes stale (e.g. after renewals, promo codes, or Family Sharing).
        Task {
            try? await Purchases.shared.syncPurchases()
        }
    }
    
    // Initialize TikTok SDK after ATT permission is handled
    func initializeTikTokSDK() {
        // The TikTok SDK builds shared singletons (logger/session) during
        // initializeSdk and is NOT safe to initialize off the main thread —
        // doing so races that setup and over-releases its internal `logger`
        // (EXC_BAD_ACCESS in getRemoteSwitch/getLogger). Initialize on the main
        // thread; the SDK performs its network calls asynchronously itself, so
        // this does not block the UI.
        let start = {
            let config = TikTokConfig(accessToken: "TTT9Kn1rHyqZN1AMEcrMS6WBCnh7pFj2", appId: "7421777490315624455", tiktokAppId: "7421777490315624455")
            #if DEBUG
            config?.enableDebugMode()
            #endif

            TikTokBusiness.initializeSdk(config) { success, error in
                DispatchQueue.main.async {
                    if (!success) {
                        print("🔴 TikTok SDK initialization failed: \(error?.localizedDescription ?? "Unknown error")")
                    } else {
                        print("✅ TikTok SDK initialized successfully")
                    }
                }
            }
        }

        if Thread.isMainThread {
            start()
        } else {
            DispatchQueue.main.async(execute: start)
        }
    }
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {

        registerNotificationHandler()

        // Install the UIKit-backed platform seams before anything touches the
        // Core Data / sync stores. `DefaultVendorIdentifier` feeds
        // `ProgressSyncStore.deviceId` its vendor pin (see the block comment
        // there for why that pin is load-bearing on iCloud-restored installs);
        // `LifecycleNames` gives the stores their foreground/background
        // notification names. Both live in the app target so the stores can
        // stay UIKit-free.
        DefaultVendorIdentifier.shared.read = {
            UIDevice.current.identifierForVendor?.uuidString
        }
        let lifecycle = LifecycleNames(
            didBecomeActive: UIApplication.didBecomeActiveNotification,
            didEnterBackground: UIApplication.didEnterBackgroundNotification
        )

        // Install the SpeakLifeCore seams (PR6). Core is Foundation-only, so
        // anything that needs to reach up into the app (analytics, the active
        // personal declaration, the AI task path's user-behavior profile) is
        // an injected closure that stays nil in `swift test`. See
        // `AnalyticsTracking.swift`, `FoundationAudioPlan.personalDeclarationCategoryProvider`,
        // and `TaskLibrary.userBehaviorProvider`.
        CoreAnalytics.provider = AnalyticsService.shared
        FoundationAudioPlan.personalDeclarationCategoryProvider = {
            PersonalDeclarationRepository.activeCategoryRaw()
        }
        TaskLibrary.userBehaviorProvider = {
            let profile = EnhancedAnalyticsService.shared.userBehaviorProfile
            return [
                "topCategories": Array(profile.topCategories.keys),
                "strugglingAreas": profile.strugglingAreas,
                "spiritualMaturity": profile.spiritualMaturityLevel.rawValue,
                "preferredTaskTypes": [],
                "completionPatterns": profile.completionRates,
                "weeklyPattern": profile.weeklyPattern,
                "currentLifeSeason": profile.currentLifeSeason,
            ]
        }

        PersistenceController.shared.start(lifecycle: lifecycle)

        // iCloud progress sync: mirror streaks, listened audio, counters, and
        // whitelisted preferences across the user's devices via CloudKit.
        // Both stores are additive/merge-only, so starting them is safe even
        // before the first CloudKit import completes.
        ProgressSyncStore.shared.start(lifecycle: lifecycle)
        SyncedSettingsStore.shared.start(lifecycle: lifecycle)

        // SpeakLifePersistence seams (PR7). Persistence is Firebase-free, so
        // anything that needs to reach up into the app for analytics, the
        // legacy JSON favorites source, or the app's `LocalAPIClient` is an
        // injected closure installed here.
        DataMigrationManager.defaultLegacyAPIServiceFactory = { LocalAPIClient() }
        UnifiedFavoritesManager.legacyJSONFavoritesProvider = { completion in
            CoreDataAPIService().declarations { declarations, _, _ in
                completion(declarations)
            }
        }
        AudioFavoritesTelemetry.trackFavoriteToggle = { audio, isFavorited in
            AudioAnalytics.shared.trackFavoriteToggle(audio: audio, isFavorited: isFavorited)
        }
        AudioFavoritesTelemetry.trackFavoriteRemoved = { audio in
            AudioAnalytics.shared.trackFavoriteRemoved(audio: audio)
        }
        AudioFavoritesTelemetry.trackFavoritesCleared = { count in
            AudioAnalytics.shared.trackFavoritesCleared(count: count)
        }
        AudioFavoritesTelemetry.trackFavoriteSavedForPaywall = {
            PaywallTriggerManager.shared.trackFavoriteSaved()
        }

        // SpeakLifeServices seams (PR8). Services is Foundation + Combine
        // only; every UIKit / SwiftUI / Firebase-adjacent hook it needs
        // is a closure installed here at composition time.
        EnhancedStreakViewModel.notifications = LifecycleNotificationService.shared
        EnhancedStreakViewModel.shareImageRenderer = { args in
            StreakShareCardRenderer.render(args)
        }
        EnhancedStreakViewModel.LifecycleNames.install(
            didBecomeActive: UIApplication.didBecomeActiveNotification
        )
        EnhancedStreakViewModel.cancelLegacyDailyNotifications = { identifiers in
            UNUserNotificationCenter.current()
                .removePendingNotificationRequests(withIdentifiers: identifiers)
        }
        PersonalDeclarationProgressBridge.todayProgress = {
            PersonalDeclarationRepository.todayProgress()
        }
        NotificationDeclarationSource.apiServiceFactory = { LocalAPIClient() }
        StreakFeedback.onTaskCompleted = { PremiumHaptics.affirmationCompleted() }
        StreakFeedback.onDayCompleted = { PremiumHaptics.dailyGoalCompleted() }
        StreakFeedback.onNewRecord = { PremiumHaptics.newRecordSet() }
        StreakFeedback.playGentleSuccess = {
            AudioDelightManager.shared.playGentleSuccess()
        }
        StreakFeedback.playForStreakMilestone = { streak in
            AudioDelightManager.shared.playForStreakMilestone(streak)
        }

        ApplicationDelegate.shared.application(
            application,
            didFinishLaunchingWithOptions: launchOptions
        )

        // Branch (MMP): resolve the deferred deep link at launch (no ATT wait) so
        // ad-matched onboarding is known before onboarding renders. No-op until the
        // BranchSDK Swift Package is added in Xcode.
        BranchAttribution.initSession(launchOptions: launchOptions)

        Messaging.messaging().delegate = self
        let settings = RemoteConfigSettings()
        #if DEBUG
        settings.minimumFetchInterval = 0
        #else
        settings.minimumFetchInterval = 3600 * 5
        #endif
        RemoteConfig.remoteConfig().configSettings = settings

        // In-app Remote Config defaults. Without these, a fresh install reads
        // un-fetched flags before the first network fetch completes — which
        // would briefly fall back to the legacy useQuizOnboarding routing.
        // Default onboardingVariant so first launch goes straight to the chosen
        // flow; Remote Config (incl. any A/B test) still overrides once fetched.
        // "warfare" is the baseline/default; the Firebase A/B test splits the
        // other arms (product / identity / quiz / outcomes / promises / closer)
        // against it once fetched.
        RemoteConfig.remoteConfig().setDefaults([
            "useQuizOnboarding": true as NSNumber,
            "onboardingVariant": "warfare" as NSString,
            // Checklist home tab is on by default; flip to false in Remote Config
            // to revert to the feed-as-home layout if complaints spike.
            "checklistHomeEnabled": true as NSNumber,
            // Seven-day Enforcement campaigns ship on. Flip to false in Remote Config
            // and every Enforcement surface goes dark at once: the Today card stops
            // rendering, the checklist audio task falls back to
            // FoundationAudioPlan, and the daily push reverts to the rotating
            // declaration. No orphaned state either way.
            "enforcementEnabled": true as NSNumber,
            // Guarding (Take It Captive) ships on. Flip to false in Remote Config
            // and the fifth pillar goes dark at once: the checklist row stops
            // being built and the flow has no entry point. Nothing is orphaned —
            // ground already taken is a plain synced counter and survives the
            // switch being thrown either way.
            "guardEnabled": true as NSNumber,
            // Onboarding rating ask ships on; flip to false in Remote Config to
            // skip the rating step in every onboarding flow.
            "onboardingRatingEnabled": true as NSNumber,
            // "I'm In" pledge inside the closer onboarding arm ships on; flip to
            // false in Remote Config to run the arm's no-pledge cell.
            "closerPledgeEnabled": true as NSNumber,
            // Personalized audio category ordering ships dark; flip to true in
            // Remote Config (or via the A/B test) to promote each user's
            // best-matching categories to the front of the audio filter row.
            "personalizedAudioOrderEnabled": false as NSNumber,
            // Forced update gate. Ships inert and doubly so: the switch is off
            // AND the floor is empty, either of which alone is enough to keep
            // every user running. To retire a build, publish
            // `minimumAppVersion` (e.g. "2.4.0") and flip `forceUpdateEnabled`
            // to true; flipping the switch back off releases everyone
            // immediately, which is why the floor alone can't lock anyone out.
            // The copy keys are optional overrides — empty falls back to the
            // wording compiled into ForcedUpdatePrompt. See
            // MinimumVersionPolicy (SpeakLifeCore) for the decision rules.
            MinimumVersionPolicy.enabledKey: false as NSNumber,
            MinimumVersionPolicy.minimumVersionKey: "" as NSString,
            MinimumVersionPolicy.titleKey: "" as NSString,
            MinimumVersionPolicy.messageKey: "" as NSString,
            // Paywall product IDs — defaults mirror the compiled-in SKUs so a
            // fresh install (offline / pre-fetch) still offers real products;
            // Remote Config overrides once fetched. Read in
            // SubscriptionStore.updateConfigValues.
            "currentPremiumID": currentPremiumID as NSString,
            "currentPremiumMonthly": currentMonthlyPremiumID as NSString,
            "currentPremiumWeekly": weeklyID as NSString
        ])

        // Wire the domain-facing feature-flag seam to Firebase Remote Config now
        // that its defaults are set. `EnforcementService` and
        // `TakeItCaptiveService` read through `DefaultFeatureFlags.shared`, so
        // installing here — before either singleton is first touched — lets them
        // stay Firebase-free while still honoring the live flag values.
        DefaultFeatureFlags.shared.provider = RemoteConfigFlags()

        registerBGTask()
        
        // Initialize TikTok SDK after a brief delay to not interfere with landing animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.initializeTikTokSDK()
        }
        
        // Track TikTok app launch (will queue until SDK is ready)
        Event.trackTikTokAppLaunch()
        
        // Track install on first launch (only called once)
        let isFirstLaunch = UserDefaults.standard.bool(forKey: "hasLaunchedBefore")
        if !isFirstLaunch {
            UserDefaults.standard.set(true, forKey: "hasLaunchedBefore")
            Event.trackTikTokAppInstall()
        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(scheduleNotificationRequest), name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(scheduleNotificationRequest), name: resyncNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(rescheduleNotificationsForNewContent), name: declarationsContentUpdated, object: nil)
        
        // Register FCM for onboarded users (including migration for existing users)
        let hasMigratedFCM = UserDefaults.standard.bool(forKey: "hasMigratedToFCM")
        registerForPushNotifications()
        if appState?.isOnboarded ?? false {
            
            if !hasMigratedFCM {
                UserDefaults.standard.set(true, forKey: "hasMigratedToFCM")
            }
        }
        // Lifecycle: track app open for lapsed re-engagement detection
        LifecycleNotificationService.shared.onAppOpen()
        return true
    }
    
    func registerForPushNotifications() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            if settings.authorizationStatus == .authorized {
                // Already authorized - just register for remote notifications
                DispatchQueue.main.async {
                    print("✅ Already authorized - registering for FCM Token RWRW")
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
            // Do NOT prompt undetermined users at launch. The onboarding flow asks
            // for notification permission at the right moment (after the user picks
            // their needs / notification time). Prompting here showed the
            // notification alert too early AND blocked the ATT prompt from
            // appearing (iOS won't present two system alerts at once).
        }
    }
    
   
    
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let token = fcmToken else { return }
        print("✅ FCM Token: \(token)") // This should now appear in Xcode logs

        // Cache the token so flows that read it (e.g. PrayerWall registration)
        // get a real value instead of an empty string.
        UserDefaults.standard.set(token, forKey: "fcmToken")

        // Subscribe every device to the broadcast topic so server-sent
        // announcements / personalized messages can reach the whole user base
        // without needing a per-user token store. Safe to call repeatedly.
        Messaging.messaging().subscribe(toTopic: "allUsers") { error in
            if let error = error {
                print("⚠️ Failed to subscribe to allUsers topic: \(error.localizedDescription)")
            }
        }
    }

    /// Recover a Meta deferred app link (ad-matched onboarding) once, AFTER the
    /// ATT response — advertiser tracking must be resolved or Meta won't return
    /// the deferred link. The "checked" flag is set only on a clean completion, so
    /// a transient first-launch failure (e.g. no network) retries on a later launch.
    func checkDeferredAppLinkOnce() {
        guard !UserDefaults.standard.bool(forKey: "didCheckDeferredAppLink") else { return }
        AppLinkUtility.fetchDeferredAppLink { url, error in
            if let error = error {
                print("⚠️ Deferred app link fetch failed, will retry next launch: \(error.localizedDescription)")
                return
            }
            // Clean completion: either we got a link, or there genuinely isn't one.
            UserDefaults.standard.set(true, forKey: "didCheckDeferredAppLink")
            if let url = url {
                SubscriptionStore.handleIncomingURL(url, source: "ad")
            }
        }
    }
    
    // Removed duplicate didReceive - now handled in extension
}

/// Firebase-backed `FeatureFlagProviding`. Lives in the app target so the
/// domain services that read flags do not import `FirebaseRemoteConfig`.
/// Installed into `DefaultFeatureFlags.shared` in `didFinishLaunchingWithOptions`
/// immediately after `RemoteConfig.setDefaults(...)`.
///
/// Consults `DebugOverrides` first so the shake panel can take Enforcement or
/// Guarding dark on a TestFlight device without a Remote Config change. That
/// lookup returns nil on the App Store, leaving the Remote Config read below as
/// the only path for real users.
struct RemoteConfigFlags: FeatureFlagProviding {
    func bool(_ key: String, default defaultValue: Bool) -> Bool {
        DebugOverrides.bool(key) ?? RemoteConfig.remoteConfig()[key].boolValue
    }
}

extension AppDelegate {
    
    func application(
            _ app: UIApplication,
            open url: URL,
            options: [UIApplication.OpenURLOptionsKey : Any] = [:]
        ) -> Bool {
            BranchAttribution.handleOpen(app, url, options)
            return ApplicationDelegate.shared.application(
                app,
                open: url,
                sourceApplication: options[UIApplication.OpenURLOptionsKey.sourceApplication] as? String,
                annotation: options[UIApplication.OpenURLOptionsKey.annotation]
            )
        }

    func application(
            _ application: UIApplication,
            continue userActivity: NSUserActivity,
            restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void
        ) -> Bool {
            // Branch universal links (already-installed taps) — deferred installs
            // are handled by initSession above.
            BranchAttribution.handleUserActivity(userActivity)
            return true
        }
    
    private func registerNotificationHandler() {
        // Set AppDelegate as the notification delegate to handle both foreground and background scenarios
        UNUserNotificationCenter.current().delegate = self
    }
    
    
    private func registerBGTask() {

        BGTaskScheduler.shared.register(forTaskWithIdentifier: "com.speaklife.updateNotificationContent", using: nil) { task in
            self.updateNotificationContent(task: task as! BGAppRefreshTask)
        }

        // Wire the Foundation-typed submit seam on `NotificationManager` to the
        // real `BGTaskScheduler`. Kept here so the manager itself does not
        // import `BackgroundTasks` — the framework only touches the app target.
        NotificationManager.shared.submitBackgroundTask = { identifier, earliestBeginDate in
            let request = BGAppRefreshTaskRequest(identifier: identifier)
            request.earliestBeginDate = earliestBeginDate
            do {
                try BGTaskScheduler.shared.submit(request)
                let formatter = DateFormatter()
                formatter.dateStyle = .short
                formatter.timeStyle = .short
                let when = earliestBeginDate.map { formatter.string(from: $0) } ?? "asap"
                print("✅ BGAppRefreshTask scheduled for \(when)")
            } catch {
                print("⚠️ Could not schedule notification batch refresh: \(error.localizedDescription)")
            }
        }
    }
    
    /// Called when `resyncNotification` fires (e.g. content version bump or
    /// other in-app trigger). Immediately reschedules a fresh notification batch
    /// via UserDefaults preferences; `NotificationManager` will then submit a
    /// new BGAppRefreshTask for the next refresh window automatically.
    @objc func scheduleNotificationRequest() {
        NotificationManager.shared.rescheduleFromUserDefaults()
    }

    /// Fires when remote declarations are freshly downloaded due to a version bump.
    /// Reschedules local notifications immediately so users get the new content
    /// without waiting for the next natural batch-refresh window.
    @objc func rescheduleNotificationsForNewContent() {
        NotificationManager.shared.rescheduleFromUserDefaults()
    }
    
    private func updateNotificationContent(task: BGAppRefreshTask)  {
        scheduleNotificationRequest()
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        
        guard let appState = appState else  {
            return
        }
        
        let updateNotificationsOperation = UpdateNotificationsOperation(appState: appState)
        
        task.expirationHandler = {
            queue.cancelAllOperations()
        }
        
        updateNotificationsOperation.completionBlock = {
            task.setTaskCompleted(success: true)
        }
        
        queue.addOperation(updateNotificationsOperation)
        queue.waitUntilAllOperationsAreFinished()
        
    }
}

extension AppDelegate: UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        print(deviceToken, "RWRW")
        let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
           print("✅ Successfully registered for APNs with token: \(tokenString) RWRW success")
        Messaging.messaging().apnsToken = deviceToken
    
    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print(error, "RWRW failed")
    }
}

extension AppDelegate: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Pass to NotificationHandler for app state updates
        NotificationHandler.shared.userNotificationCenter(center, willPresent: notification) { options in
            completionHandler(options)
        }
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        // Pass to NotificationHandler for app state updates
        NotificationHandler.shared.userNotificationCenter(center, didReceive: response, withCompletionHandler: completionHandler)
    }
}

// MARK: - Branch (MMP) ad-matched onboarding
//
// Thin wrapper around the Branch SDK. Guarded by `canImport(BranchSDK)` so the
// app builds before the Swift Package is added in Xcode; it activates the moment
// the package is added. Unlike Meta's deferred app link (gated by the ATT
// response), Branch resolves the deferred link AT LAUNCH without waiting on ATT,
// so the ad's `ob=<variant>` is known before onboarding renders.
enum BranchAttribution {

    /// Call as early as possible in didFinishLaunching. Resolves the deferred deep
    /// link for fresh installs and routes `ob=<variant>` into the onboarding override.
    static func initSession(launchOptions: [UIApplication.LaunchOptionsKey: Any]?) {
        #if canImport(BranchSDK)
        Branch.getInstance().initSession(launchOptions: launchOptions) { params, _ in
            apply(params as? [String: Any])
        }
        #endif
    }

    /// Forward already-installed Branch link opens (custom scheme).
    static func handleOpen(_ app: UIApplication, _ url: URL, _ options: [UIApplication.OpenURLOptionsKey: Any]) {
        #if canImport(BranchSDK)
        _ = Branch.getInstance().application(app, open: url, options: options)
        #endif
    }

    /// Forward direct deep-link opens (SwiftUI `.onOpenURL`).
    static func handleDeepLink(_ url: URL) {
        #if canImport(BranchSDK)
        Branch.getInstance().handleDeepLink(url)
        #endif
    }

    /// Forward universal-link opens (SwiftUI `.onContinueUserActivity`).
    static func handleUserActivity(_ userActivity: NSUserActivity) {
        #if canImport(BranchSDK)
        _ = Branch.getInstance().continue(userActivity)
        #endif
    }

    #if canImport(BranchSDK)
    private static func apply(_ params: [String: Any]?) {
        guard let params = params else { return }
        // Prefer an explicit `ob` key set on the Branch link's deep-link data;
        // otherwise recover it from the referring link URL.
        if let ob = params["ob"] as? String {
            SubscriptionStore.assignOnboardingVariantFromAd(ob, source: "ad")
        } else if let link = (params["~referring_link"] as? String) ?? (params["$canonical_url"] as? String),
                  let url = URL(string: link) {
            SubscriptionStore.handleIncomingURL(url, source: "ad")
        }
    }
    #endif
}
