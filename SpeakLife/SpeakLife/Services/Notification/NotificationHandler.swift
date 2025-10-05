//
//  NotificationHandler.swift
//  Dios Es Aqui
//
//  Created by Riccardo Washington on 3/10/22.
//

import SwiftUI

final class NotificationHandler: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    
    static let shared = NotificationHandler()

    var callback: ((UNNotificationContent) -> Void)? {
        didSet {
            // If a callback is set and we have a pending notification, process it immediately
            if let pending = pendingNotificationContent, let callback = callback {
                print("🔔 Processing pending notification: \(pending.body)")
                DispatchQueue.main.async { [weak self] in
                    callback(pending)
                    self?.pendingNotificationContent = nil
                }
            }
        }
    }
    private var pendingNotificationContent: UNNotificationContent?
    
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        
        let content = response.notification.request.content
        print("🔔 NotificationHandler.didReceive called with: \(content.body)")
        
        DispatchQueue.main.async { [weak self] in
            if let callback = self?.callback {
                // If callback is set, call it immediately
                print("🔔 Callback exists, calling immediately")
                callback(content)
            } else {
                // If callback isn't set yet, store the notification for later
                print("🔔 No callback yet, storing notification for later")
                self?.pendingNotificationContent = content
            }
        }
        completionHandler()
        
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
