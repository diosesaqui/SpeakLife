//
//  BibleChatService.swift
//  SpeakLife
//
//  Loads curated topical answers from bundled JSON.
//

import Foundation
import FirebaseAnalytics

protocol BibleChatServiceProtocol {
    func loadTopics() throws -> [BibleChatTopic]
    func topic(withId id: String) -> BibleChatTopic?
    func search(_ query: String) -> [BibleChatTopic]
}

final class BibleChatService: BibleChatServiceProtocol {

    static let shared = BibleChatService()

    private let resourceName: String
    private var cache: [BibleChatTopic] = []
    private var didLoad = false

    init(resourceName: String = "bible_chat_topics") {
        self.resourceName = resourceName
    }

    @discardableResult
    func loadTopics() throws -> [BibleChatTopic] {
        if didLoad { return cache }

        guard let url = Bundle.main.url(forResource: resourceName, withExtension: "json") else {
            throw BibleChatError.resourceMissing
        }

        let data = try Data(contentsOf: url)
        let decoded = try JSONDecoder().decode(BibleChatTopicCollection.self, from: data)
        cache = decoded.topics
        didLoad = true
        return cache
    }

    func topic(withId id: String) -> BibleChatTopic? {
        cache.first(where: { $0.id == id })
    }

    func search(_ query: String) -> [BibleChatTopic] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return cache }
        return cache.filter { topic in
            topic.title.lowercased().contains(trimmed)
            || topic.question.lowercased().contains(trimmed)
            || topic.summary.lowercased().contains(trimmed)
        }
    }
}

enum BibleChatError: LocalizedError {
    case resourceMissing
    case decodingFailed

    var errorDescription: String? {
        switch self {
        case .resourceMissing: return "We couldn't find the topical answers file."
        case .decodingFailed: return "We couldn't read the topical answers."
        }
    }
}

// MARK: - Live Bible Chat (AI)
//
// Talks to the `bibleChat` Firebase Cloud Function, which holds the Anthropic
// key, verifies premium via RevenueCat, enforces the free-message limit, and
// meters token usage. The device never sees the API key. This mirrors the
// async/await + analytics style of ClaudeDeclarationMatcher.

/// Local-testing helpers.
enum BibleChatLocal {
    /// DEBUG builds (i.e. running from Xcode) always show the Bible Chat tab and
    /// can chat, so you can test without flipping the production
    /// `enableAIFeatures` Remote Config flag. Always false in Release.
    static var isDebug: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }

    /// Optional: hit a local Firebase emulator instead of the deployed cloud
    /// function. Off unless you set USE_FIREBASE_EMULATOR=1 in the scheme. Most
    /// of the time you just deploy the function and leave this alone.
    static var usesEmulator: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.environment["USE_FIREBASE_EMULATOR"] == "1"
        #else
        return false
        #endif
    }
}

struct ChatMessage: Identifiable, Equatable {
    enum Role: String { case user, assistant }
    let id = UUID()
    let role: Role
    var text: String
}

struct BibleChatResponse {
    let reply: String?
    let needsPaywall: Bool
    let remainingFree: Int?
}

enum BibleChatAIError: Error { case network, server, empty }

final class BibleChatAIService {
    static let shared = BibleChatAIService()

    // us-central1 HTTPS function for the speaklife-3e5c4 project.
    //
    // Local testing: set the scheme env var USE_FIREBASE_EMULATOR=1 (Edit Scheme
    // → Run → Arguments → Environment Variables) and run `firebase emulators:start`.
    // DEBUG builds will then hit the local emulator. Without the env var, and in
    // all Release builds, it always uses the production cloud URL.
    private static let cloudEndpoint = URL(string: "https://us-central1-speaklife-3e5c4.cloudfunctions.net/bibleChat")!
    private static let emulatorEndpoint = URL(string: "http://127.0.0.1:5001/speaklife-3e5c4/us-central1/bibleChat")!

    private var endpoint: URL {
        BibleChatLocal.usesEmulator ? Self.emulatorEndpoint : Self.cloudEndpoint
    }

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    /// Sends the rolling conversation window. `isPremium` is only a fallback
    /// claim — the server verifies entitlement via RevenueCat when configured.
    func send(messages: [ChatMessage], isPremium: Bool) async throws -> BibleChatResponse {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30

        var payload: [String: Any] = [
            "appUserId": RevenueCatManager.shared.appUserID,
            "isPremiumClaim": isPremium,
            "messages": messages.map { ["role": $0.role.rawValue, "content": $0.text] }
        ]

        // Onboarding already learned what this person is carrying; without it the
        // chat meets them as a stranger. The function renders a whitelisted
        // subset into a SECOND, uncached system block (per-user text inside the
        // cached one would destroy the prompt-cache discount for everyone).
        //
        // Read synchronously off UserDefaults rather than through DIContainer:
        // this service is not main-actor isolated, and `loadSync` is the same
        // accessor NotificationManager already uses off the async path.
        // Encoding goes through SoulProfileFirestoreMirror so there is exactly
        // one definition of the wire shape (`firestorePayload`, not
        // `requestPayload` — appUserId is already a top-level field here).
        // No profile (skipped onboarding, or an install that predates it) means
        // the key is simply absent and the request is what it has always been.
        if let profile = SoulProfileRepository.loadSync(), !profile.isEmpty,
           let encodedProfile = SoulProfileFirestoreMirror.firestorePayload(for: profile) {
            payload["profile"] = encodedProfile
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw BibleChatAIError.network }
        guard http.statusCode == 200 else {
            AnalyticsService.shared.track("bible_chat_http_error", parameters: ["status": http.statusCode])
            throw BibleChatAIError.server
        }

        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        let needsPaywall = json["needsPaywall"] as? Bool ?? false
        let reply = json["reply"] as? String
        let remaining = (json["remainingFree"] as? NSNumber)?.intValue

        let isBlankReply = reply?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true
        if !needsPaywall && isBlankReply { throw BibleChatAIError.empty }
        return BibleChatResponse(reply: reply, needsPaywall: needsPaywall, remainingFree: remaining)
    }
}

// MARK: - Chat history (local JSON cache)
//
// SwiftData refused to build a ModelContainer in this app (loadIssueModelContainer
// on init for both a relationship model and a Codable-array model), so chat
// history uses a simple, bulletproof Codable-to-disk cache. The data is small
// (capped at 50 conversations), loaded once and rewritten on each exchange —
// fast and reliable, with no schema engine to fail.

struct StoredMessage: Codable, Identifiable, Equatable {
    var id = UUID()
    var role: String
    var text: String
    var createdAt: Date
}

struct ChatConversation: Codable, Identifiable, Equatable {
    var id = UUID()
    var title: String
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var messages: [StoredMessage] = []
}

@MainActor
final class ChatHistoryStore: ObservableObject {
    static let shared = ChatHistoryStore()

    /// Conversations, newest first.
    @Published private(set) var conversations: [ChatConversation] = []

    private let maxConversations = 50
    private let fileURL: URL

    private init() {
        let dir = (try? FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask,
            appropriateFor: nil, create: true
        )) ?? FileManager.default.temporaryDirectory
        fileURL = dir.appendingPathComponent("bible_chat_history.json")
        loadFromDisk()
    }

    private func loadFromDisk() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([ChatConversation].self, from: data) else {
            conversations = []
            return
        }
        conversations = decoded.sorted { $0.updatedAt > $1.updatedAt }
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(conversations) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    /// Append the latest user+assistant exchange. Creates the conversation if
    /// `conversationID` is nil or no longer exists. Returns the conversation.
    @discardableResult
    func record(userText: String, assistantText: String, into conversationID: UUID?) -> ChatConversation {
        let now = Date()
        let userMsg = StoredMessage(role: ChatMessage.Role.user.rawValue, text: userText, createdAt: now)
        let aiMsg = StoredMessage(role: ChatMessage.Role.assistant.rawValue, text: assistantText, createdAt: now.addingTimeInterval(0.001))

        if let id = conversationID, let idx = conversations.firstIndex(where: { $0.id == id }) {
            conversations[idx].messages.append(userMsg)
            conversations[idx].messages.append(aiMsg)
            conversations[idx].updatedAt = now
            let updated = conversations.remove(at: idx)
            conversations.insert(updated, at: 0) // bump to top (newest first)
            persist()
            return updated
        }

        let convo = ChatConversation(
            title: Self.makeTitle(from: userText),
            createdAt: now, updatedAt: now,
            messages: [userMsg, aiMsg]
        )
        conversations.insert(convo, at: 0)
        if conversations.count > maxConversations {
            conversations.removeLast(conversations.count - maxConversations)
        }
        persist()
        return convo
    }

    func rename(_ id: UUID, to title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let idx = conversations.firstIndex(where: { $0.id == id }) else { return }
        conversations[idx].title = String(trimmed.prefix(60))
        persist()
    }

    func delete(_ id: UUID) {
        conversations.removeAll { $0.id == id }
        persist()
    }

    func delete(at offsets: IndexSet) {
        conversations.remove(atOffsets: offsets)
        persist()
    }

    static func makeTitle(from text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "New conversation" : String(trimmed.prefix(48))
    }
}
