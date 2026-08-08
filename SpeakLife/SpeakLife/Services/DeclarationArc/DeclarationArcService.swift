//
//  DeclarationArcService.swift
//  SpeakLife
//
//  Talks to the `declarationArc` Firebase Cloud Function, which holds the
//  Anthropic key in Secret Manager, narrows the shipped declaration library
//  down to a few hundred candidates, has the model pick and sequence thirty of
//  them, validates every pick against that candidate set, and meters usage.
//  The device never sees the key and never receives generated text — only IDs
//  of declarations it already has.
//
//  Mirrors ClaudeDeclarationMatcher's shape (URLSession, the shared
//  RevenueCat appUserId, status-code-only analytics) with one difference: this
//  never throws. Every failure returns nil, because the caller's answer to any
//  failure is identical — build the keyword arc — and an error type with one
//  handler is ceremony.
//

import Foundation

final class DeclarationArcService: DeclarationArcRemoteSelecting {

    // us-central1 HTTPS function for the speaklife-3e5c4 project. Same
    // emulator switch Bible Chat and the declaration matcher use.
    private static let cloudEndpoint = URL(string: "https://us-central1-speaklife-3e5c4.cloudfunctions.net/declarationArc")!
    private static let emulatorEndpoint = URL(string: "http://127.0.0.1:5001/speaklife-3e5c4/us-central1/declarationArc")!

    private var endpoint: URL {
        BibleChatLocal.usesEmulator ? Self.emulatorEndpoint : Self.cloudEndpoint
    }

    /// Generous, because nothing is waiting on it. The call happens after
    /// onboarding has already completed and the user is in the app; a slow
    /// answer costs nothing but a later write.
    private static let timeout: TimeInterval = 45

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func selectArc(beliefText: String?, profile: SoulProfile?) async -> DeclarationArcSelection? {
        let appUserId = RevenueCatManager.shared.appUserID
        // Purchases.shared traps before configure(); appUserID returns "" in
        // that window. Without an id the server has nothing to meter or rate
        // limit against, so don't call at all — the keyword arc covers it.
        guard !appUserId.isEmpty else {
            AnalyticsService.shared.track("declaration_arc_skipped", parameters: ["reason": "no_app_user_id"])
            return nil
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = Self.timeout

        var payload: [String: Any] = ["appUserId": appUserId]

        if let beliefText = beliefText?.trimmingCharacters(in: .whitespacesAndNewlines),
           !beliefText.isEmpty {
            payload["beliefText"] = beliefText
        }

        // Encoded through SoulProfileFirestoreMirror so there is exactly one
        // definition of the wire shape — `firestorePayload`, not
        // `requestPayload`, because appUserId is already a top-level field
        // here. The server whitelists what it reads and drops the rest.
        if let profile, !profile.isEmpty,
           let encodedProfile = SoulProfileFirestoreMirror.firestorePayload(for: profile) {
            payload["profile"] = encodedProfile
        }

        guard let body = try? JSONSerialization.data(withJSONObject: payload) else { return nil }
        request.httpBody = body

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { return nil }
            guard http.statusCode == 200 else {
                // Status code only. Never log the response body — it can echo
                // request metadata into Firebase Analytics.
                AnalyticsService.shared.track("declaration_arc_http_error", parameters: ["status": http.statusCode])
                return nil
            }
            let decoded = try JSONDecoder().decode(ArcResponse.self, from: data)
            let ids = decoded.declarationIDs.filter { !$0.isEmpty }
            guard !ids.isEmpty else { return nil }
            return DeclarationArcSelection(
                declarationIDs: ids,
                categoryRaw: decoded.categoryRaw
            )
        } catch {
            AnalyticsService.shared.track("declaration_arc_error", parameters: ["reason": "\(type(of: error))"])
            return nil
        }
    }

    /// The function's success envelope. It also returns `source`,
    /// `remainingToday` and `usage`, which the client ignores.
    private struct ArcResponse: Decodable {
        let declarationIDs: [String]
        let categoryRaw: String
    }
}
