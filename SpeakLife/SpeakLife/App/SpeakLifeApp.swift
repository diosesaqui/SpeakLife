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
    
    // Notification handling state
    @State private var notificationJustReceived = false
    @State private var isFirstAppear = true
    
    // Track if this is the very first launch of the app
    @AppStorage("hasLaunchedBefore") private var hasLaunchedBefore = false
    
    private let fourDaysInSeconds: Double = 345600
    
    var body: some Scene {
        WindowGroup {
            HomeView(isShowingLanding: $isShowingLanding)
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
                    
                    viewModel.requestPermission() { accepted in
                        if accepted {
                            appDelegate.initializeTikTokSDK()
                        }
                    }
                    
                    // Check if this is the first launch or if user has music enabled
                    if !hasLaunchedBefore {
                        // First launch - automatically start background music
                        declarationStore.backgroundMusicEnabled = true
                        AudioPlayerService.shared.playSound(files: resources)
                        hasLaunchedBefore = true
                        print("🎵 First launch detected - starting background music")
                    } else if declarationStore.backgroundMusicEnabled {
                        // Subsequent launches - respect user's saved preference
                        AudioPlayerService.shared.playSound(files: resources)
                        print("🎵 Background music enabled - starting playback")
                    }
                    
                    // 🚀 Initialize AI services and train initial models
                    Task {
                        await CreateMLTrainingPipeline.shared.trainInitialModels()
                    }
                    // Handle landing page and initial category selection
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        withAnimation {
                            isShowingLanding = false
                        }
                        
                        // Auto-select category for non-onboarded users
                        // Skip if notification was just received
                        if !appState.isOnboarded && !notificationJustReceived {
                            print("⚠️ Auto-selecting category for non-onboarded user")
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
                print("📲 App became active")
                
                // Set up app state references
                appDelegate.appState = appState
                appDelegate.declarationStore = declarationStore
                appDelegate.tabViewModel = tabViewModel
                StreakIntegrationManager.shared.setStreakViewModel(enhancedStreakViewModel)
                
                // Process any pending widget actions when app becomes active
                WidgetDataBridge.shared.processPendingWidgetActions()
                
//                if declarationStore.backgroundMusicEnabled && !AudioPlayerViewModel.hasActiveAudio {
//                              DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
//                                  AudioPlayerService.shared.resumeOrStartMusic(files: resources)
//                    }
               // }

                
                // Don't automatically resume/start music when coming from background
                // Music should only start from explicit user actions or app launch
                // This prevents unwanted music playback when app becomes active
                print("📲 App active - music auto-resume disabled to prevent unwanted playback")
                    
                if appState.notificationEnabled {
                    // Ensure checklist notifications are scheduled (they repeat daily)
                    NotificationManager.shared.scheduleChecklistNotifications()
                }
                
               
                // update for next four days
                if appState.lastNotificationSetDate < appState.lastNotificationSetDate.addingTimeInterval(fourDaysInSeconds), appState.notificationEnabled {
                    
                    resetNotifications()
        
                    }
            case .inactive:
                // Don't pause background music when app becomes inactive
                // This allows music to continue when notification center/control center is opened
                break
            case .background:
                // Reset session tracking when app goes to background
                PaywallTriggerManager.shared.resetSessionTracking()
                
                // Stop music completely
                AudioPlayerService.shared.stopMusic()
                print("⏹️ Stopped music to prevent background playback")
                
                // Deactivate audio session to ensure no background audio can play
                if !AudioPlayerViewModel.hasActiveAudio {
                    do {
                        try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
                        print("🔇 Audio session deactivated for background")
                    } catch {
                        print("❌ Failed to deactivate audio session: \(error)")
                    }
                }
                break
            @unknown default:
                break
            }
        }
    }

    
    // MARK: - Notification Setup
    
    private func setupNotificationHandling() {
        print("🚀 Setting up notification handling")
        
        NotificationHandler.shared.callback = { content in
            
            DispatchQueue.main.async {
                self.handleNotificationContent(content)
            }
        }
    }
    
    private func handleNotificationContent(_ content: UNNotificationContent) {
        print("📱 Processing notification: \(content.body.prefix(50))...")
        
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
            print("📱 Affirmation notification - category: \(category)")
            // Set the declaration in the store
            declarationStore.setDeclaration(content.body, category: category)
        } else {
            print("📱 Non-affirmation notification (reminder/checklist) - opening app only")
            // Just open the app without displaying as affirmation
        }
    }
    
    private func resetNotifications() {
        let categories = Set(appState.selectedNotificationCategories.components(separatedBy: ",").compactMap({ DeclarationCategory($0) }))
        NotificationManager.shared.registerNotifications(count: appState.notificationCount, startTime: appState.startTimeIndex, endTime: appState.endTimeIndex, categories: categories)
        DispatchQueue.main.async {
            appState.lastNotificationSetDate = Date()
        }
    }
    
    func scheduleReminderNotification() {
        // Step 1: Cancel existing notification
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["appReminder"])
        
        // refresh these every 3 months - next april 2024 RWRW
        
        let title: [String] = ["Nurture Your Mind Garden!", "Time for Mental Fitness!", "Daily Dose of Positivity!", "Set Your Mind's Intention!", "Paint Today with Positivity!", "Recipe for a Great Day!", "Building a Positive Day!", "Elevate Your Day!", "Unleash Your Inner Strength!", "Focus Your Positivity Lens!"]
        
        let body: [String] = ["Just like a garden needs daily watering to grow, your mind needs positive affirmations to flourish. Nurture your thoughts today!", "Think of affirmations as mental push-ups. They strengthen your mind just like exercises strengthen your body. Time for your daily mental workout!", "Affirmations are like vitamins for your soul, providing essential nutrients for a healthy mindset. Don't forget your daily dose of positivity!", "Every great song needs a repeat to become a favorite. Repeat your affirmations like a catchy chorus to make positivity stick in your mind.", "Affirmations are the compass of your mind, guiding you through the day. Set your course with some positive direction this morning!", "Your mind is a canvas, and affirmations are the brushstrokes of positivity. Paint a beautiful picture for your day ahead!", "Affirmations are like ingredients for a successful day. Mix in some positivity to cook up a great day ahead!", "Just as a house needs a solid foundation, your day needs a base of positive affirmations. Build your day on a strong, positive note!", "Affirmations are like focusing a camera lens. They help clear the blur and bring the positive into focus. Time to get your mind in focus with today’s affirmation!"]

        // Step 2: Create new content for the notification
        let content = UNMutableNotificationContent()
        content.title = title.randomElement()!
        content.body = body.randomElement()!

        // Set the trigger for 4 days (96 hours)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: (96 * 60 * 60), repeats: false)

        // Create the request with the same identifier
        let request = UNNotificationRequest(identifier: "appReminder", content: content, trigger: trigger)

        // Schedule the new request with the system
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                // Handle any errors.
                print("Error scheduling notification: \(error)")
            }
        }
    }
}
