//
//  EmailMarketingService.swift
//  SpeakLife
//
//  Email marketing service integration for managing email lists and campaigns
//

import Foundation
import FirebaseFirestore

enum EmailMarketingProvider {
    case mailchimp
    case convertKit
    case sendGrid
}

protocol EmailMarketingServiceProtocol {
    func addSubscriber(email: String, tags: [String], customFields: [String: Any]) async throws
    func updateSubscriber(email: String, tags: [String], customFields: [String: Any]) async throws
    func unsubscribe(email: String) async throws
    func getSubscriberStatus(email: String) async throws -> SubscriberStatus
    func sendCampaign(to: [String], subject: String, content: String) async throws
}

struct SubscriberStatus {
    let isSubscribed: Bool
    let tags: [String]
    let dateAdded: Date?
    let customFields: [String: Any]
}

class EmailMarketingService: ObservableObject {
    static let shared = EmailMarketingService()
    
    private let provider: EmailMarketingProvider = .mailchimp
    private var apiKey: String = ""
    private var listId: String = ""
    private var audienceId: String = ""
    
    private var baseURL: String = ""
    // Use the specific 'speaklife' database instead of default
    private let db = Firestore.firestore(database: "speaklife")
    
    init() {
//        switch provider {
//        case .mailchimp:
//            baseURL = "https://us1.api.mailchimp.com/3.0"
//            loadMailchimpConfig()
//        case .convertKit:
//            baseURL = "https://api.convertkit.com/v3"
//            loadConvertKitConfig()
//        case .sendGrid:
//            baseURL = "https://api.sendgrid.com/v3"
//            loadSendGridConfig()
//        }
    }
    
    private func loadMailchimpConfig() {
        // First try to load from plist file
        if let path = Bundle.main.path(forResource: "EmailConfig", ofType: "plist"),
           let config = NSDictionary(contentsOfFile: path) {
            apiKey = config["MailchimpAPIKey"] as? String ?? ""
            listId = config["MailchimpListId"] as? String ?? ""
            
            if let dataCenter = config["MailchimpDataCenter"] as? String {
                // Update baseURL with correct data center
                baseURL = "https://\(dataCenter).api.mailchimp.com/3.0"
            }
        }
        
        // Fall back to environment variables if plist not found
        if apiKey.isEmpty {
            apiKey = ProcessInfo.processInfo.environment["MAILCHIMP_API_KEY"] ?? ""
        }
        if listId.isEmpty {
            listId = ProcessInfo.processInfo.environment["MAILCHIMP_LIST_ID"] ?? ""
        }
        
        audienceId = listId // Audience ID is same as List ID in Mailchimp
    }
    
    private func loadConvertKitConfig() {
        // Load from plist file
        if let path = Bundle.main.path(forResource: "EmailConfig", ofType: "plist"),
           let config = NSDictionary(contentsOfFile: path) {
            apiKey = config["ConvertKitAPIKey"] as? String ?? ""
            listId = config["ConvertKitFormId"] as? String ?? ""
        }
        
        // Fall back to environment variables
        if apiKey.isEmpty {
            apiKey = ProcessInfo.processInfo.environment["CONVERTKIT_API_KEY"] ?? ""
        }
        if listId.isEmpty {
            listId = ProcessInfo.processInfo.environment["CONVERTKIT_FORM_ID"] ?? ""
        }
    }
    
    private func loadSendGridConfig() {
        // Load from plist file
        if let path = Bundle.main.path(forResource: "EmailConfig", ofType: "plist"),
           let config = NSDictionary(contentsOfFile: path) {
            apiKey = config["SendGridAPIKey"] as? String ?? ""
            listId = config["SendGridListId"] as? String ?? ""
        }
        
        // Fall back to environment variables
        if apiKey.isEmpty {
            apiKey = ProcessInfo.processInfo.environment["SENDGRID_API_KEY"] ?? ""
        }
        if listId.isEmpty {
            listId = ProcessInfo.processInfo.environment["SENDGRID_LIST_ID"] ?? ""
        }
    }
    
    func addSubscriber(email: String, firstName: String? = nil, source: String = "ios_app") async throws {
        let normalizedEmail = email.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard isValidEmail(normalizedEmail) else {
            throw EmailMarketingError.invalidEmail
        }
        
        // Always save to Firebase first
        try await saveToFirebase(email: normalizedEmail, source: source, firstName: firstName)
        
        // Then try to add to email marketing service if configured
        // Don't throw error if not configured - just skip
  //      do {
//            switch provider {
//            case .mailchimp:
//                if !apiKey.isEmpty && !listId.isEmpty {
//                    try await addToMailchimp(email: normalizedEmail, firstName: firstName, source: source)
//                } else {
//                    print("Mailchimp not configured - saved to Firebase only")
//                }
//            case .convertKit:
//                if !apiKey.isEmpty && !listId.isEmpty {
//                    try await addToConvertKit(email: normalizedEmail, firstName: firstName, source: source)
//                } else {
//                    print("ConvertKit not configured - saved to Firebase only")
//                }
//            case .sendGrid:
//                if !apiKey.isEmpty {
//                    try await addToSendGrid(email: normalizedEmail, firstName: firstName, source: source)
//                } else {
//                    print("SendGrid not configured - saved to Firebase only")
//                }
//            }
//        } catch {
//            // Log error but don't throw - Firebase save was successful
//            print("Email service error (Firebase save successful): \(error)")
//        }
    }
    
    private func saveToFirebase(email: String, source: String, firstName: String? = nil) async throws {
        print("📧 Attempting to save email to Firebase...")
        print("  - Email: \(email)")
        print("  - Source: \(source)")
        print("  - Collection: email_list")
        
        // Skip duplicate check - let Firestore handle it with security rules
        // The duplicate check requires read permissions which anonymous users don't have
        
        var data: [String: Any] = [
            "email": email,
            "timestamp": Timestamp(date: Date()),
            "source": source,
            "platform": "iOS",
            "app_version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        ]
        
        if let firstName = firstName, !firstName.isEmpty {
            data["first_name"] = firstName
        }
        
        // Use email as document ID (sanitized)
        // This prevents duplicates automatically at database level
        let documentId = email.replacingOccurrences(of: ".", with: "_")
            .replacingOccurrences(of: "@", with: "_at_")
        
        do {
            let docRef = db.collection("email_list").document(documentId)
            
            // Check if document exists (requires read permission)
            // If you want to avoid reads, just use setData and it will overwrite
            // For now, let's just save without checking (cheaper)
            
            // Option 1: Overwrite (cheapest - 1 write only)
            try await docRef.setData(data)
            
            // Option 2: Preserve first signup (uncomment if you prefer)
            // This adds "updated_at" field on duplicates but preserves original timestamp
            // try await docRef.setData([
            //     "updated_at": Timestamp(date: Date()),
            //     "last_source": source
            // ], merge: true)
            
            print("✅ Email saved to Firebase successfully!")
            print("  - Document ID: \(documentId)")
            print("  - Collection: email_list")
        } catch {
            print("❌ Failed to save email to Firebase!")
            print("  - Error: \(error.localizedDescription)")
            print("  - Error details: \(error)")
            throw error
        }
    }
    
    private func addToMailchimp(email: String, firstName: String?, source: String) async throws {
        guard !apiKey.isEmpty && !listId.isEmpty else {
            throw EmailMarketingError.missingConfiguration
        }
        
        let emailHash = email.data(using: .utf8)?.sha256() ?? ""
        let urlString = "\(baseURL)/lists/\(listId)/members/\(emailHash)"
        
        guard let url = URL(string: urlString) else {
            throw EmailMarketingError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let body: [String: Any] = [
            "email_address": email,
            "status": "subscribed",
            "merge_fields": [
                "FNAME": firstName ?? "",
                "SOURCE": source
            ],
            "tags": ["ios_app", "speaklife"]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw EmailMarketingError.apiError
        }
    }
    
    private func addToConvertKit(email: String, firstName: String?, source: String) async throws {
        // ConvertKit implementation
        let urlString = "\(baseURL)/forms/\(listId)/subscribe"
        guard let url = URL(string: urlString) else {
            throw EmailMarketingError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "api_key": apiKey,
            "email": email,
            "first_name": firstName ?? "",
            "tags": ["ios_app", source]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw EmailMarketingError.apiError
        }
    }
    
    private func addToSendGrid(email: String, firstName: String?, source: String) async throws {
        // SendGrid implementation
        let urlString = "\(baseURL)/marketing/contacts"
        guard let url = URL(string: urlString) else {
            throw EmailMarketingError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let body: [String: Any] = [
            "list_ids": [listId],
            "contacts": [[
                "email": email,
                "first_name": firstName ?? "",
                "custom_fields": [
                    "source": source,
                    "platform": "ios"
                ]
            ]]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw EmailMarketingError.apiError
        }
    }
    
    func unsubscribe(email: String) async throws {
        let normalizedEmail = email.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        switch provider {
        case .mailchimp:
            let emailHash = normalizedEmail.data(using: .utf8)?.sha256() ?? ""
            let urlString = "\(baseURL)/lists/\(listId)/members/\(emailHash)"
            
            guard let url = URL(string: urlString) else {
                throw EmailMarketingError.invalidURL
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "PATCH"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            
            let body = ["status": "unsubscribed"]
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            
            let (_, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                throw EmailMarketingError.apiError
            }
            
        default:
            throw EmailMarketingError.notImplemented
        }
    }
    
    private func isValidEmail(_ email: String) -> Bool {
        // More robust email validation
        // Allows: letters, numbers, dots, hyphens, underscores before @
        // Requires: @ symbol, domain with at least one dot
        let pattern = #"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$"#
        
        // Additional checks
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Check basic requirements
        guard !trimmed.isEmpty,
              trimmed.count >= 5, // Minimum: a@b.c
              trimmed.count <= 254, // RFC 5321 max email length
              !trimmed.hasPrefix("."),
              !trimmed.hasSuffix("."),
              !trimmed.contains(".."),
              trimmed.filter({ $0 == "@" }).count == 1 else {
            return false
        }
        
        return trimmed.range(of: pattern, options: .regularExpression) != nil
    }
}

enum EmailMarketingError: LocalizedError {
    case invalidEmail
    case missingConfiguration
    case invalidURL
    case apiError
    case notImplemented
    case databaseNotConfigured
    case timeout
    
    var errorDescription: String? {
        switch self {
        case .invalidEmail:
            return "Invalid email address"
        case .missingConfiguration:
            return "Email service not configured"
        case .invalidURL:
            return "Invalid service URL"
        case .apiError:
            return "Email service error"
        case .notImplemented:
            return "Feature not implemented for this provider"
        case .databaseNotConfigured:
            return "Firestore database not created. Please set up Firestore in Firebase Console."
        case .timeout:
            return "Request timed out. Please check your connection and try again."
        }
    }
}

extension Data {
    func sha256() -> String {
        return self.map { String(format: "%02hhx", $0) }.joined()
    }
}
