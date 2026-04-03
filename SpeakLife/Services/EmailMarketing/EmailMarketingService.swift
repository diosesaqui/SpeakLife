//
//  EmailMarketingService.swift
//  SpeakLife
//

import Foundation
import FirebaseAuth
import FirebaseFirestore

// MARK: - Error Types

enum EmailMarketingError: LocalizedError {
    case invalidEmail
    case missingConfiguration
    case invalidURL
    case apiError
    case databaseNotConfigured
    case timeout

    var errorDescription: String? {
        switch self {
        case .invalidEmail:           return "Invalid email address"
        case .missingConfiguration:   return "Email service not configured"
        case .invalidURL:             return "Invalid service URL"
        case .apiError:               return "Email service error"
        case .databaseNotConfigured:  return "Firestore database not configured"
        case .timeout:                return "Request timed out. Please check your connection and try again."
        }
    }
}

// MARK: - Service

class EmailMarketingService: ObservableObject {
    static let shared = EmailMarketingService()

    private let db = Firestore.firestore(database: "speaklife")

    // Klaviyo config — loaded from EmailConfig.plist
    private var klaviyoPrivateKey: String = ""
    private var klaviyoListId: String = ""
    private let klaviyoBaseURL = "https://a.klaviyo.com"
    private let klaviyoRevision = "2024-10-15"

    init() {
        loadKlaviyoConfig()
    }

    // MARK: - Config

    private func loadKlaviyoConfig() {
        guard let path = Bundle.main.path(forResource: "EmailConfig", ofType: "plist"),
              let config = NSDictionary(contentsOfFile: path) else {
            print("⚠️ EmailConfig.plist not found — Klaviyo sync disabled")
            return
        }
        klaviyoPrivateKey = config["KlaviyoPrivateKey"] as? String ?? ""
        klaviyoListId     = config["KlaviyoListId"]     as? String ?? ""
    }

    // MARK: - Public API

    func addSubscriber(email: String, firstName: String? = nil, source: String = "ios_app") async throws {
        let normalizedEmail = email.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        guard isValidEmail(normalizedEmail) else {
            throw EmailMarketingError.invalidEmail
        }

        let userId = Auth.auth().currentUser?.uid

        // 1. Save to Firebase (source of truth)
        try await saveToFirebase(email: normalizedEmail, source: source, firstName: firstName)

        // 2. Sync to Klaviyo (non-blocking — Firebase save already succeeded)
        guard !klaviyoPrivateKey.isEmpty && !klaviyoListId.isEmpty else { return }

        do {
            let profileId = try await createOrUpdateKlaviyoProfile(
                email: normalizedEmail,
                firstName: firstName,
                source: source,
                userId: userId
            )
            try await addKlaviyoProfileToList(profileId: profileId)
            print("✅ Klaviyo sync successful for \(normalizedEmail)")
        } catch {
            print("⚠️ Klaviyo sync failed (Firebase save OK): \(error.localizedDescription)")
        }
    }

    // MARK: - Firebase

    private func saveToFirebase(email: String, source: String, firstName: String? = nil) async throws {
        let userId = Auth.auth().currentUser?.uid
        let documentId = userId ?? email
            .replacingOccurrences(of: ".", with: "_")
            .replacingOccurrences(of: "@", with: "_at_")

        var data: [String: Any] = [
            "email": email,
            "timestamp": Timestamp(date: Date()),
            "source": source,
            "platform": "iOS",
            "app_version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        ]
        if let uid = userId       { data["user_id"]    = uid }
        if let name = firstName, !name.isEmpty { data["first_name"] = name }

        try await db.collection("email_list").document(documentId).setData(data)
        print("✅ Email saved to Firebase — doc: \(documentId)")
    }

    // MARK: - Klaviyo

    private func createOrUpdateKlaviyoProfile(
        email: String,
        firstName: String?,
        source: String,
        userId: String?
    ) async throws -> String {
        let url = URL(string: "\(klaviyoBaseURL)/api/profiles/")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Klaviyo-API-Key \(klaviyoPrivateKey)", forHTTPHeaderField: "Authorization")
        request.setValue(klaviyoRevision,    forHTTPHeaderField: "revision")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var props: [String: Any] = [
            "source": source,
            "platform": "iOS",
            "app_version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        ]
        if let uid = userId { props["firebase_uid"] = uid }

        var attributes: [String: Any] = ["email": email, "properties": props]
        if let name = firstName, !name.isEmpty { attributes["first_name"] = name }

        let body: [String: Any] = ["data": ["type": "profile", "attributes": attributes]]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0

        if statusCode == 201,
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let dataObj = json["data"] as? [String: Any],
           let id = dataObj["id"] as? String {
            return id
        }

        if statusCode == 409,
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let errors = json["errors"] as? [[String: Any]],
           let meta = errors.first?["meta"] as? [String: Any],
           let duplicateId = meta["duplicate_profile_id"] as? String {
            try? await updateKlaviyoProfile(id: duplicateId, source: source, userId: userId)
            return duplicateId
        }

        throw EmailMarketingError.apiError
    }

    private func updateKlaviyoProfile(id: String, source: String, userId: String?) async throws {
        let url = URL(string: "\(klaviyoBaseURL)/api/profiles/\(id)/")!
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("Klaviyo-API-Key \(klaviyoPrivateKey)", forHTTPHeaderField: "Authorization")
        request.setValue(klaviyoRevision,    forHTTPHeaderField: "revision")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var props: [String: Any] = ["source": source]
        if let uid = userId { props["firebase_uid"] = uid }

        let body: [String: Any] = [
            "data": ["type": "profile", "id": id, "attributes": ["properties": props]]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        _ = try await URLSession.shared.data(for: request)
    }

    private func addKlaviyoProfileToList(profileId: String) async throws {
        let url = URL(string: "\(klaviyoBaseURL)/api/lists/\(klaviyoListId)/relationships/profiles/")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Klaviyo-API-Key \(klaviyoPrivateKey)", forHTTPHeaderField: "Authorization")
        request.setValue(klaviyoRevision,    forHTTPHeaderField: "revision")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = ["data": [["type": "profile", "id": profileId]]]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (_, response) = try await URLSession.shared.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0

        // 200 = added, 204 = already in list — both are fine
        guard [200, 204].contains(statusCode) else {
            throw EmailMarketingError.apiError
        }
    }

    // MARK: - Validation

    private func isValidEmail(_ email: String) -> Bool {
        let pattern = #"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$"#
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              trimmed.count >= 5,
              trimmed.count <= 254,
              !trimmed.hasPrefix("."),
              !trimmed.hasSuffix("."),
              !trimmed.contains(".."),
              trimmed.filter({ $0 == "@" }).count == 1 else { return false }
        return trimmed.range(of: pattern, options: .regularExpression) != nil
    }
}
