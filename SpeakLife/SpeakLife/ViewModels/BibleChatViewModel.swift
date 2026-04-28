//
//  BibleChatViewModel.swift
//  SpeakLife
//

import Foundation
import SwiftUI

@MainActor
final class BibleChatViewModel: ObservableObject {

    @Published private(set) var topics: [BibleChatTopic] = []
    @Published var searchText: String = ""
    @Published var selectedTopic: BibleChatTopic?
    @Published var errorMessage: String?
    @Published var isLoading: Bool = false

    private let service: BibleChatServiceProtocol

    init(service: BibleChatServiceProtocol = BibleChatService.shared) {
        self.service = service
    }

    var filteredTopics: [BibleChatTopic] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return topics }
        return service.search(trimmed)
    }

    func load() {
        isLoading = true
        defer { isLoading = false }
        do {
            topics = try service.loadTopics()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func select(_ topic: BibleChatTopic) {
        selectedTopic = topic
        AnalyticsService.shared.trackContentInteraction(
            contentType: "bible_chat_topic",
            contentId: topic.id,
            action: "open"
        )
    }

    func dismiss() {
        selectedTopic = nil
    }
}
