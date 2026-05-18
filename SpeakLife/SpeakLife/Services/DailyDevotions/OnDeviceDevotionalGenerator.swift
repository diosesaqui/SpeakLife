//
//  OnDeviceDevotionalGenerator.swift
//  SpeakLife
//
//  NOTE: name is now historical — implementation calls the cloud Anthropic
//  Messages API (same service as ClaudeDeclarationMatcher / the personal
//  declaration onboarding path). Apple's on-device model didn't hold up
//  for this format, so generation was moved to cloud while the public
//  protocol stayed stable. CategoryDevotionalSheet consumes this through
//  OnDeviceDevotionalGeneratorProtocol — no UI changes required.
//

import Foundation
import FirebaseAnalytics

enum GeneratedDevotionalCategory: String, CaseIterable, Identifiable {
    case healing
    case identity
    case peace
    case breakthrough
    case warfare
    case calling
    case relationships
    case faith
    case gratitude
    case fear
    case forgiveness
    case rest

    var id: String { rawValue }

    var label: String {
        switch self {
        case .healing:       return "Healing"
        case .identity:      return "Identity"
        case .peace:         return "Peace"
        case .breakthrough:  return "Breakthrough"
        case .warfare:       return "Spiritual Warfare"
        case .calling:       return "Purpose & Calling"
        case .relationships: return "Relationships"
        case .faith:         return "Faith"
        case .gratitude:     return "Gratitude"
        case .fear:          return "Fear & Anxiety"
        case .forgiveness:   return "Forgiveness"
        case .rest:          return "Rest"
        }
    }

    var emoji: String {
        switch self {
        case .healing:       return "🌿"
        case .identity:      return "👑"
        case .peace:         return "🕊"
        case .breakthrough:  return "💥"
        case .warfare:       return "⚔️"
        case .calling:       return "🧭"
        case .relationships: return "🤝"
        case .faith:         return "🙏"
        case .gratitude:     return "🌟"
        case .fear:          return "🛡"
        case .forgiveness:   return "💜"
        case .rest:          return "😴"
        }
    }
}

protocol OnDeviceDevotionalGeneratorProtocol {
    var isAvailable: Bool { get }
    func generate(category: GeneratedDevotionalCategory) async throws -> Devotional
    func stream(category: GeneratedDevotionalCategory) -> AsyncThrowingStream<Devotional, Error>
}

final class OnDeviceDevotionalGenerator: OnDeviceDevotionalGeneratorProtocol {

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    var isAvailable: Bool {
        !AnthropicConfig.apiKey.isEmpty
    }

    func generate(category: GeneratedDevotionalCategory) async throws -> Devotional {
        guard !AnthropicConfig.apiKey.isEmpty else {
            print("📖 [AIDevotional] No API key loaded yet")
            throw MomentGenerationError.unavailable
        }
        print("📖 [AIDevotional] Calling Claude for category=\(category.rawValue)")
        let start = Date()
        do {
            let result = try await callClaude(category: category)
            let elapsed = Date().timeIntervalSince(start)
            print("📖 [AIDevotional] ✅ Generated in \(String(format: "%.1f", elapsed))s — title='\(result.title)'")
            return result
        } catch {
            let elapsed = Date().timeIntervalSince(start)
            print("📖 [AIDevotional] ❌ Failed after \(String(format: "%.1f", elapsed))s: \(error)")
            throw MomentGenerationError.modelFailed(error.localizedDescription)
        }
    }

    func stream(category: GeneratedDevotionalCategory) -> AsyncThrowingStream<Devotional, Error> {
        let (stream, continuation) = AsyncThrowingStream<Devotional, Error>.makeStream()
        Task {
            do {
                let result = try await self.generate(category: category)
                continuation.yield(result)
                continuation.finish()
            } catch {
                continuation.finish(throwing: error)
            }
        }
        return stream
    }

    // MARK: - Cloud call

    private func callClaude(category: GeneratedDevotionalCategory) async throws -> Devotional {
        var request = URLRequest(url: AnthropicConfig.apiURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(AnthropicConfig.apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.timeoutInterval = 45  // longer prompts → longer responses

        let body = ClaudeRequest(
            model: AnthropicConfig.model,
            maxTokens: 1200,
            system: Self.systemPrompt,
            messages: [.init(role: "user", content: "Category: \(category.label). Write today's devotional.")]
        )
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            let bodyText = String(data: data, encoding: .utf8) ?? ""
            Analytics.logEvent("ai_devotional_http_error",
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
        let parsed = try JSONDecoder().decode(DevotionalJSON.self, from: jsonData)
        return Devotional(
            date: Date(),
            title: parsed.title,
            devotionalText: parsed.body,
            books: parsed.scriptureLine
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

    // MARK: - Prompt

    private static let systemPrompt = """
    You are writing today's devotional for SpeakLife, a Christian faith app used by over 1 million believers daily. Match the voice and shape of the editorially-curated devotionals exactly.

    STRUCTURE:
    - title: 4-8 words, evocative and theological. Examples: "His Words Are Spirit and Life", "Clean Hands, Dirty Hearts?", "The Banner Over Me Is Love"
    - scriptureLine: One Bible verse, NIV preferred, written as "Quoted verse text. – Book Chapter:Verse" with the dash separator and reference at the end.
    - body: 4-6 paragraphs separated by double newlines (\\n\\n). Total length 350-500 words.

    BODY VOICE RULES:
    - Open with a one-sentence theological hook naming the truth the devotional will unfold.
    - Second paragraph: ground the truth in the scripture and the moment it was spoken. Name what God is like ("This is who He is — a God who…").
    - Middle paragraphs: apply the truth to the reader with specificity. Use direct address ("you"). Ask a piercing question.
    - Closing paragraph: a short, surrendered prayer ending with "Amen." and a single heart emoji 💜.
    - Tone: pastoral, certain, weighty. No hedging. No clichés ("hang in there", "God's got this").
    - Em dashes are allowed in the devotional body (the curated devotionals use them freely).
    - The devotional is written TO the reader, not as the reader speaking.

    Respond ONLY with valid JSON — no markdown, no code fences, no preface. Exact format:
    {"title":"Title here","scriptureLine":"Verse text. – Book Chapter:Verse","body":"Paragraph 1.\\n\\nParagraph 2.\\n\\nParagraph 3."}
    """
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

private struct DevotionalJSON: Decodable {
    let title: String
    let scriptureLine: String
    let body: String
}
