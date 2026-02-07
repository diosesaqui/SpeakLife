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
import TikTokBusinessSDK

final class AppDelegate: NSObject, MessagingDelegate {
    
    var appState: AppState?
    var declarationStore: DeclarationViewModel?
    var tabViewModel: TabViewModel?
    var updateAppState: (() -> Void)?
    
    override init() {
        FirebaseApp.configure()
    }
    
    // Initialize TikTok SDK after ATT permission is handled
    func initializeTikTokSDK() {
        // Run on background queue to avoid blocking UI
        DispatchQueue.global(qos: .background).async {
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
    }
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        registerNotificationHandler()
        NotificationManager.shared.checkForLowReminders()
        ApplicationDelegate.shared.application(
            application,
            didFinishLaunchingWithOptions: launchOptions
        )
        
        Messaging.messaging().delegate = self
        let settings = RemoteConfigSettings()
        #if DEBUG
        settings.minimumFetchInterval = 0
        #else
        settings.minimumFetchInterval = 3600 * 5
        #endif
        RemoteConfig.remoteConfig().configSettings = settings
       
        
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
        
        // Register FCM for onboarded users (including migration for existing users)
        let hasMigratedFCM = UserDefaults.standard.bool(forKey: "hasMigratedToFCM")
        if appState?.isOnboarded ?? false {
            registerForPushNotifications()
            if !hasMigratedFCM {
                UserDefaults.standard.set(true, forKey: "hasMigratedToFCM")
            }
        }        
        return true
    }
    
    func registerForPushNotifications() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            if settings.authorizationStatus == .authorized {
                // Already authorized - just register for remote notifications
                DispatchQueue.main.async {
                    print("✅ Already authorized - registering for FCM Token")
                    UIApplication.shared.registerForRemoteNotifications()
                }
            } else if settings.authorizationStatus == .notDetermined {
                // First time - request authorization
                UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
                    if granted {
                        DispatchQueue.main.async {
                            print("✅ Permission granted - registering for FCM Token")
                            UIApplication.shared.registerForRemoteNotifications()
                        }
                    } else {
                        print("🔴 Push notifications permission denied: \(error?.localizedDescription ?? "No error")")
                    }
                }
            } else {
            }
        }
    }
    
   
    
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        if let token = fcmToken {
                   print("✅ FCM Token: \(token)") // This should now appear in Xcode logs
               } else {
               }
    }
    
    // Removed duplicate didReceive - now handled in extension
    
    func application(
            _ app: UIApplication,
            open url: URL,
            options: [UIApplication.OpenURLOptionsKey : Any] = [:]
        ) -> Bool {
            ApplicationDelegate.shared.application(
                app,
                open: url,
                sourceApplication: options[UIApplication.OpenURLOptionsKey.sourceApplication] as? String,
                annotation: options[UIApplication.OpenURLOptionsKey.annotation]
            )
        }
    
    private func registerNotificationHandler() {
        // Set AppDelegate as the notification delegate to handle both foreground and background scenarios
        UNUserNotificationCenter.current().delegate = self
    }
    
    
    private func registerBGTask() {
        
        BGTaskScheduler.shared.register(forTaskWithIdentifier: "com.speaklife.updateNotificationContent", using: nil) { task in
            self.updateNotificationContent(task: task as! BGAppRefreshTask)
        }
    }
    
    @objc func scheduleNotificationRequest()  {
        scheduleNotificationRequestWithInterval(true)
        scheduleNotificationRequestWithInterval()
    }
    
    func scheduleNotificationRequestWithInterval(_ resyncNow: Bool = false) {
    
        let now = TimeInterval(1)
        let sixHours = TimeInterval(6 * 60 * 60)
        
        let request = BGAppRefreshTaskRequest(identifier: "com.speaklife.updateNotificationContent")
        request.earliestBeginDate = Date(timeIntervalSinceNow: resyncNow ? now : sixHours)

        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("Could not schedule notification cleaning: \(error)")
        }

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
        let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
           print("✅ Successfully registered for APNs with token: \(tokenString)")
        Messaging.messaging().apnsToken = deviceToken
    
    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
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
