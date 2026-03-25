//
//  AIVerseService.swift
//  SpeakLife
//
//  AI-powered Bible verse service using OpenAI GPT-4o.
//  Accepts topic tags + optional user message → returns a curated verse with encouragement.
//

import Foundation

// MARK: - Response Models

struct AIVerseResponse: Codable, Identifiable {
    let id: UUID
    let verse: String
    let reference: String
    let encouragement: String
    let topics: [String]
    
    init(verse: String, reference: String, encouragement: String, topics: [String]) {
        self.id = UUID()
        self.verse = verse
        self.reference = reference
        self.encouragement = encouragement
        self.topics = topics
    }
}

struct AIChatMessage: Identifiable {
    let id: UUID
    let role: MessageRole
    let content: String
    let verseResponse: AIVerseResponse?
    let timestamp: Date
    
    enum MessageRole {
        case user, assistant
    }
    
    init(role: MessageRole, content: String, verseResponse: AIVerseResponse? = nil) {
        self.id = UUID()
        self.role = role
        self.content = content
        self.verseResponse = verseResponse
        self.timestamp = Date()
    }
}

// MARK: - Service

final class AIVerseService {
    static let shared = AIVerseService()
    
    // TODO: Move to secure config / remote config before production.
    // Set via Info.plist key "OPENAI_API_KEY" or inject at build time.
    private var apiKey: String {
        Bundle.main.object(forInfoDictionaryKey: "OPENAI_API_KEY") as? String ?? ""
    }
    
    private let endpoint = URL(string: "https://api.openai.com/v1/chat/completions")!
    
    private let systemPrompt = """
    You are a compassionate Christian spiritual companion in the SpeakLife app. \
    Your role is to provide Scripture that speaks directly to what the user is going through. \
    
    Rules:
    - Always ground your response in an accurate Bible verse (KJV or NIV).
    - Never speculate or invent Scripture. Only use real, verifiable Bible verses.
    - Keep encouragement warm, personal, and faith-filled. 5th grade reading level.
    - Speak directly to the user ("you", "your heart").
    - Do NOT use complex theological jargon.
    
    Respond ONLY with valid JSON in this exact format:
    {
      "verse": "<full verse text>",
      "reference": "<Book Chapter:Verse (translation)>",
      "encouragement": "<2-3 sentences of warm, personal encouragement>"
    }
    """
    
    func fetchVerse(topics: [String], userMessage: String?) async throws -> AIVerseResponse {
        guard !apiKey.isEmpty else {
            throw AIVerseError.missingAPIKey
        }
        
        let topicList = topics.isEmpty ? "faith" : topics.joined(separator: ", ")
        let userContent: String
        if let msg = userMessage, !msg.trimmingCharacters(in: .whitespaces).isEmpty {
            userContent = "Topics: \(topicList)\n\nWhat's on my heart: \(msg)"
        } else {
            userContent = "I need a Bible verse about: \(topicList)"
        }
        
        let requestBody: [String: Any] = [
            "model": "gpt-4o",
            "max_tokens": 400,
            "temperature": 0.7,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userContent]
            ]
        ]
        
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIVerseError.networkError
        }
        
        switch httpResponse.statusCode {
        case 200:
            break
        case 401:
            throw AIVerseError.unauthorized
        case 429:
            throw AIVerseError.rateLimited
        default:
            throw AIVerseError.serverError(httpResponse.statusCode)
        }
        
        // Parse OpenAI envelope
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard
            let choices = json?["choices"] as? [[String: Any]],
            let message = choices.first?["message"] as? [String: Any],
            let content = message["content"] as? String
        else {
            throw AIVerseError.decodingError
        }
        
        // Parse the inner JSON response
        guard let jsonData = content.data(using: .utf8) else {
            throw AIVerseError.decodingError
        }
        
        let parsed = try JSONDecoder().decode(RawVersePayload.self, from: jsonData)
        return AIVerseResponse(
            verse: parsed.verse,
            reference: parsed.reference,
            encouragement: parsed.encouragement,
            topics: topics
        )
    }
}

// MARK: - Internal Models

private struct RawVersePayload: Decodable {
    let verse: String
    let reference: String
    let encouragement: String
}

// MARK: - Errors

enum AIVerseError: LocalizedError {
    case missingAPIKey
    case networkError
    case unauthorized
    case rateLimited
    case decodingError
    case serverError(Int)
    
    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "API key not configured."
        case .networkError:
            return "Network connection error."
        case .unauthorized:
            return "Invalid API key."
        case .rateLimited:
            return "Too many requests. Please try again shortly."
        case .decodingError:
            return "Unexpected response from server."
        case .serverError(let code):
            return "Server error (\(code))."
        }
    }
}
