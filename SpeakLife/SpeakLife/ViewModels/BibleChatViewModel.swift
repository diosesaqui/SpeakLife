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
        AnalyticsService.shared.trackContentInteraction(
            contentType: "bible_chat_topic",
            contentId: topic.id,
            action: "open"
        )
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
    @Published var currentConversationID: UUID?

    private let service: BibleChatAIService
    private let windowSize = 8
    /// Bumped whenever the user switches chats; lets an in-flight send ignore
    /// its result if the context changed while it was loading.
    private var generation = 0

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
        AnalyticsService.shared.trackUserAction("bible_chat_message_sent", category: "bible_chat")
        GrowthMetrics.shared.trackActivation(action: "bible_chat_message_sent")
        GrowthMetrics.shared.trackFeatureFirstUse("bible_chat")
        // Ticks the `ask_the_bible` checklist row. Posted here rather than on a
        // successful response so a network failure does not cost the user a row
        // they earned by asking. Deliberately not in `retryLastMessage`, for the
        // same reason the metrics above are not.
        NotificationCenter.default.post(name: .bibleChatAsked, object: nil)
        dispatchSend(text, isPremium: isPremium)
    }

    /// Resend the question that just failed, without making the user retype it.
    ///
    /// The failure path deliberately leaves their message in the transcript, so
    /// the text is already here — this resends it in place rather than
    /// appending a duplicate, which is why it cannot go through `send`.
    ///
    /// Not counted as a new message: the activation and first-use metrics
    /// already fired when the question was first asked, and counting a network
    /// blip as a second question would overstate engagement.
    func retryLastMessage(isPremium: Bool) {
        guard !isSending else { return }
        guard let last = messages.last, last.role == .user else { return }
        errorMessage = nil
        AnalyticsService.shared.trackUserAction("bible_chat_retry_tapped", category: "bible_chat")
        dispatchSend(last.text, isPremium: isPremium)
    }

    /// The request itself. Assumes the user's message is already the last one in
    /// the transcript, so both a first send and a retry can share it.
    private func dispatchSend(_ text: String, isPremium: Bool) {
        isSending = true

        // Rolling window: only the last N messages are sent upstream.
        let window = Array(messages.suffix(windowSize))
        let gen = generation

        Task {
            defer { isSending = false }
            do {
                let result = try await service.send(messages: window, isPremium: isPremium)
                // If the user switched to another chat (or started a new one)
                // while this was loading, drop the stale result.
                guard gen == generation else { return }
                if result.needsPaywall {
                    // Pull the unanswered question back so the transcript stays clean.
                    if messages.last?.role == .user { messages.removeLast() }
                    needsPaywall = true
                } else if let reply = result.reply {
                    messages.append(ChatMessage(role: .assistant, text: reply))
                    remainingFree = result.remainingFree
                    // Persist the exchange to local history (creates the
                    // conversation on the first save of a new chat).
                    currentConversationID = ChatHistoryStore.shared.record(
                        userText: text, assistantText: reply, into: currentConversationID
                    ).id
                }
            } catch {
                guard gen == generation else { return }
                // Leave the user's message in the transcript and surface an error
                // so nothing they typed is lost; they can resend.
                errorMessage = "Something went wrong. Please try again."
            }
        }
    }

    /// Clear the screen for a fresh conversation (does not delete saved history).
    func startNewConversation() {
        generation += 1
        messages = []
        draft = ""
        errorMessage = nil
        needsPaywall = false
        currentConversationID = nil
    }

    /// Load a saved conversation back into the chat to continue or review it.
    func load(_ conversation: ChatConversation) {
        generation += 1
        currentConversationID = conversation.id
        errorMessage = nil
        messages = conversation.messages
            .sorted { $0.createdAt < $1.createdAt }
            .map { ChatMessage(
                role: $0.role == ChatMessage.Role.assistant.rawValue ? .assistant : .user,
                text: $0.text
            ) }
    }
}
