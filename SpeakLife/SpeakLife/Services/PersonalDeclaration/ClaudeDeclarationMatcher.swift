//
//  ClaudeDeclarationMatcher.swift
//  SpeakLife
//
//  Uses the Anthropic Messages API to generate a personalized declaration and
//  Bible verse from the user's free-form prayer need. Falls back to
//  KeywordDeclarationMatcher when offline or when no API key is configured.
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
        let apiKey = AnthropicConfig.apiKey
        guard !apiKey.isEmpty else {
            print("🔑 [Claude] API key is empty — falling back to keyword matcher")
            AnalyticsService.shared.track("claude_fallback", parameters: ["reason": "no_key"])
            return await fallback.match(input: input)
        }
        print("🔑 [Claude] API key found, prefix: \(String(apiKey.prefix(12)))...")
        do {
            let result = try await callClaude(input: input, apiKey: apiKey)
            print("✅ [Claude] Match succeeded, category: \(result.category.rawValue)")
            AnalyticsService.shared.track("claude_success", parameters: ["category": result.category.rawValue])
            return result
        } catch ClaudeError.declined {
            // Must NOT fall back. A network error means "try the keyword
            // matcher"; a refusal means "do not write for this", and routing it
            // to the fallback would answer a declined request with a written
            // declaration — exactly what the refusal existed to prevent.
            AnalyticsService.shared.track("claude_declined")
            return DeclarationMatch(category: .faith, declarationText: "", verse: "",
                                    verseReference: "", isConfident: false, isDeclined: true)
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

    private func callClaude(input: String, apiKey: String) async throws -> DeclarationMatch {
        var request = URLRequest(url: AnthropicConfig.apiURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.timeoutInterval = 15

        let body = ClaudeRequest(
            model: AnthropicConfig.model,
            maxTokens: 512,
            system: AnthropicConfig.systemPrompt,
            messages: [.init(role: "user", content: "User need: \(input)")]
        )
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse {
            print("📡 [Claude] HTTP status: \(http.statusCode)")
            if http.statusCode != 200 {
                let body = String(data: data, encoding: .utf8) ?? ""
                print("📡 [Claude] Error body: \(body.prefix(400))")
                AnalyticsService.shared.track("claude_http_error", parameters: ["status": http.statusCode, "body": String(body.prefix(100))])
                throw ClaudeError.httpError(statusCode: http.statusCode)
            }
        } else {
            throw ClaudeError.httpError(statusCode: 0)
        }

        let claude = try JSONDecoder().decode(ClaudeResponse.self, from: data)
        guard let text = claude.content.first(where: { $0.type == "text" })?.text else {
            throw ClaudeError.emptyResponse
        }

        let jsonData = try extractJSON(from: text)
        let parsed = try JSONDecoder().decode(DeclarationJSON.self, from: jsonData)

        // Claude read the request and won't write for it. Caught specifically by
        // the caller so it never reaches the keyword fallback.
        guard parsed.category != "decline" else { throw ClaudeError.declined }

        let category = DeclarationCategory(rawValue: parsed.category) ?? .faith
        return DeclarationMatch(
            category: category,
            declarationText: parsed.declarationText,
            verse: parsed.verseText,
            verseReference: parsed.verseReference,
            isConfident: true
        )
    }

    private func extractJSON(from text: String) throws -> Data {
        guard let start = text.firstIndex(of: "{"),
              let end = text.lastIndex(of: "}") else {
            throw ClaudeError.invalidJSON
        }
        let jsonString = String(text[start...end])
        guard let data = jsonString.data(using: .utf8) else {
            throw ClaudeError.invalidJSON
        }
        return data
    }
}

// MARK: - Supporting Types

private enum ClaudeError: Error {
    case httpError(statusCode: Int)
    case emptyResponse
    case invalidJSON
    case declined
}

private struct ClaudeRequest: Encodable {
    let model: String
    let maxTokens: Int
    let system: String
    let messages: [Message]

    struct Message: Encodable {
        let role: String
        let content: String
    }

    enum CodingKeys: String, CodingKey {
        case model, system, messages
        case maxTokens = "max_tokens"
    }
}

private struct ClaudeResponse: Decodable {
    let content: [ContentBlock]

    struct ContentBlock: Decodable {
        let type: String
        let text: String?
    }
}

private struct DeclarationJSON: Decodable {
    let category: String
    let declarationText: String
    let verseText: String
    let verseReference: String
}
