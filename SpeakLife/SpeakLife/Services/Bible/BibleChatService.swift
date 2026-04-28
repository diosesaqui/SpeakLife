//
//  BibleChatService.swift
//  SpeakLife
//
//  Loads curated topical answers from bundled JSON.
//

import Foundation

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
