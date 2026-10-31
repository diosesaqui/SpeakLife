//
//  FirebaseInitializer.swift
//  SpeakLife
//
//  Handles Firebase initialization to prevent crashes on iOS 17+
//

import Foundation
import FirebaseCore
import FirebaseAppCheck
import SpeakLifeCore

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
            
            AppCheckSetup.install()

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

/// Firebase App Check proves a request to our Cloud Functions came from a real
/// install of this app, so the claudeProxy function can refuse scripts that
/// only know its URL. The provider factory must be set before
/// `FirebaseApp.configure()`, which is why both configure call sites run this
/// first.
enum AppCheckSetup {
    private static var installed = false

    static func install() {
        guard !installed else { return }
        installed = true
        #if DEBUG
        // Prints a debug token to the console; register it in the Firebase
        // console (App Check > Apps > Manage debug tokens) to test locally.
        AppCheck.setAppCheckProviderFactory(AppCheckDebugProviderFactory())
        #else
        // DeviceCheck needs no entitlement. Register the app's DeviceCheck key
        // in the Firebase console before the function enforces App Check.
        AppCheck.setAppCheckProviderFactory(DeviceCheckProviderFactory())
        #endif

        AnthropicConfig.appCheckToken = {
            // A missing token is sent as no header; the server decides whether
            // that is allowed (ENFORCE_APP_CHECK).
            try? await AppCheck.appCheck().token(forcingRefresh: false).token
        }
    }
}
