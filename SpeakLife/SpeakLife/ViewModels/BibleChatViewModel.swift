//
//  BibleChatViewModel.swift
//  SpeakLife
//

import Foundation
import SwiftUI
import SwiftData

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

// MARK: - Live conversation view model
//
// Drives the AI Bible Chat. Keeps a rolling window of the last 8 messages
// (~4 exchanges) so follow-ups feel natural while keeping tokens bounded.

@MainActor
final class BibleChatConversationViewModel: ObservableObject {

    @Published var messages: [ChatMessage] = []
    @Published var draft: String = ""
    @Published var isSending: Bool = false
    @Published var errorMessage: String?
    @Published var needsPaywall: Bool = false
    @Published private(set) var remainingFree: Int?
    /// The conversation currently being viewed/extended (nil = unsaved new chat).
    @Published var currentConversation: ChatConversation?

    private let service: BibleChatAIService
    private let windowSize = 8

    init(service: BibleChatAIService = .shared) {
        self.service = service
    }

    var canSend: Bool {
        !isSending && !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func sendDraft(isPremium: Bool) {
        // Guard before clearing draft so a send while one is in flight (e.g. the
        // return key firing) never silently discards the user's text.
        guard !isSending else { return }
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        draft = ""
        send(text, isPremium: isPremium)
    }

    func send(_ text: String, isPremium: Bool) {
        guard !isSending else { return }
        errorMessage = nil
        messages.append(ChatMessage(role: .user, text: text))
        isSending = true

        // Rolling window: only the last N messages are sent upstream.
        let window = Array(messages.suffix(windowSize))
        AnalyticsService.shared.trackUserAction("bible_chat_message_sent", category: "bible_chat")

        Task {
            defer { isSending = false }
            do {
                let result = try await service.send(messages: window, isPremium: isPremium)
                if result.needsPaywall {
                    // Pull the unanswered question back so the transcript stays clean.
                    if messages.last?.role == .user { messages.removeLast() }
                    needsPaywall = true
                } else if let reply = result.reply {
                    messages.append(ChatMessage(role: .assistant, text: reply))
                    remainingFree = result.remainingFree
                    // Persist the exchange to local history (creates the
                    // conversation on the first save of a new chat).
                    currentConversation = ChatHistoryStore.shared.record(
                        userText: text, assistantText: reply, into: currentConversation
                    )
                }
            } catch {
                // Leave the user's message in the transcript and surface an error
                // so nothing they typed is lost; they can resend.
                errorMessage = "Something went wrong. Please try again."
            }
        }
    }

    /// Clear the screen for a fresh conversation (does not delete saved history).
    func startNewConversation() {
        messages = []
        draft = ""
        errorMessage = nil
        needsPaywall = false
        currentConversation = nil
    }

    /// Load a saved conversation back into the chat to continue or review it.
    func load(_ conversation: ChatConversation) {
        currentConversation = conversation
        errorMessage = nil
        messages = conversation.messages
            .sorted { $0.createdAt < $1.createdAt }
            .map { ChatMessage(
                role: $0.role == ChatMessage.Role.assistant.rawValue ? .assistant : .user,
                text: $0.text
            ) }
    }
}
