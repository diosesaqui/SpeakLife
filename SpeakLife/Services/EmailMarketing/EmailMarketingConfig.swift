//
//  EmailMarketingConfig.swift
//  SpeakLife
//
//  Configuration for email marketing services
//

import Foundation
import FirebaseRemoteConfig

class EmailMarketingConfig {
    static let shared = EmailMarketingConfig()
    
    private let remoteConfig = RemoteConfig.remoteConfig()
    private let userDefaults = UserDefaults.standard
    
    private init() {
        setupRemoteConfig()
    }
    
    private func setupRemoteConfig() {
        let settings = RemoteConfigSettings()
        settings.minimumFetchInterval = 3600 // 1 hour
        remoteConfig.configSettings = settings
        
        // Set default values
        remoteConfig.setDefaults([
            "email_provider": "mailchimp" as NSObject,
            "email_list_enabled": true as NSObject
        ])
    }
    
    func fetchConfig() async {
        do {
            let status = try await remoteConfig.fetch()
            if status == .success {
                try await remoteConfig.activate()
            }
        } catch {
            print("Error fetching remote config: \(error)")
        }
    }
    
    var provider: String {
        remoteConfig["email_provider"].stringValue ?? "mailchimp"
    }
    
    var isEmailListEnabled: Bool {
        remoteConfig["email_list_enabled"].boolValue
    }
    
    var mailchimpAPIKey: String? {
        // In production, use Keychain or secure storage
        // For development, can use environment variables or plist
        if let apiKey = ProcessInfo.processInfo.environment["MAILCHIMP_API_KEY"] {
            return apiKey
        }
        
        // Check if stored in a secure configuration file (not in git)
        if let path = Bundle.main.path(forResource: "EmailConfig", ofType: "plist"),
           let config = NSDictionary(contentsOfFile: path),
           let apiKey = config["MailchimpAPIKey"] as? String {
            return apiKey
        }
        
        return nil
    }
    
    var mailchimpListId: String? {
        if let listId = ProcessInfo.processInfo.environment["MAILCHIMP_LIST_ID"] {
            return listId
        }
        
        if let path = Bundle.main.path(forResource: "EmailConfig", ofType: "plist"),
           let config = NSDictionary(contentsOfFile: path),
           let listId = config["MailchimpListId"] as? String {
            return listId
        }
        
        return nil
    }
    
    var convertKitAPIKey: String? {
        ProcessInfo.processInfo.environment["CONVERTKIT_API_KEY"]
    }
    
    var convertKitFormId: String? {
        ProcessInfo.processInfo.environment["CONVERTKIT_FORM_ID"]
    }
    
    var sendGridAPIKey: String? {
        ProcessInfo.processInfo.environment["SENDGRID_API_KEY"]
    }
}