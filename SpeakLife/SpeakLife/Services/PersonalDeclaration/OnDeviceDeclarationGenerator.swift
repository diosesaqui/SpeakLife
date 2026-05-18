//
//  OnDeviceDeclarationGenerator.swift
//  SpeakLife
//
//  NOTE: name is now historical — this class drives the "Declaration of
//  the Moment" feature using the cloud Anthropic Messages API (the same
//  service ClaudeDeclarationMatcher uses for onboarding). The Apple
//  on-device path produced low-quality output for this app's voice, so
//  the implementation was swapped to cloud while keeping the public
//  protocol surface stable. The MomentDeclarationSheet UI consumes
//  this through OnDeviceDeclarationGeneratorProtocol — no changes there.
//

import Foundation
import FirebaseAnalytics

/// What the UI receives.
struct MomentDeclaration: Equatable {
    let declarationText: String
    let verseText: String
    let verseReference: String
}

enum MomentGenerationError: Error, LocalizedError {
    case unavailable
    case modelFailed(String)

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return "AI generation isn't available right now. Check your connection and try again."
        case .modelFailed(let reason):
            return "Couldn't generate a declaration. \(reason)"
        }
    }
}

protocol OnDeviceDeclarationGeneratorProtocol {
    /// True when the cloud Anthropic API key has been loaded from Remote Config.
    var isAvailable: Bool { get }

    /// One-shot generation.
    func generate(from input: String) async throws -> MomentDeclaration

    /// Stream wrapper around `generate` so the UI can keep its streaming
    /// consumer shape. Emits a single final value when the cloud call returns.
    func stream(from input: String) -> AsyncThrowingStream<MomentDeclaration, Error>
}

final class OnDeviceDeclarationGenerator: OnDeviceDeclarationGeneratorProtocol {

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    var isAvailable: Bool {
        !AnthropicConfig.apiKey.isEmpty
    }

    func generate(from input: String) async throws -> MomentDeclaration {
        guard !AnthropicConfig.apiKey.isEmpty else {
            print("✨ [MomentDeclaration] No API key loaded yet")
            throw MomentGenerationError.unavailable
        }
        print("✨ [MomentDeclaration] Calling Claude for input: \(input.prefix(60))...")
        let start = Date()
        do {
            let result = try await callClaude(input: input)
            let elapsed = Date().timeIntervalSince(start)
            print("✨ [MomentDeclaration] ✅ Generated in \(String(format: "%.1f", elapsed))s")
            return result
        } catch {
            let elapsed = Date().timeIntervalSince(start)
            print("✨ [MomentDeclaration] ❌ Failed after \(String(format: "%.1f", elapsed))s: \(error)")
            throw MomentGenerationError.modelFailed(error.localizedDescription)
        }
    }

    func stream(from input: String) -> AsyncThrowingStream<MomentDeclaration, Error> {
        let (stream, continuation) = AsyncThrowingStream<MomentDeclaration, Error>.makeStream()
        Task {
            do {
                let result = try await self.generate(from: input)
                continuation.yield(result)
                continuation.finish()
            } catch {
                continuation.finish(throwing: error)
            }
        }
        return stream
    }

    // MARK: - Cloud call

    private func callClaude(input: String) async throws -> MomentDeclaration {
        var request = URLRequest(url: AnthropicConfig.apiURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(AnthropicConfig.apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.timeoutInterval = 20

        let body = ClaudeRequest(
            model: AnthropicConfig.model,
            maxTokens: 512,
            system: AnthropicConfig.systemPrompt,
            messages: [.init(role: "user", content: "User need: \(input)")]
        )
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            let bodyText = String(data: data, encoding: .utf8) ?? ""
            Analytics.logEvent("moment_decl_http_error",
                               parameters: ["status": http.statusCode,
                                            "body": String(bodyText.prefix(100))])
            throw NSError(domain: "Anthropic", code: http.statusCode,
                          userInfo: [NSLocalizedDescriptionKey: "HTTP \(http.statusCode)"])
        }

        let claude = try JSONDecoder().decode(ClaudeResponse.self, from: data)
        guard let text = claude.content.first(where: { $0.type == "text" })?.text else {
            throw NSError(domain: "Anthropic", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Empty response"])
        }

        let jsonData = try Self.extractJSON(from: text)
        let parsed = try JSONDecoder().decode(DeclarationJSON.self, from: jsonData)
        return MomentDeclaration(
            declarationText: parsed.declarationText,
            verseText: parsed.verseText,
            verseReference: parsed.verseReference
        )
    }

    private static func extractJSON(from text: String) throws -> Data {
        guard let start = text.firstIndex(of: "{"),
              let end = text.lastIndex(of: "}") else {
            throw NSError(domain: "Anthropic", code: -2,
                          userInfo: [NSLocalizedDescriptionKey: "Invalid JSON in response"])
        }
        let jsonString = String(text[start...end])
        guard let data = jsonString.data(using: .utf8) else {
            throw NSError(domain: "Anthropic", code: -3,
                          userInfo: [NSLocalizedDescriptionKey: "JSON encoding failed"])
        }
        return data
    }
}

// MARK: - Anthropic request/response shapes

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
    let category: String?
    let declarationText: String
    let verseText: String
    let verseReference: String
}
