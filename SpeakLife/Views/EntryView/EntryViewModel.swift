//
//  EntryViewModel.swift
//  SpeakLife
//
//  View model for managing journal and affirmation entry state
//

import Foundation
import SwiftUI
import Combine

@MainActor
class EntryViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var text: String = ""
    @Published var isSaving: Bool = false
    @Published var saveError: String?
    @Published var hasUnsavedChanges: Bool = false
    
    // MARK: - Computed Properties
    var wordCount: Int {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .count
    }
    
    var characterCount: Int {
        text.count
    }
    
    var canSave: Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).count >= 3 && !isSaving
    }
    
    var isWithinRecommendedLength: Bool {
        characterCount <= 1000 // Reasonable limit for mobile entry
    }
    
    var recommendedLengthMessage: String {
        if characterCount > 1000 {
            return "Consider shortening your entry for better readability"
        } else if characterCount > 500 {
            return "Your entry is getting long but still manageable"
        } else {
            return ""
        }
    }
    
    // MARK: - Private Properties
    private let contentType: ContentType
    private let existingText: String
    private let isEditing: Bool
    private var autoSaveTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    // Auto-save configuration
    private let autoSaveInterval: TimeInterval = 30
    private let draftKey: String
    
    // MARK: - Initialization
    init(contentType: ContentType, existingText: String = "", isEditing: Bool = false) {
        self.contentType = contentType
        self.existingText = existingText
        self.isEditing = isEditing
        self.draftKey = "draft_\(contentType.rawValue)_\(Date().timeIntervalSince1970)"
        
        // Initialize text
        self.text = existingText
        
        setupTextChangeObserver()
        loadDraftIfNeeded()
    }
    
    deinit {
        autoSaveTimer?.invalidate()
    }
    
    // MARK: - Public Methods
    func appendVoiceText(_ voiceText: String) {
        guard !voiceText.isEmpty else { return }
        
        let trimmedVoice = voiceText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedVoice.isEmpty else { return }
        
        if text.isEmpty {
            text = trimmedVoice
        } else {
            // Add a space or period depending on the context
            let lastChar = text.last
            let needsPunctuation = lastChar != nil && !CharacterSet.punctuationCharacters.contains(Unicode.Scalar(String(lastChar!))!)
            let separator = needsPunctuation ? ". " : " "
            text += separator + trimmedVoice
        }
        
        // Ensure text ends properly - add period if it doesn't end with punctuation
        if !text.isEmpty, let lastChar = text.last,
           !CharacterSet.punctuationCharacters.contains(Unicode.Scalar(String(lastChar))!) {
            text += "."
        }
        
        // Trigger haptic feedback for voice integration
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
    
    func replaceWithVoiceText(_ voiceText: String) {
        // Alternative method to replace entire text with voice input
        let trimmedVoice = voiceText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedVoice.isEmpty else { return }
        
        text = trimmedVoice
        
        // Ensure text ends properly
        if let lastChar = text.last,
           !CharacterSet.punctuationCharacters.contains(Unicode.Scalar(String(lastChar))!) {
            text += "."
        }
        
        // Trigger haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
    
    func save() async -> Bool {
        guard canSave else { return false }
        
        isSaving = true
        saveError = nil
        
        do {
            // Simulate save operation - integrate with actual DeclarationViewModel
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
            
            // Clear draft after successful save
            clearDraft()
            hasUnsavedChanges = false
            
            isSaving = false
            return true
            
        } catch {
            saveError = "Failed to save: \(error.localizedDescription)"
            isSaving = false
            return false
        }
    }
    
    func saveDraft() {
        guard !text.isEmpty else { return }
        
        let draft = DraftEntry(
            text: text,
            contentType: contentType,
            createdAt: Date(),
            wordCount: wordCount
        )
        
        if let encoded = try? JSONEncoder().encode(draft) {
            UserDefaults.standard.set(encoded, forKey: draftKey)
        }
    }
    
    func clearDraft() {
        UserDefaults.standard.removeObject(forKey: draftKey)
    }
    
    func resetEntry() {
        text = existingText
        hasUnsavedChanges = false
        saveError = nil
        clearDraft()
    }
    
    func getContextualPrompt() -> String {
        switch contentType {
        case .affirmation:
            if text.isEmpty {
                return "What truth do you want to speak over your life today?"
            } else if wordCount < 5 {
                return "Let God's promises flow through your words..."
            } else {
                return "Speak life and watch it manifest!"
            }
        case .journal:
            if text.isEmpty {
                return "What is God showing you in this moment?"
            } else if wordCount < 10 {
                return "Pour out your heart... He's listening."
            } else {
                return "Your faith journey is worth recording!"
            }
        }
    }
    
    func getPlaceholderText() -> String {
        switch contentType {
        case .affirmation:
            return "I am blessed, chosen, and deeply loved by God. He has plans to prosper me and give me hope..."
        case .journal:
            return "Today I'm grateful for God's faithfulness. I see His hand moving in my life through..."
        }
    }
    
    // MARK: - Private Methods
    private func setupTextChangeObserver() {
        $text
            .debounce(for: .seconds(2), scheduler: RunLoop.main)
            .sink { [weak self] newText in
                self?.handleTextChange(newText)
            }
            .store(in: &cancellables)
        
        $text
            .map { [weak self] newText in
                newText != self?.existingText && !newText.isEmpty
            }
            .assign(to: &$hasUnsavedChanges)
    }
    
    private func handleTextChange(_ newText: String) {
        if hasUnsavedChanges && !newText.isEmpty {
            saveDraft()
        }
        
        // Reset auto-save timer
        autoSaveTimer?.invalidate()
        autoSaveTimer = Timer.scheduledTimer(withTimeInterval: autoSaveInterval, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.saveDraft()
            }
        }
    }
    
    private func loadDraftIfNeeded() {
        guard !isEditing, existingText.isEmpty else { return }
        
        // Try to load any recent draft
        let recentDraftKey = "draft_\(contentType.rawValue)"
        if let draftData = UserDefaults.standard.data(forKey: recentDraftKey),
           let draft = try? JSONDecoder().decode(DraftEntry.self, from: draftData),
           Date().timeIntervalSince(draft.createdAt) < 3600 { // Within last hour
            
            text = draft.text
            hasUnsavedChanges = true
        }
    }
}

// MARK: - Draft Entry Model
struct DraftEntry: Codable {
    let text: String
    let contentType: ContentType
    let createdAt: Date
    let wordCount: Int
}

// MARK: - Extensions
extension EntryViewModel {
    var progressInfo: String {
        if wordCount == 0 {
            return "Start typing or use voice input"
        } else if wordCount < 10 {
            return "\(wordCount) words - Keep going!"
        } else if wordCount < 50 {
            return "\(wordCount) words - You're building something beautiful"
        } else {
            return "\(wordCount) words - Powerful reflection!"
        }
    }
    
    var shouldShowLengthWarning: Bool {
        characterCount > 1000
    }
}