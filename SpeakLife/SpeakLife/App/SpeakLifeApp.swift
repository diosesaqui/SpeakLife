//
//  SpeakLifeApp.swift
//  SpeakLife
//
//  Created by Riccardo Washington on 7/20/22.
//

import SwiftUI
import Combine
import TipKit

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
                    NotificationHandler.shared.callback = { content in
                        DispatchQueue.main.async {
                            tabViewModel.resetToHome()
                            declarationStore.setDeclaration(content.body, category: content.title)
                        }
                    }
                    
                    // Sync widget data on app launch
                    WidgetDataBridge.shared.syncAllData()
                    
                    // Warm up listener metrics cache for better performance
                    ListenerMetricsService.shared.warmUpCache()
                    
                    viewModel.requestPermission()
                    // Start background music if explicitly enabled
                    if declarationStore.backgroundMusicEnabled {
                        AudioPlayerService.shared.playSound(files: resources)
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        withAnimation {
                            isShowingLanding = false
                        }
                        

                            if !appState.isOnboarded {
                                let categoryString = appState.selectedNotificationCategories.components(separatedBy: ",").first ?? "destiny"
                                if let category = DeclarationCategory(categoryString) {
                                    declarationStore.choose(category) { _ in }
                                }
                            }
                        }
    
                        } 
            //    .environmentObject(timeTracker)
        }
        .onChange(of: scenePhase) { (newScenePhase) in
            switch newScenePhase {
            case .active:
                //DispatchQueue.global().async {
                appDelegate.appState = appState
                appDelegate.declarationStore = declarationStore
                appDelegate.tabViewModel = tabViewModel
                StreakIntegrationManager.shared.setStreakViewModel(enhancedStreakViewModel)
                
                // Process any pending widget actions when app becomes active
                WidgetDataBridge.shared.processPendingWidgetActions()
                
                // Resume background music if enabled, not already playing, and no content audio is active
                if declarationStore.backgroundMusicEnabled && 
                   !AudioPlayerService.shared.isPlaying && 
                   !AudioPlayerViewModel.hasActiveAudio {
                    AudioPlayerService.shared.playSound(files: resources)
                }
                    
                if appState.notificationEnabled {
                    // Ensure checklist notifications are scheduled (they repeat daily)
                    NotificationManager.shared.scheduleChecklistNotifications()
                }
                
                //reset for updated versions
//                if appState.notificationEnabled, appState.resetNotifications {
//                    resetNotifications()
//                    appState.resetNotifications.toggle()
//                }
               
                // update for next four days
                if appState.lastNotificationSetDate < appState.lastNotificationSetDate.addingTimeInterval(fourDaysInSeconds), appState.notificationEnabled {
                    
                    resetNotifications()
        
                    }
            case .inactive:
                // Stop background music when app becomes inactive
                AudioPlayerService.shared.pauseMusic()
                break
            case .background:
                // Only pause background music when going to background
                // Content audio should continue playing
                AudioPlayerService.shared.pauseMusic()
                break
            @unknown default:
                break
            }
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
