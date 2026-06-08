//
//  SpeakLifeApp.swift
//  SpeakLife
//
//  Created by Riccardo Washington on 7/20/22.
//

import SwiftUI
import Combine
import TipKit
import AVFoundation

// MARK: - Notification Handling Documentation
/*
 NOTIFICATION FLOW OVERVIEW:
 
 The app handles notifications in three distinct scenarios:
 
 1. COLD LAUNCH (App not running):
    - User taps notification → App launches
    - AppDelegate registers NotificationHandler as delegate
    - NotificationHandler.didReceive is called BEFORE app UI is ready
    - Notification is stored in pendingNotificationContent
    - SpeakLifeApp.onAppear sets up the callback
    - Callback setter detects pending notification and processes it
    - Declaration is displayed, auto-selection is prevented
 
 2. BACKGROUND TO FOREGROUND (App suspended):
    - User taps notification while app is in background
    - NotificationHandler.didReceive is called
    - Callback already exists from initial launch
    - Notification is processed immediately
    - notificationJustReceived flag prevents auto-selection
    - Declaration is displayed correctly
 
 3. FOREGROUND (App active):
    - Notification arrives while user is using app
    - NotificationHandler.willPresent is called
    - Notification is shown as banner
    - If user taps, didReceive is called and processed normally
 
 KEY FLAGS:
 - notificationJustReceived: Prevents auto-category selection after notification
 - isProcessingNotification: Prevents DeclarationViewModel from overriding selection
 - isFirstAppear: Ensures callback is only set once
 
 TIMING CONSIDERATIONS:
 - 1-second delay for landing page dismissal
 - 0.5-second retry if declarations aren't loaded
 - Flags are reset after appropriate delays to prevent interference
 */

@main
struct SpeakLifeApp: App {
    
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.scenePhase) private var scenePhase
    @StateObject var appState = AppState()
    @StateObject var declarationStore = DeclarationViewModel(apiService: CoreDataAPIService())
    let persistenceController = PersistenceController.shared
    @StateObject var themeStore = ThemeViewModel()
    @StateObject var subscriptionStore = SubscriptionStore()
    @StateObject var devotionalViewModel = DevotionalViewModel()
    @StateObject var streakViewModel = StreakViewModel()
    @StateObject var enhancedStreakViewModel = EnhancedStreakViewModel()
    @StateObject var timerViewModel = TimerViewModel()
    @StateObject private var viewModel = FacebookTrackingViewModel()
    @StateObject private var audioDeclarationViewModel = AudioDeclarationViewModel()
    @StateObject var tabViewModel = TabViewModel()
    
    @State var isShowingLanding = true
    @State private var showDailyBurstOnLaunch = false
    @State private var showDailyStructuredDayOnLaunch = false

    // Notification handling state
    @State private var notificationJustReceived = false
    @State private var isFirstAppear = true
    
    // Track if this is the very first launch of the app
    @AppStorage("hasLaunchedBefore") private var hasLaunchedBefore = false
    
    var body: some Scene {
        WindowGroup {
            HomeView(isShowingLanding: $isShowingLanding, showDailyBurstOnLaunch: $showDailyBurstOnLaunch, showDailyStructuredDayOnLaunch: $showDailyStructuredDayOnLaunch)
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environmentObject(appState)
                .environmentObject(declarationStore)
                .environmentObject(themeStore)
                .environmentObject(subscriptionStore)
                .environmentObject(devotionalViewModel)
                .environmentObject(streakViewModel)
                .environmentObject(enhancedStreakViewModel)
                .environmentObject(timerViewModel)
                .environmentObject(viewModel)
                .environmentObject(audioDeclarationViewModel)
                .environmentObject(tabViewModel)
                .onOpenURL { url in
                    // Ad-matched onboarding: owned channels (email, push, IG bio,
                    // QR, landing page) carrying `ob=<variant>` route here when the
                    // app opens directly (vs. a deferred install link).
                    SubscriptionStore.handleIncomingURL(url, source: "deeplink")
                    if url.absoluteString == "speaklife://event/daily-declarations" {

                    }
                }
                .onAppear {
                    // Set up notification callback only once on first appear
                    if isFirstAppear {
                        setupNotificationHandling()
                        isFirstAppear = false
                    }
                    
                    // Sync widget data on app launch
                    WidgetDataBridge.shared.syncAllData()
                    
                    // ATT must be requested while the app is in the active state or
                    // iOS silently drops the prompt. Calling it at launch (before
                    // active) was consuming the one-shot request, so the prompt never
                    // appeared during onboarding. Delay briefly so it reliably shows.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        viewModel.requestPermission { accepted in
                            if accepted {
                                appDelegate.initializeTikTokSDK()
                            }
                        }
                    }
                    
                    // Check if this is the first launch or if user has music enabled
                    if !hasLaunchedBefore {
                        // First launch - automatically start background music
                        declarationStore.backgroundMusicEnabled = true
                        AudioPlayerService.shared.playSound(files: resources)
                        hasLaunchedBefore = true
                        // First launch - background music started automatically
                    } else if declarationStore.backgroundMusicEnabled {
                        // Subsequent launches - respect user's saved preference
                        AudioPlayerService.shared.playSound(files: resources)
                        // Background music enabled - starting playback
                    }
                    
                    // 🚀 Initialize AI services and train initial models (deferred to avoid blocking)
                    Task(priority: .background) {
                        // Wait for app to fully initialize before training
                        try? await Task.sleep(nanoseconds: 10_000_000_000) // 10 seconds
                        await CreateMLTrainingPipeline.shared.trainInitialModels()
                    }
                    
                    // Set up daily burst reminders
                    DailyDeclarationReminderService.shared.setupDailyReminders()
                    DailyDeclarationReminderService.setupNotificationActions()
                    
                    // 🧪 Test HelloAO Bible API integration
                    // runHelloAOTest() // Disabled: Test should not run in production
                    // Handle landing page and initial category selection.
                    // Budget aligned with LandingView's sequenced entrance:
                    // glow+icon spring ~0.7s, wordmark letter cascade,
                    // shimmer sweep, tagline, breath, then outgoing fade.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.8) {
                        withAnimation {
                            isShowingLanding = false
                        }

                        // Daily checklist no longer auto-presents on launch — it was
                        // racing notification-tap routing (the popup landed on top of
                        // the deep-linked declaration). Users get a pulsing icon on
                        // the home screen instead, so they can open it on their terms.

                        // Auto-select category for non-onboarded users
                        // Skip if notification was just received
                        if !appState.isOnboarded && !notificationJustReceived {
                            // Auto-selecting category for non-onboarded user
                            let categoryString = appState.selectedNotificationCategories.components(separatedBy: ",").first ?? "destiny"
                            if let category = DeclarationCategory(categoryString) {
                                declarationStore.choose(category) { _ in }
                            }
                        }
                        
                        // Clear notification flag after initial setup
                        notificationJustReceived = false
                    }
    
                        } 
            //    .environmentObject(timeTracker)
        }
        .onChange(of: scenePhase) { (newScenePhase) in
            switch newScenePhase {
            case .active:
                // App became active
                
                // Set up app state references
                appDelegate.appState = appState
                appDelegate.declarationStore = declarationStore
                appDelegate.tabViewModel = tabViewModel
                StreakIntegrationManager.shared.setStreakViewModel(enhancedStreakViewModel)
                
                // Process any pending widget actions when app becomes active
                WidgetDataBridge.shared.processPendingWidgetActions()
                
                // Smart resume background music if enabled and not already playing audio content
                if !AudioPlayerViewModel.hasActiveAudio {
                    if declarationStore.backgroundMusicEnabled {
                        // Try smart resume first, fall back to starting new music only if needed
                        let audioService = AudioPlayerService.shared
                        let wasResumed = audioService.resumeFromBackground()
                        
                        // App became active - audio resume status: \(wasResumed)
                        
                        // Only start fresh if nothing was resumed
                        if !wasResumed {
                            // Add small delay for TestFlight builds to let audio system settle
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                audioService.playSound(files: resources)
                                // Starting fresh background music
                            }
                        }
                    } else {
                        // Stop any lingering background music if disabled
                        let audioService = AudioPlayerService.shared
                        if audioService.isPlaying {
                            // Background music disabled - stopping playback
                            audioService.stopMusic()
                        }
                    }
                } else {
                    // Audio content is playing - not resuming background music
                }
                    
                if appState.notificationEnabled {
                    // Ensure checklist notifications are scheduled (they repeat daily)
                    NotificationManager.shared.scheduleChecklistNotifications()
                }

                // Reset the lapsed re-engagement timer on every foreground (not just
                // cold launch). Without this, a user who background/foregrounds for
                // days never resets lapsed_d5/lapsed_d10, so they fire incorrectly.
                LifecycleNotificationService.shared.onAppOpen()

                // Re-queue the personal declaration daily push every foreground.
                // The trigger is repeats=true, but we've seen iOS drop the request
                // (force-quit, throttling, time-zone change, OS state resets), so
                // a defensive idempotent reschedule on each open guarantees the user
                // gets it daily. Stable identifier means iOS replaces in place — no
                // duplicates queued.
                //
                // NOT gated on appState.notificationEnabled: that flag was only
                // ever set to true by specific onboarding paths and can be left
                // false on users whose onboarding flow didn't hit one of those
                // paths, or who toggled it off in Settings. Meanwhile the daily
                // burst uses an independent key (dailyDeclarationRemindersEnabled),
                // so a user gets burst pushes but no personal declaration push —
                // exactly the "got it for a week, then stopped" failure mode.
                // iOS already silently no-ops add() when permission is denied, so
                // there's no harm in calling unconditionally.
                DIContainer.shared.rescheduleActivePersonalDeclarationIfNeeded(
                    startTimeIndex: appState.personalDeclarationTimeIndex
                )

                // Check if we should show evening reminder for daily burst
                DailyDeclarationReminderService.shared.refreshEveningReminderIfNeeded()
                
               
                // Reschedule only when the current batch is close to running out.
                // NotificationManager owns the threshold (it scales with the actual batch
                // length, since count=10 fits ≤6 days of notifications under iOS's 64-pending
                // cap whereas count=5 fits 10 days). Avoids wiping future notifications on
                // every app open while still keeping the schedule continuous for users who
                // open the app daily.
                if appState.notificationEnabled,
                   NotificationManager.shared.shouldRescheduleBatch {
                    resetNotifications()
                }
            case .inactive:
                // Inactive state happens briefly when transitioning
                // Don't pause here - wait for actual background state
                // App inactive - waiting for background state
                break
            case .background:
                // Reset session tracking when app goes to background
                PaywallTriggerManager.shared.resetSessionTracking()
                
                // Smart pause music with timer - will auto-stop after 15 seconds
                AudioPlayerService.shared.pauseForBackground()
                // App entering background - music paused with auto-stop timer
                
                // Note: We don't deactivate audio session immediately anymore
                // This allows for quick resume if user returns within 15 seconds
                break
            @unknown default:
                break
            }
        }
    }

    
    // MARK: - Notification Setup
    
    private func setupNotificationHandling() {
        // Setting up notification handling
        
        NotificationHandler.shared.callback = { content in
            
            DispatchQueue.main.async {
                self.handleNotificationContent(content)
            }
        }
    }
    
    private func handleNotificationContent(_ content: UNNotificationContent) {
        // Processing notification

        // Prayer wall, streak-at-risk, and streak-complete notifications surface as banners only —
        // never navigate away from whatever tab the user is on.
        let notifType = content.userInfo["notificationType"] as? String
        if notifType == "prayerWall" ||
           notifType == "streakAtRisk" ||
           notifType == "streakComplete" {
            return
        }

        // Deep link routing
        if let deepLink = content.userInfo["deepLink"] as? String {
            switch deepLink {
            case "declarations":
                tabViewModel.selectedTab = 0
                return
            case "personalDeclaration":
                tabViewModel.selectedTab = 0
                appState.scrollToPersonalDeclaration = true
                return
            default:
                break
            }
        }

        // Mark that we just received a notification
        notificationJustReceived = true
        
        // Navigate to appropriate tab
        if content.userInfo["tab"] != nil {
            tabViewModel.goToAudio()
        } else {
            tabViewModel.resetToHome()
        }
        
        // Only treat notifications with category as affirmations
        // Other notifications (reminders, checklist, etc.) should just open the app
        if let category = content.userInfo["category"] as? String {
            // Affirmation notification received
            // Set the declaration in the store
            declarationStore.setDeclaration(content.body, category: category)
        } else {
            // Non-affirmation notification received
            // Just open the app without displaying as affirmation
        }
    }
    
    private func resetNotifications() {
        let parsed = Set(appState.selectedNotificationCategories.components(separatedBy: ",").compactMap({ DeclarationCategory($0) }))
        // If the user hasn't selected any categories yet, pass nil so NotificationManager
        // uses its default curated set (faith, destiny, identity, etc.) rather than
        // pulling from all declarations indiscriminately.
        let categories: Set<DeclarationCategory>? = parsed.isEmpty ? nil : parsed
        NotificationManager.shared.registerNotifications(count: appState.notificationCount, startTime: appState.startTimeIndex, endTime: appState.endTimeIndex, categories: categories)
        DispatchQueue.main.async {
            appState.lastNotificationSetDate = Date()
        }
    }
    
}
