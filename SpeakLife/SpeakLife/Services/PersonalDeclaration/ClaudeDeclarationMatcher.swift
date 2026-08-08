//
//  ClaudeDeclarationMatcher.swift
//  SpeakLife
//
//  Generates a personalized declaration and Bible verse from the user's
//  free-form prayer need by calling the `declarationMatch` Firebase Cloud
//  Function. That function holds the Anthropic key in Secret Manager, owns the
//  declaration-writing rules, and rate-limits per user — the device never sees
//  the key. Falls back to KeywordDeclarationMatcher on any failure, so a
//  network blip, a rate limit, or a bad generation still yields a declaration.
//

import Foundation
import FirebaseAnalytics

final class ClaudeDeclarationMatcher: DeclarationMatcherProtocol {
    private let fallback: KeywordDeclarationMatcher
    private let session: URLSession

    init(fallback: KeywordDeclarationMatcher = KeywordDeclarationMatcher(),
         session: URLSession = .shared) {
        self.fallback = fallback
        self.session = session
    }

    // MARK: - DeclarationMatcherProtocol

    func match(input: String) async -> DeclarationMatch {
        do {
            let result = try await callDeclarationMatch(input: input)
            print("✅ [Claude] Match succeeded, category: \(result.category.rawValue)")
            AnalyticsService.shared.track("claude_success", parameters: ["category": result.category.rawValue])
            return result
        } catch ClaudeError.rateLimited {
            // The daily cap is a normal, expected outcome — not an error state.
            // Keyword matching covers it silently, tagged so it's separable in
            // analytics from real failures.
            print("⏳ [Claude] Rate limited — falling back to keyword matcher")
            AnalyticsService.shared.track("claude_fallback", parameters: ["reason": "rate_limited"])
            return await fallback.match(input: input)
        } catch {
            print("❌ [Claude] Error: \(error) — falling back to keyword matcher")
            AnalyticsService.shared.track("claude_fallback", parameters: ["reason": "\(error)"])
            return await fallback.match(input: input)
        }
    }

    /// Keyword scan stays local — fast, no network needed for multi-topic detection.
    func matchAll(input: String) -> [DeclarationCategory] {
        fallback.matchAll(input: input)
    }

    // MARK: - Private

    private func callDeclarationMatch(input: String) async throws -> DeclarationMatch {
        var request = URLRequest(url: AnthropicConfig.endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15

        // Same identity Bible Chat keys its metering off, so one person's usage
        // is one row regardless of which AI surface they hit.
        let payload: [String: Any] = [
            "appUserId": RevenueCatManager.shared.appUserID,
            "input": input
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw ClaudeError.httpError(statusCode: 0)
        }
        print("📡 [Claude] HTTP status: \(http.statusCode)")

        if http.statusCode == 429 { throw ClaudeError.rateLimited }

        guard http.statusCode == 200 else {
            // Status code only. Never log the response body — it can echo request
            // metadata into Firebase Analytics.
            AnalyticsService.shared.track("claude_http_error", parameters: ["status": http.statusCode])
            throw ClaudeError.httpError(statusCode: http.statusCode)
        }

        let parsed = try JSONDecoder().decode(DeclarationJSON.self, from: data)
        let category = DeclarationCategory(rawValue: parsed.category) ?? .faith
        return DeclarationMatch(
            category: category,
            declarationText: parsed.declarationText,
            verse: parsed.verseText,
            verseReference: parsed.verseReference,
            isConfident: true
        )
    }
}

// MARK: - Supporting Types

private enum ClaudeError: Error {
    case httpError(statusCode: Int)
    case rateLimited
}

/// The function's success envelope. It returns the declaration fields flat at
/// the top level (plus `remainingToday` and `usage`, which the client ignores),
/// so there's no Anthropic response shape left to unwrap on device.
private struct DeclarationJSON: Decodable {
    let category: String
    let declarationText: String
    let verseText: String
    let verseReference: String
}
