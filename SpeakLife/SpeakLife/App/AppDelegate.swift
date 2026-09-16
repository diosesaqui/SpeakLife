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
#if canImport(AppsFlyerLib)
import AppsFlyerLib
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

            // SKAdNetwork gives each install ONE conversion value, and
            // `updatePostbackConversionValue` is last-writer-wins. Two SDKs in
            // this app want to write it: the Meta SDK does so off its
            // automatic in-app-purchase logging (on by default, never disabled
            // here), and TikTok's does so from a schema fetched at runtime.
            // Whichever writes second wins, and neither knows it lost — the
            // networks just optimize against a value that means something
            // other than what they think.
            //
            // Meta is the app's larger paid channel and already owns the
            // deferred-app-link path, so it keeps the conversion value and
            // TikTok stands down. TikTok documents exactly this call for the
            // case where another SDK owns SKAN.
            //
            // To hand ownership to TikTok instead: delete this line and set
            // `FacebookSKAdNetworkReportEnabled` to false in Info.plist. Never
            // leave both on, and never add a third writer in app code.
            config?.disableSKAdNetworkSupport()

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
        // Stand With Me's write path. Without this the seam stays nil and a
        // completed Enforcement day is never mirrored into the shared room —
        // the feature builds, runs, and silently does nothing.
        //
        // Installed rather than referenced directly for the same reason as the
        // hooks above: SpeakLifeServices has no Firebase dependency and must
        // not gain one.
        StandMirror.shared = StandService.shared

        // Start the room listener and the pass observer for anybody who ALREADY
        // has an account. Without this `rooms` stayed empty for the whole
        // session, so `mirrorDay` early-returned and a completed day was never
        // mirrored — the feature's core loop, silently dead. It also left the
        // Profile row hidden and let `StandInviteRow` mint a duplicate room
        // because it could not see the existing one.
        //
        // No account is created here: `StandService.startListening` and
        // `StandPassStore.startObserving` both no-op without a current user, and
        // an anonymous account is still only minted on Invite or on opening an
        // invite link.
        Task { @MainActor in
            StandAuthCoordinator.shared.refresh()
            guard StandAuthCoordinator.shared.currentUid != nil else { return }
            StandService.shared.startListening()
            StandPassStore.shared.startObserving()
            // Finish a migration that was started but never confirmed — the app
            // can be killed between signing in with Apple and telling the
            // server. Idempotent server-side, so retrying is free.
            await StandAuthCoordinator.shared.completePendingMergeIfNeeded()
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
        // ad-matched onboarding is known before onboarding renders. Live — the
        // package is added and `branch_key` is set.
        BranchAttribution.initSession(launchOptions: launchOptions)

        // AppsFlyer (MMP): the same job as Branch, and the ALTERNATIVE to it,
        // never an addition — two MMPs double-count every install. Branch is
        // the one chosen (see docs/ATTRIBUTION_MMP.md §6), so this stays dead:
        // its package is not added, and it would additionally need
        // AppsFlyerDevKey / AppsFlyerAppleAppID in Info.plist. If AppsFlyer is
        // ever adopted, delete the Branch call above in the same change.
        AppsFlyerAttribution.configure()

        // Per-person acquisition channel. Starts the Apple Search Ads token
        // exchange and schedules the organic fallback, so every person ends up
        // with a channel and CAC can be set against LTV per channel.
        //
        // Runs alongside Branch rather than instead of it. Branch reports the
        // click that produced the install; this owns Apple Search Ads, which
        // Branch does not, and the priority ladder that decides which source
        // wins when both speak.
        AcquisitionAttribution.shared.start()

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
        
        // Track install on first launch (only called once).
        //
        // This used to dedupe on `hasLaunchedBefore`, which SpeakLifeApp also
        // owns as the @AppStorage flag behind "first launch turns background
        // music on". didFinishLaunching runs before that view's .onAppear, so
        // this write consumed the flag every time and the music default never
        // once applied on a real first launch. Two unrelated jobs, two keys.
        //
        // Seeded from the old key so the existing base — already launched,
        // already counted — does not re-fire an install event on upgrade.
        let defaults = UserDefaults.standard
        let didTrackInstallKey = "analytics_did_track_install"
        if !defaults.bool(forKey: didTrackInstallKey) {
            let isExistingInstall = defaults.bool(forKey: "hasLaunchedBefore")
            defaults.set(true, forKey: didTrackInstallKey)
            if !isExistingInstall {
                Event.trackTikTokAppInstall()
            }
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

                // Same link, read for acquisition channel rather than for the
                // onboarding arm.
                //
                // Scope worth being explicit about: this only fires for Meta
                // campaigns configured with a deferred link. A Meta install
                // carrying no link is invisible here — Meta reports it on its
                // own side and no client API hands it back. So
                // `acquisition_channel = meta` is a FLOOR on Meta-driven
                // installs, never the total, and belongs reconciled against Ads
                // Manager rather than trusted outright.
                AcquisitionAttribution.shared.recordDeepLink(url, source: "meta_deferred")

                // A Meta link with no utm_source would otherwise file as a
                // generic owned deep link. It is paid traffic and has to price
                // as such.
                if AcquisitionAttribution.shared.storedRecord()?.channel == .ownedDeeplink {
                    AcquisitionAttribution.shared.record(channel: .meta, source: "meta_deferred")
                }
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

    /// An unset Remote Config string reads as "", which is not a value — it is
    /// the absence of one. Falling through to the caller's default there keeps
    /// the same semantics `bool` has.
    func string(_ key: String, default defaultValue: String) -> String {
        if let override = DebugOverrides.string(key), !override.isEmpty { return override }
        let remote = RemoteConfig.remoteConfig()[key].stringValue
        return remote.isEmpty ? defaultValue : remote
    }
}

extension AppDelegate {
    
    func application(
            _ app: UIApplication,
            open url: URL,
            options: [UIApplication.OpenURLOptionsKey : Any] = [:]
        ) -> Bool {
            BranchAttribution.handleOpen(app, url, options)
            AppsFlyerAttribution.handleOpen(app, url, options)
            AcquisitionAttribution.shared.recordDeepLink(url, source: "custom_scheme")
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
            AppsFlyerAttribution.handleUserActivity(userActivity)
            // Universal links are the web-side half of the same campaigns, so
            // they carry the same UTM set as the custom-scheme links above.
            if userActivity.activityType == NSUserActivityTypeBrowsingWeb,
               let url = userActivity.webpageURL {
                AcquisitionAttribution.shared.recordDeepLink(url, source: "universal_link")
            }
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
// Thin wrapper around the Branch SDK. The `canImport(BranchSDK)` guards are
// kept so the file still compiles if the package is ever removed, but the
// package IS added and the key IS set, so this is live code. Unlike Meta's
// deferred app link (gated by the ATT
// response), Branch resolves the deferred link AT LAUNCH without waiting on ATT,
// so the ad's `ob=<variant>` is known before onboarding renders.
enum BranchAttribution {

    /// Branch reads its key from the `branch_key` Info.plist entry. The Swift
    /// Package is now added, so `canImport(BranchSDK)` is true and every method
    /// below is live code — but the dashboard half (key, OneLink subdomain,
    /// Associated Domains) is configuration this repo does not carry. Without a
    /// key the SDK cannot attribute anything and only logs, so the whole
    /// wrapper stays a no-op until the key is present.
    private static var isConfigured: Bool {
        guard let key = Bundle.main.object(forInfoDictionaryKey: "branch_key") as? String else { return false }
        return !key.isEmpty
    }

    /// Gives Branch the same identity RevenueCat already uses for this person.
    ///
    /// RevenueCat's Branch integration keys its events off the RevenueCat App
    /// User Id by default, so making that id Branch's developer identity is
    /// what lets a trial, conversion or renewal reported by RevenueCat land on
    /// the same Branch person as the ad click that produced the install. That
    /// is the join that puts revenue next to campaign spend in Branch.
    ///
    /// Deliberately NOT done by calling `Purchases.shared.logIn(...)`, which is
    /// the more commonly suggested fix. Two reasons it is wrong here:
    ///
    ///  * There is no app-level user id to pass. Apple sign-in exists but is
    ///    scoped to the Community/Prayer Wall feature and `uid` is "" for
    ///    everyone else, so a `logIn` would cover a minority of people and
    ///    leave the rest exactly as split as before.
    ///  * `logIn` CHANGES `Purchases.shared.appUserID`, and that id is load
    ///    bearing: `BibleChatService` sends it to the chat proxy, which keys
    ///    server-side entitlement checks and usage metering off it. Changing
    ///    it orphans every existing subscriber's record there.
    ///
    /// Setting Branch's identity to RevenueCat's id achieves the same join from
    /// the other direction, covers everyone rather than sign-ins only, and
    /// changes nothing RevenueCat-side.
    static func setIdentity(_ appUserID: String) {
        #if canImport(BranchSDK)
        guard isConfigured, !appUserID.isEmpty else { return }
        Branch.getInstance().setIdentity(appUserID)
        #endif
    }

    /// Call as early as possible in didFinishLaunching. Resolves the deferred deep
    /// link for fresh installs and routes `ob=<variant>` into the onboarding override.
    static func initSession(launchOptions: [UIApplication.LaunchOptionsKey: Any]?) {
        #if canImport(BranchSDK)
        guard isConfigured else { return }
        Branch.getInstance().initSession(launchOptions: launchOptions) { params, _ in
            apply(params as? [String: Any])
        }
        #endif
    }

    /// Forward already-installed Branch link opens (custom scheme).
    static func handleOpen(_ app: UIApplication, _ url: URL, _ options: [UIApplication.OpenURLOptionsKey: Any]) {
        #if canImport(BranchSDK)
        guard isConfigured else { return }
        _ = Branch.getInstance().application(app, open: url, options: options)
        #endif
    }

    /// Forward direct deep-link opens (SwiftUI `.onOpenURL`).
    static func handleDeepLink(_ url: URL) {
        #if canImport(BranchSDK)
        guard isConfigured else { return }
        Branch.getInstance().handleDeepLink(url)
        #endif
    }

    /// Forward universal-link opens (SwiftUI `.onContinueUserActivity`).
    static func handleUserActivity(_ userActivity: NSUserActivity) {
        #if canImport(BranchSDK)
        guard isConfigured else { return }
        _ = Branch.getInstance().continue(userActivity)
        #endif
    }

    #if canImport(BranchSDK)
    private static func apply(_ params: [String: Any]?) {
        guard let params = params else { return }

        // Stand invite, resolved from a DEFERRED link — the invitee did not
        // have the app and just installed it from the App Store. This is the
        // highest-intent install the feature produces, so it is read before
        // anything else here can fail.
        //
        // Stash it, never present from here: this runs inside
        // didFinishLaunching, which on a fresh install is before onboarding has
        // finished. A join sheet fighting onboarding is how the invitee
        // bounces on their first launch.
        // Normalized, never stored raw. StandJoinView hides the code field when
        // a code is prefilled, so a malformed value left the user staring at a
        // disabled button with no way to correct it. StandLink.normalize
        // returns nil for anything that is not a valid code, which falls back
        // to the manual-entry path instead.
        if let code = (params["stand"] as? String).flatMap(StandLink.normalize)
            ?? (params["~referring_link"] as? String).flatMap({ URL(string: $0) })
                .flatMap(StandLink.code(from:)) {
            UserDefaults.standard.set(code, forKey: "pendingStandCode")
            AnalyticsService.shared.track("stand_invite_opened", parameters: [
                "source": "deferred"
            ])
        }
        // Prefer an explicit `ob` key set on the Branch link's deep-link data;
        // otherwise recover it from the referring link URL.
        if let ob = params["ob"] as? String {
            SubscriptionStore.assignOnboardingVariantFromAd(ob, source: "ad")
        } else if let link = (params["~referring_link"] as? String) ?? (params["$canonical_url"] as? String),
                  let url = URL(string: link) {
            SubscriptionStore.handleIncomingURL(url, source: "ad")
        }

        // Only a real link click is an attribution. See `attribution(from:)`.
        guard let attribution = attribution(from: params) else { return }
        AcquisitionAttribution.shared.record(
            channel: attribution.channel,
            source: attribution.source,
            campaign: attribution.campaign,
            adGroup: attribution.adGroup,
            creative: attribution.creative,
            keyword: attribution.keyword
        )
    }
    #endif

    // MARK: - Attribution decision
    //
    // Pure and outside the SDK guard, so it is unit-testable without Branch.

    struct Attribution: Equatable {
        let channel: AcquisitionChannel
        let source: String
        let campaign: String?
        let adGroup: String?
        let creative: String?
        let keyword: String?
    }

    /// What a Branch session says about acquisition, or nil when it says nothing.
    ///
    /// `initSession` calls back on EVERY launch, not just link opens. A session
    /// with no matched click still returns params (`+clicked_branch_link:
    /// false`, `+is_first_session`, `+non_branch_link`), and this used to record
    /// all of them as `owned_deeplink / branch`. That outranks `organic` (60 vs
    /// 10), so it overwrote the organic decision for nearly every install: 360
    /// of 382 onboarding starters over 14 days read `owned_deeplink` with no
    /// campaign. No click, no attribution: AcquisitionAttribution's own organic
    /// finalizer owns that answer.
    static func attribution(from params: [String: Any]) -> Attribution? {
        guard clickedBranchLink(params) else { return nil }

        func string(_ key: String) -> String? {
            guard let value = params[key] as? String else { return nil }
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }

        // Branch's own attribution keys beat anything parsed off the URL: they
        // name the network that actually served the click, which a link's
        // utm_source only claims. Most specific first — the ad partner, then
        // the link's channel, then its feature ("paid advertising", "invite").
        let candidates = [
            string("~advertising_partner_name"),
            string("~channel"),
            string("~feature")
        ].compactMap { $0 }

        var channel = candidates
            .lazy
            .map { AcquisitionChannel.from(sourceString: $0) }
            .first { $0 != .unknown } ?? .unknown

        // A stand invite is a person inviting a person, whatever the link's
        // channel field was left as.
        if channel == .unknown, string("stand") != nil
            || string("~referring_link").flatMap({ URL(string: $0) }).flatMap(StandLink.code(from:)) != nil {
            channel = .referral
        }

        // A real click with no network named is still an owned link.
        if channel == .unknown { channel = .ownedDeeplink }

        return Attribution(
            channel: channel,
            // Raw network text survives here even when the channel is coarse.
            source: candidates.first ?? "branch",
            campaign: string("~campaign"),
            adGroup: string("~ad_set_name"),
            creative: string("~creative_name"),
            keyword: string("~keyword")
        )
    }

    /// `+clicked_branch_link` arrives as a Bool from the SDK, but as an
    /// NSNumber or a string when it has crossed a JSON or Objective-C boundary.
    /// Anything unreadable counts as no click.
    static func clickedBranchLink(_ params: [String: Any]) -> Bool {
        switch params["+clicked_branch_link"] {
        case let flag as Bool:
            return flag
        case let number as NSNumber:
            return number.boolValue
        case let text as String:
            return ["true", "1", "yes"].contains(text.trimmingCharacters(in: .whitespaces).lowercased())
        default:
            return false
        }
    }
}

// MARK: - AppsFlyer (MMP)
//
// Thin wrapper around the AppsFlyer SDK, written to the same shape as
// `BranchAttribution` above: guarded by `canImport(AppsFlyerLib)` so the app
// builds and ships unchanged until the Swift Package is added in Xcode, and
// activates the moment it is.
//
// What it adds that the app cannot get on its own:
//
// * TikTok and Google installs. `AcquisitionAttribution` resolves Apple Search
//   Ads deterministically and Meta only when a campaign carries a deferred
//   link. Every TikTok and Google install currently files as `organic`, so
//   those channels have no CAC at all.
// * A deferred deep link that does NOT wait on ATT, which is the whole reason
//   `docs/AD_ONBOARDING_ROUTING.md` wanted an MMP: the ad's `ob=` variant has
//   to be known before onboarding renders, and Meta's `fetchDeferredAppLink`
//   only answers after the ATT response.
// * One owner for the SKAdNetwork conversion value. The Meta and TikTok SDKs
//   both ship their own SKAN reporters and `updatePostbackConversionValue` is
//   last-writer-wins per install, so today they overwrite each other.
//
// Configuration lives in Info.plist rather than in source, so no key is
// committed and the wrapper stays inert until both values are set:
//
//   AppsFlyerDevKey     (String) — from the AppsFlyer dashboard
//   AppsFlyerAppleAppID (String) — the numeric App Store id, digits only
//
enum AppsFlyerAttribution {

    /// Info.plist keys. Both must be present or the SDK is never configured,
    /// which keeps a package-added-but-not-yet-provisioned build silent rather
    /// than crashing on an empty dev key.
    private enum PlistKey {
        static let devKey = "AppsFlyerDevKey"
        static let appleAppID = "AppsFlyerAppleAppID"
    }

    /// Call from `didFinishLaunchingWithOptions`, after RevenueCat is
    /// configured (AppDelegate.init does that) so the AppsFlyer id can be
    /// handed straight to RevenueCat's subscriber attributes.
    static func configure() {
        #if canImport(AppsFlyerLib)
        guard let devKey = Bundle.main.object(forInfoDictionaryKey: PlistKey.devKey) as? String,
              !devKey.isEmpty,
              let appleAppID = Bundle.main.object(forInfoDictionaryKey: PlistKey.appleAppID) as? String,
              !appleAppID.isEmpty else { return }

        let lib = AppsFlyerLib.shared()
        lib.appsFlyerDevKey = devKey
        lib.appleAppID = appleAppID
        lib.delegate = AppsFlyerBridge.shared
        lib.deepLinkDelegate = AppsFlyerBridge.shared
        #if DEBUG
        lib.isDebug = true
        #endif

        // Hold the install postback until the person answers ATT, so a granted
        // IDFA is attached to it rather than arriving after attribution has
        // already been decided. The prompt fires ~1.5s into the landing screen
        // (see SpeakLifeApp), so ten seconds covers a real answer without
        // stalling attribution behind someone who never taps.
        lib.waitForATTUserAuthorization(timeoutInterval: 10)

        // RevenueCat's AppsFlyer integration keys on this attribute. Without
        // it, the trial starts, conversions and renewals RevenueCat sends
        // server-side never join the install, and channel LTV stops at the
        // first payment made while the app was open.
        if Purchases.isConfigured {
            let uid = lib.getAppsFlyerUID()
            Purchases.shared.attribution.setAppsflyerID(uid)
            // Same identity in both directions, so an AppsFlyer-side export can
            // be joined to a RevenueCat subscriber without a mapping table.
            lib.customerUserID = Purchases.shared.appUserID
        }

        // AppsFlyer requires `start()` while the app is active; calling it from
        // didFinishLaunching (pre-active) drops the session. Observing here
        // keeps the call site in one file instead of adding another lifecycle
        // hook to AppDelegate.
        NotificationCenter.default.addObserver(
            AppsFlyerBridge.shared,
            selector: #selector(AppsFlyerBridge.applicationDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        #endif
    }

    /// Forward custom-scheme opens (`speaklife://…`).
    static func handleOpen(_ app: UIApplication, _ url: URL, _ options: [UIApplication.OpenURLOptionsKey: Any]) {
        #if canImport(AppsFlyerLib)
        AppsFlyerLib.shared().handleOpen(url, options: options)
        #endif
    }

    /// Forward direct deep-link opens (SwiftUI `.onOpenURL`).
    static func handleDeepLink(_ url: URL) {
        #if canImport(AppsFlyerLib)
        AppsFlyerLib.shared().handleOpen(url, options: nil)
        #endif
    }

    /// Forward universal-link opens (OneLink taps by already-installed users).
    static func handleUserActivity(_ userActivity: NSUserActivity) {
        #if canImport(AppsFlyerLib)
        AppsFlyerLib.shared().continue(userActivity, restorationHandler: nil)
        #endif
    }
}

#if canImport(AppsFlyerLib)
/// Delegate target for the AppsFlyer SDK. Separate from the enum above because
/// the SDK protocols are `@objc` and need a retained NSObject.
final class AppsFlyerBridge: NSObject, AppsFlyerLibDelegate, AppsFlyerDeepLinkDelegate {

    static let shared = AppsFlyerBridge()

    private var didStart = false

    @objc func applicationDidBecomeActive() {
        // start() is idempotent on the SDK side, but the app foregrounds many
        // times a day and each call re-sends a session.
        guard !didStart else { return }
        didStart = true
        AppsFlyerLib.shared().start()
    }

    // MARK: - Install attribution

    func onConversionDataSuccess(_ data: [AnyHashable: Any]) {
        // "Organic" is AppsFlyer telling us it found no click. Recording
        // nothing lets AcquisitionAttribution's own organic finalizer own that
        // decision, which is where the 8-second look-before-you-write window
        // lives.
        let status = data["af_status"] as? String
        guard status?.caseInsensitiveCompare("Non-organic") == .orderedSame else { return }

        let mediaSource = data["media_source"] as? String
        let channel = AcquisitionChannel.from(sourceString: mediaSource)

        AcquisitionAttribution.shared.record(
            channel: channel == .unknown ? .ownedDeeplink : channel,
            source: mediaSource ?? "appsflyer",
            campaign: data["campaign"] as? String,
            adGroup: (data["adset"] as? String) ?? (data["af_adset"] as? String),
            creative: (data["af_ad"] as? String) ?? (data["af_ad_id"] as? String),
            keyword: (data["af_keywords"] as? String) ?? (data["keyword"] as? String)
        )

        applyOnboardingVariant(from: data)
    }

    func onConversionDataFail(_ error: Error) {
        // Deliberately silent beyond the log: a failed conversion lookup must
        // not write a channel, or the failure itself becomes an attribution.
        print("⚠️ AppsFlyer conversion data failed: \(error.localizedDescription)")
    }

    // MARK: - Deep links (OneLink)

    func didResolveDeepLink(_ result: DeepLinkResult) {
        guard result.status == .found, let deepLink = result.deepLink else { return }
        applyOnboardingVariant(from: deepLink.clickEvent)

        if let url = deepLink.clickEvent["link"] as? String, let parsed = URL(string: url) {
            AcquisitionAttribution.shared.recordDeepLink(parsed, source: "appsflyer_onelink")
        }
    }

    /// Routes the ad's onboarding arm into the same override every other source
    /// funnels through (`docs/AD_ONBOARDING_ROUTING.md`). OneLink can carry the
    /// value as a custom parameter or as the reserved `deep_link_value`, so
    /// both spellings are read.
    private func applyOnboardingVariant(from data: [AnyHashable: Any]) {
        let variant = (data["ob"] as? String)
            ?? (data["deep_link_value"] as? String)
            ?? (data["deep_link_sub1"] as? String)
        guard let variant = variant else { return }
        SubscriptionStore.assignOnboardingVariantFromAd(variant, source: "ad")
    }
}
#endif
