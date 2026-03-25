//
//  AskViewModel.swift
//  SpeakLife
//
//  State management for the Ask tab — topic selection, chat history, and AI requests.
//

import SwiftUI
import Combine

@MainActor
final class AskViewModel: ObservableObject {
    
    // MARK: - State
    
    enum ViewState {
        case empty       // No conversation yet
        case loading     // Waiting on AI
        case chat        // Conversation active
        case error(String)
    }
    
    @Published var viewState: ViewState = .empty
    @Published var selectedTopics: Set<DeclarationCategory> = []
    @Published var inputText: String = ""
    @Published var messages: [AIChatMessage] = []
    @Published var showPaywall = false
    @Published var savedVerses: [AIVerseResponse] = []
    
    // Animated input focus
    @Published var isInputFocused = false
    
    private let service = AIVerseService.shared
    
    // MARK: - Available Topics
    // All non-Bible categories from DeclarationCategory.categoryOrder
    
    static let availableTopics: [DeclarationCategory] = [
        .love, .identity, .faith, .grace,
        .rest, .hope, .joy, .wisdom, .praise,
        .destiny, .warfare, .miracles, .health, .innerHealing,
        .obedience, .purity, .gratitude,
        .marriage, .parenting, .friendship,
        .godsprotection, .favor, .wealth, .work,
        .anxiety, .fear, .hardtimes, .addiction,
        .heaven
    ]
    
    // MARK: - Actions
    
    func toggleTopic(_ category: DeclarationCategory) {
        if selectedTopics.contains(category) {
            selectedTopics.remove(category)
        } else {
            if selectedTopics.count < 3 {
                selectedTopics.insert(category)
            }
        }
    }
    
    func isSelected(_ category: DeclarationCategory) -> Bool {
        selectedTopics.contains(category)
    }
    
    func canSelectMore: Bool {
        selectedTopics.count < 3
    }
    
    var canSubmit: Bool {
        !selectedTopics.isEmpty || !inputText.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    func submit() async {
        guard canSubmit else { return }
        
        let topicNames = selectedTopics.map { $0.name }
        let userText = inputText.trimmingCharacters(in: .whitespaces)
        
        // Build user-facing message summary
        var displayText = ""
        if !topicNames.isEmpty {
            displayText += topicNames.joined(separator: " · ")
        }
        if !userText.isEmpty {
            displayText += displayText.isEmpty ? userText : "\n\"\(userText)\""
        }
        
        // Add user message to chat
        let userMessage = AIChatMessage(role: .user, content: displayText)
        messages.append(userMessage)
        
        // Clear input
        let submittedTopics = selectedTopics
        let submittedText = inputText
        inputText = ""
        selectedTopics = []
        
        // Set loading
        viewState = .loading
        
        do {
            let response = try await service.fetchVerse(
                topics: topicNames,
                userMessage: submittedText.isEmpty ? nil : submittedText
            )
            
            let assistantMessage = AIChatMessage(
                role: .assistant,
                content: response.verse,
                verseResponse: response
            )
            
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                messages.append(assistantMessage)
                viewState = .chat
            }
            
            // Analytics
            Event.trackScreen("ask_verse_received", metadata: [
                "topics": topicNames.joined(separator: ","),
                "had_custom_message": !submittedText.isEmpty
            ])
            
        } catch {
            withAnimation {
                viewState = .error(error.localizedDescription)
            }
            
            // Remove user message on error
            messages.removeLast()
        }
    }
    
    func saveVerse(_ verse: AIVerseResponse) {
        guard !savedVerses.contains(where: { $0.id == verse.id }) else { return }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            savedVerses.append(verse)
        }
        PremiumHaptics.success()
    }
    
    func isSaved(_ verse: AIVerseResponse) -> Bool {
        savedVerses.contains(where: { $0.id == verse.id })
    }
    
    func clearError() {
        if case .error = viewState {
            viewState = messages.isEmpty ? .empty : .chat
        }
    }
    
    func resetConversation() {
        withAnimation(.easeInOut(duration: 0.3)) {
            messages = []
            selectedTopics = []
            inputText = ""
            viewState = .empty
        }
    }
}
