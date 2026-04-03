//
//  FirebaseInitializer.swift
//  SpeakLife
//
//  Handles Firebase initialization to prevent crashes on iOS 17+
//

import Foundation
import FirebaseCore

class FirebaseInitializer {
    static let shared = FirebaseInitializer()
    private var isConfigured = false
    private let configurationQueue = DispatchQueue(label: "com.speaklife.firebase.config")
    
    private init() {}
    
    func configure() {
        configurationQueue.sync {
            guard !isConfigured else { return }
            guard FirebaseApp.app() == nil else {
                isConfigured = true
                return
            }
            
            // Configure Firebase on main thread to avoid crashes
            if Thread.isMainThread {
                FirebaseApp.configure()
            } else {
                DispatchQueue.main.sync {
                    FirebaseApp.configure()
                }
            }
            
            isConfigured = true
            print("✅ Firebase configured successfully")
        }
    }
    
    var isFirebaseConfigured: Bool {
        return FirebaseApp.app() != nil
    }
}