//
//  ClaudeDeclarationMatcher.swift
//  SpeakLife
//
//  Uses the Anthropic Messages API to generate a personalized declaration and
//  Bible verse from the user's free-form prayer need. Falls back to
//  KeywordDeclarationMatcher when offline or when no API key is configured.
//

import Foundation

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
            return await fallback.match(input: input)
        }
        do {
            return try await callClaude(input: input, apiKey: apiKey)
        } catch {
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
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw ClaudeError.httpError
        }

        let claude = try JSONDecoder().decode(ClaudeResponse.self, from: data)
        guard let text = claude.content.first(where: { $0.type == "text" })?.text else {
            throw ClaudeError.emptyResponse
        }

        let jsonData = try extractJSON(from: text)
        let parsed = try JSONDecoder().decode(DeclarationJSON.self, from: jsonData)

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
    case httpError
    case emptyResponse
    case invalidJSON
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
