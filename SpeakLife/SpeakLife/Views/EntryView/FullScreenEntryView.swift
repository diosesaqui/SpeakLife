//
//  FullScreenEntryView.swift
//  SpeakLife
//
//  Beautiful full-screen journal and affirmation entry with voice input
//

import SwiftUI

struct FullScreenEntryView: View {
    let contentType: ContentType
    let existingText: String
    let isEditing: Bool
    let editingDeclaration: Declaration?
    
    @StateObject private var viewModel: EntryViewModel
    @StateObject private var voiceManager = VoiceInputManager()
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var declarationStore: DeclarationViewModel
    
    @State private var showingSaveConfirmation = false
    @State private var showingDiscardAlert = false
    @State private var keyboardHeight: CGFloat = 0
    @FocusState private var isTextFieldFocused: Bool
    
    // Convert FocusState.Binding to regular Binding for compatibility
    private var textFieldFocusBinding: Binding<Bool> {
        Binding(
            get: { isTextFieldFocused },
            set: { isTextFieldFocused = $0 }
        )
    }
    
    init(contentType: ContentType, existingText: String = "", isEditing: Bool = false, editingDeclaration: Declaration? = nil) {
        self.contentType = contentType
        self.existingText = existingText
        self.isEditing = isEditing
        self.editingDeclaration = editingDeclaration
        self._viewModel = StateObject(wrappedValue: EntryViewModel(
            contentType: contentType,
            existingText: existingText,
            isEditing: isEditing
        ))
    }
    
    var body: some View {
        ZStack {
            // Spiritual background
            SpiritualBackgroundView()
                .ignoresSafeArea()
            
           VStack(spacing: 0) {
                    // Voice state indicator (when active)
                    if voiceManager.voiceInputState != .idle {
                        VoiceStateIndicator(state: voiceManager.voiceInputState)
                            .padding(.horizontal)
                            .padding(.bottom, 8)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                    
                    // Error message display
                    if let errorMessage = voiceManager.errorMessage {
                        ErrorBanner(message: errorMessage) {
                            voiceManager.clearTranscription()
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                    }
                    
                    // Main content area
                    ContentInputView(
                        text: $viewModel.text,
                        voiceManager: voiceManager,
                        contentType: contentType,
                        isTextFieldFocused: textFieldFocusBinding
                    )
                .padding(.bottom, 16)
                
                // Voice input toolbar
//                VoiceInputToolbar(
//                    voiceManager: voiceManager,
//                    viewModel: viewModel
//                )
//                .padding(.horizontal, 16)
//                .padding(.bottom, 8)
                
                // Save/Cancel toolbar
                EntryActionToolbar(
                    viewModel: viewModel,
                    onSave: handleSave,
                    onCancel: handleCancel
                )
                .cornerRadius(8)
                .padding(.horizontal, 16)
                .padding(.bottom, keyboardHeight > 0 ? max(keyboardHeight - 100, 20) : 20)
                
            }
            
            // Save confirmation overlay
            if showingSaveConfirmation {
                SaveConfirmationView(contentType: contentType) {
                    dismiss()
                }
                .transition(.scale.combined(with: .opacity))
                .zIndex(1)
            }
        }
        .onTapGesture {
            // Dismiss keyboard when tapping outside
            if isTextFieldFocused {
                isTextFieldFocused = false
            }
        }
        .onKeyboardHeightChange { height in
            withAnimation(.easeInOut(duration: 0.3)) {
                keyboardHeight = height
            }
        }
//        .onAppear {
//            setupVoiceInput()
//        }
//        .onDisappear {
//            cleanupVoiceInput()
//        }
//        .onChange(of: voiceManager.transcribedText) { newText in
//            handleVoiceTranscription(newText)
//        }
        .alert("Discard Changes?", isPresented: $showingDiscardAlert) {
            Button("Discard", role: .destructive) {
                viewModel.clearDraft()
                safeDismiss()
            }
            Button("Keep Editing", role: .cancel) { }
        } message: {
            Text("You have unsaved changes. Are you sure you want to discard them?")
        }
    }
    
    // MARK: - Private Methods
    private func setupVoiceInput() {
        Task {
            await voiceManager.requestPermissions()
        }
    }
    
    private func cleanupVoiceInput() {
        if voiceManager.isListening {
            // Save any pending transcription before stopping
            if !voiceManager.transcribedText.isEmpty {
                handleVoiceTranscription(voiceManager.transcribedText)
            }
            voiceManager.stopListening()
        }
    }
    
    private func handleVoiceTranscription(_ newText: String) {
        guard !newText.isEmpty else { return }
        
        // Only process if this is genuinely new content
        let trimmedNew = newText.trimmingCharacters(in: .whitespacesAndNewlines)
        let currentText = viewModel.text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Accept even short transcriptions (1 character or more)
        guard trimmedNew != currentText && trimmedNew.count > 0 else { return }
        
        // Append transcription when voice input completes or when stopping
        if voiceManager.voiceInputState == .completed || !voiceManager.isListening {
            // More lenient duplicate check - only check exact matches
            if currentText.isEmpty || currentText != trimmedNew {
                // If the new text starts with the current text, just append the difference
                if trimmedNew.starts(with: currentText) && currentText.count > 0 {
                    let difference = String(trimmedNew.dropFirst(currentText.count)).trimmingCharacters(in: .whitespaces)
                    if !difference.isEmpty {
                        viewModel.appendVoiceText(difference)
                    }
                } else if !currentText.contains(trimmedNew) {
                    // Only append if it's not already contained
                    viewModel.appendVoiceText(trimmedNew)
                }
                
                // Clear after a short delay to ensure it's processed
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.voiceManager.clearTranscription()
                }
            }
        }
    }
    
    private func handleSave() {
        guard viewModel.canSave else { return }
        
        // Stop any active voice input
        if voiceManager.isListening {
            voiceManager.stopListening()
        }
        
        // Blur text field
        isTextFieldFocused = false
        
        Task { @MainActor in
            
            do {
                let success = await saveEntry()
                if success {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                        showingSaveConfirmation = true
                    }
                    
                    // Auto-dismiss after showing confirmation
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                        safeDismiss()
                    }
                } else {
                    // Handle save failure
                    print("Save failed")
                }
            } catch {
                print("Save error: \(error)")
            }
        }
    }
    
    private func handleCancel() {
        // Stop any active voice input safely
        cleanupVoiceInput()
        
        // Check for unsaved changes
        if viewModel.hasUnsavedChanges {
            showingDiscardAlert = true
        } else {
            safeDismiss()
        }
    }
    
    private func safeDismiss() {
        // Ensure cleanup before dismissing
        cleanupVoiceInput()
        
        // Dismiss on main thread
        DispatchQueue.main.async {
            dismiss()
        }
    }
    
    private func saveEntry() async -> Bool {
        // Integrate with existing DeclarationViewModel
        let finalText = viewModel.text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Ensure text is not empty
        guard !finalText.isEmpty else { return false }
        
        do {
            await MainActor.run {
                if isEditing, let originalDeclaration = editingDeclaration {
                    // Remove the old declaration first
                    declarationStore.removeOwn(declaration: originalDeclaration)
                }
                // Create the new/updated declaration
                declarationStore.createDeclaration(finalText, contentType: contentType)
            }
            
            // Save to view model
            let success = await viewModel.save()
            return success
            
        } catch {
            print("Error saving entry: \(error)")
            return false
        }
    }
}

// MARK: - Supporting Views

struct SpiritualBackgroundView: View {
    var body: some View {
        // Simple static gradient background
        LinearGradient(
            colors: [
                Color(red: 0.1, green: 0.05, blue: 0.25),
                Color(red: 0.15, green: 0.1, blue: 0.35),
                Color(red: 0.08, green: 0.04, blue: 0.2)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

struct EntryHeaderView: View {
    let contentType: ContentType
    let isEditing: Bool
    let wordCount: Int
    let onCancel: () -> Void
    
    var body: some View {
        HStack {
            // Cancel button
            Button(action: onCancel) {
                HStack(spacing: 6) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .medium))
                    Text("Cancel")
                        .font(.system(size: 16, weight: .medium))
                }
                .foregroundColor(.white.opacity(0.8))
            }
            
            Spacer()
            
            // Title and progress
            VStack(spacing: 4) {
                Text(isEditing ? "Edit \(contentType.displayName)" : "New \(contentType.displayName)")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                
                if wordCount > 0 {
                    Text("\(wordCount) words")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            
            Spacer()
            
            // Placeholder for balance
            Color.clear
                .frame(width: 80)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 16)
    }
}

struct ErrorBanner: View {
    let message: String
    let onDismiss: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
            
            Text(message)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(2)
            
            Spacer()
            
            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .padding(12)
        .background(Color.red.opacity(0.2))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.red.opacity(0.4), lineWidth: 1)
        )
    }
}

// MARK: - Preview
#if DEBUG
struct FullScreenEntryView_Previews: PreviewProvider {
    static var previews: some View {
        FullScreenEntryView(contentType: .affirmation)
            .environmentObject(DeclarationViewModel(apiService: LocalAPIClient()))
            .previewDisplayName("New Affirmation")
        
        FullScreenEntryView(
            contentType: .journal,
            existingText: "God is showing me His faithfulness today...",
            isEditing: true,
            editingDeclaration: nil
        )
        .environmentObject(DeclarationViewModel(apiService: LocalAPIClient()))
        .previewDisplayName("Edit Journal")
    }
}
#endif
