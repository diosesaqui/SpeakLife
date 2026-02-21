//
//  NotificationHandler.swift
//  Dios Es Aqui
//
//  Created by Riccardo Washington on 3/10/22.
//

import SwiftUI

extension Notification.Name {
    static let audioVersionUpdated = Notification.Name("audioVersionUpdated")
    static let devotionalVersionUpdated = Notification.Name("devotionalVersionUpdated")
}

/// Handles all notification-related events for the app
/// Supports three scenarios:
/// 1. Cold launch - App not running, launched via notification tap
/// 2. Background - App in background, brought to foreground via notification tap
/// 3. Foreground - App active when notification arrives
final class NotificationHandler: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    
    static let shared = NotificationHandler()
    
    /// Callback to process notification content
    /// Set by SpeakLifeApp on initial launch
    var callback: ((UNNotificationContent) -> Void)? {
        didSet {
            // Process any pending notification when callback is set
            processPendingNotificationIfNeeded()
        }
    }
    
    /// Stores notification content if received before callback is set (cold launch scenario)
    private var pendingNotificationContent: UNNotificationContent?
    
    // MARK: - UNUserNotificationCenterDelegate
    
    /// Called when user taps on a notification
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        
        let content = response.notification.request.content
        
        // Check if this is a daily burst notification
        if content.userInfo["action"] as? String == "daily_declaration_burst" {
            // Handle daily burst notification
            DispatchQueue.main.async {
                DailyDeclarationReminderService.shared.handleNotificationTap()
            }
        } else {
            // Handle other notifications
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                if let callback = self.callback {
                    // Callback exists - process immediately
                    callback(content)
                } else {
                    // No callback yet - store for later (cold launch scenario)
                    self.pendingNotificationContent = content
                }
            }
        }
        
        completionHandler()
    }
    
    // MARK: - Private Methods
    
    private func processPendingNotificationIfNeeded() {
        guard let pending = pendingNotificationContent,
              let callback = callback else { return }
        
        pendingNotificationContent = nil
        
        DispatchQueue.main.async {
            callback(pending)
        }
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {

        let content = notification.request.content
        callback?(content)
        completionHandler([.banner, .sound])
    }
    
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [String : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
      // Handle data message in background.
      print("Message ID: \(userInfo["gcm.message_id"] ?? "")")
      completionHandler(.newData)
    }
}

extension NotificationHandler {
    
    func requestPermission(_ delegate : UNUserNotificationCenterDelegate? = nil ,
            onDeny handler :  (()-> Void)? = nil) {
        
            let center = UNUserNotificationCenter.current()
            
            center.getNotificationSettings(completionHandler: { settings in
            
                if settings.authorizationStatus == .denied {
                    if let handler = handler {
                        handler()
                    }
                    return
                }
                
                if settings.authorizationStatus != .authorized  {
                    center.requestAuthorization(options: [.alert, .sound, .badge]) {
                        _ , error in
                        
                        if let error = error {
                            print("error handling \(error)")
                        }
                    }
                }
                
            })
            center.delegate = delegate ?? self
        }
    
}
