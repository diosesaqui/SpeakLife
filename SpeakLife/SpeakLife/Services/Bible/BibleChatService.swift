//
//  BibleChatService.swift
//  SpeakLife
//
//  Loads curated topical answers from bundled JSON.
//

import Foundation
import FirebaseAnalytics
import SwiftData

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

        let payload: [String: Any] = [
            "appUserId": RevenueCatManager.shared.appUserID,
            "isPremiumClaim": isPremium,
            "messages": messages.map { ["role": $0.role.rawValue, "content": $0.text] }
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw BibleChatAIError.network }
        guard http.statusCode == 200 else {
            Analytics.logEvent("bible_chat_http_error", parameters: ["status": http.statusCode])
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

// MARK: - Chat history (SwiftData, local)
//
// A single @Model holds the whole conversation; messages are stored as a Codable
// value array rather than a SwiftData relationship. The two-model relationship
// was triggering SwiftData's loadIssueModelContainer on init — one flat model
// with primitive + Codable properties loads reliably. Fast SQLite, instant,
// offline. To sync across devices later, add the iCloud capability and pass
// `cloudKitDatabase: .automatic` to the ModelConfiguration.

struct StoredMessage: Codable, Identifiable {
    var id: UUID = UUID()
    var role: String
    var text: String
    var createdAt: Date
}

@Model
final class ChatConversation {
    var id: UUID
    var title: String
    var createdAt: Date
    var updatedAt: Date
    var messages: [StoredMessage]

    init(id: UUID = UUID(),
         title: String,
         createdAt: Date = Date(),
         updatedAt: Date = Date(),
         messages: [StoredMessage] = []) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.messages = messages
    }
}

@MainActor
final class ChatHistoryStore {
    static let shared = ChatHistoryStore()

    /// Optional so a SwiftData failure degrades gracefully (history disabled)
    /// instead of crashing the app.
    let container: ModelContainer?
    private let maxConversations = 50

    private init() {
        if let c = try? Self.makeContainer(inMemory: false) {
            container = c
            return
        }
        // On-disk store likely corrupt/incompatible — delete and retry once.
        Self.deleteDefaultStore()
        if let c = try? Self.makeContainer(inMemory: false) {
            container = c
            return
        }
        // Final fallback: in-memory (no persistence this launch). nil if even
        // this fails — the app never crashes over chat history.
        container = try? Self.makeContainer(inMemory: true)
    }

    private static func makeContainer(inMemory: Bool) throws -> ModelContainer {
        let schema = Schema([ChatConversation.self])
        return try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        )
    }

    /// Remove the default SwiftData store (and -shm/-wal sidecars) so a corrupt
    /// store can be recreated cleanly.
    private static func deleteDefaultStore() {
        let schema = Schema([ChatConversation.self])
        let url = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false).url
        let base = url.path
        for path in [base, base + "-shm", base + "-wal"] {
            try? FileManager.default.removeItem(atPath: path)
        }
    }

    private var context: ModelContext? { container?.mainContext }

    /// Append the latest user+assistant exchange, creating the conversation on
    /// first save. Returns the conversation (or the passed-in one if history is
    /// unavailable).
    @discardableResult
    func record(userText: String, assistantText: String, into conversation: ChatConversation?) -> ChatConversation? {
        guard let context else { return conversation }
        let convo: ChatConversation
        let isNew: Bool
        // Guard against a conversation deleted from history while it was active.
        if let existing = conversation, existing.modelContext != nil {
            convo = existing
            isNew = false
        } else {
            convo = ChatConversation(title: Self.makeTitle(from: userText))
            context.insert(convo)
            isNew = true
        }
        let now = Date()
        convo.messages.append(StoredMessage(role: ChatMessage.Role.user.rawValue, text: userText, createdAt: now))
        convo.messages.append(StoredMessage(role: ChatMessage.Role.assistant.rawValue, text: assistantText, createdAt: now.addingTimeInterval(0.001)))
        convo.updatedAt = now
        try? context.save()
        if isNew { pruneIfNeeded() }
        return convo
    }

    /// Rename a conversation. Ignores empty titles.
    func rename(_ conversation: ChatConversation, to title: String) {
        guard let context else { return }
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        conversation.title = String(trimmed.prefix(60))
        try? context.save()
    }

    func delete(_ conversation: ChatConversation) {
        guard let context else { return }
        context.delete(conversation)
        try? context.save()
    }

    /// Delete the oldest conversations beyond the cap (called when a new one is added).
    private func pruneIfNeeded() {
        guard let context else { return }
        let descriptor = FetchDescriptor<ChatConversation>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        guard let all = try? context.fetch(descriptor), all.count > maxConversations else { return }
        for convo in all[maxConversations...] {
            context.delete(convo)
        }
        try? context.save()
    }

    static func makeTitle(from text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "New conversation" : String(trimmed.prefix(48))
    }
}
