//
//  VoiceInputToolbar.swift
//  SpeakLife
//
//  Voice input controls and feedback toolbar for spiritual journaling
//

import SwiftUI

struct VoiceInputToolbar: View {
    @ObservedObject var voiceManager: VoiceInputManager
    @ObservedObject var viewModel: EntryViewModel
    
    @State private var showingPermissionAlert = false
    @State private var showingVoiceTips = false
    
    var body: some View {
        HStack(spacing: 16) {
            // Entry progress info
            entryProgressView
            
            Spacer()
            
            // Voice tips button (when not listening)
            if !voiceManager.isListening {
                Button(action: { showingVoiceTips = true }) {
                    Image(systemName: "questionmark.circle")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            
            // Main voice input button
            VoiceMicrophoneButton(
                isListening: voiceManager.isListening,
                audioLevels: voiceManager.audioLevels,
                action: toggleVoiceInput
            )
            .disabled(!voiceManager.hasPermissions && !voiceManager.isListening)
            
            // Voice control buttons (when listening)
            if voiceManager.isListening {
                voiceControlButtons
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        )
        .alert("Microphone Permission Required", isPresented: $showingPermissionAlert) {
            Button("Settings") {
                openSettings()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("To use voice input for your spiritual journal, please enable microphone access in Settings.")
        }
        .sheet(isPresented: $showingVoiceTips) {
            VoiceTipsView()
        }
    }
    
    @ViewBuilder
    private var entryProgressView: some View {
        VStack(alignment: .leading, spacing: 2) {
            if viewModel.wordCount > 0 {
                Text("\(viewModel.wordCount) words")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                
                Text(viewModel.progressInfo)
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(1)
            } else {
                Text("Start writing")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                
                Text("or speak your thoughts")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.6))
            }
            
            // Voice input status
            if voiceManager.isListening {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 6, height: 6)
                        .opacity(0.8)
                    
                    Text("Listening...")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.red.opacity(0.9))
                }
                .transition(.opacity)
            }
        }
    }
    
    @ViewBuilder
    private var voiceControlButtons: some View {
        HStack(spacing: 12) {
            // Pause/Resume button
            Button(action: togglePauseResume) {
                Image(systemName: voiceManager.voiceInputState == .paused ? "play.circle.fill" : "pause.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.orange)
            }
            .buttonStyle(PlainButtonStyle())
            
            // Stop button
            Button(action: stopVoiceInput) {
                Image(systemName: "stop.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.red)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
    
    // MARK: - Actions
    private func toggleVoiceInput() {
        if voiceManager.isListening {
            stopVoiceInput() // Use our enhanced stop method that saves transcription
        } else {
            startVoiceInput()
        }
    }
    
    private func startVoiceInput() {
        if voiceManager.hasPermissions {
            voiceManager.startListening()
            
            // Haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
        } else {
            requestPermissions()
        }
    }
    
    private func stopVoiceInput() {
        // First stop listening to prevent further updates
        voiceManager.stopListening()
        
        // Wait a moment for final transcription results, then save
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            // Save any pending transcription after stopping
            if !self.voiceManager.transcribedText.isEmpty {
                let trimmedText = self.voiceManager.transcribedText.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmedText.count > 3 {
                    self.viewModel.appendVoiceText(trimmedText)
                }
                
                // Clear transcription immediately after saving to prevent duplication
                self.voiceManager.clearTranscription()
            }
        }
        
        // Gentle haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
    
    private func togglePauseResume() {
        if voiceManager.voiceInputState == .paused {
            voiceManager.resumeListening()
        } else {
            voiceManager.pauseListening()
        }
    }
    
    private func requestPermissions() {
        Task {
            let granted = await voiceManager.requestPermissions()
            await MainActor.run {
                if granted {
                    voiceManager.startListening()
                } else {
                    showingPermissionAlert = true
                }
            }
        }
    }
    
    private func openSettings() {
        if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsURL)
        }
    }
}

//struct EntryActionToolbar: View {
//    @ObservedObject var viewModel: EntryViewModel
//    let onSave: () -> Void
//    let onCancel: () -> Void
//    
//    @State private var saveButtonScale: CGFloat = 1.0
//    
//    var body: some View {
//        HStack(spacing: 16) {
//            // Cancel button
//            Button(action: onCancel) {
//                Text("Cancel")
//                    .font(.system(size: 16, weight: .medium))
//                    .foregroundColor(.white.opacity(0.8))
//                    .padding(.horizontal, 20)
//                    .padding(.vertical, 12)
//                    .background(
//                        RoundedRectangle(cornerRadius: 20)
//                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
//                            .background(
//                                RoundedRectangle(cornerRadius: 20)
//                                    .fill(Color.white.opacity(0.05))
//                            )
//                    )
//            }
//            .buttonStyle(PlainButtonStyle())
//            
//            Spacer()
//            
//            // Save button
//            Button(action: onSave) {
//                HStack(spacing: 8) {
//                    if viewModel.isSaving {
//                        ProgressView()
//                            .scaleEffect(0.8)
//                            .tint(.white)
//                    } else {
//                        Image(systemName: "checkmark")
//                            .font(.system(size: 16, weight: .semibold))
//                    }
//                    
//                    Text(viewModel.isSaving ? "Saving..." : "Save")
//                        .font(.system(size: 16, weight: .semibold))
//                }
//                .foregroundColor(.white)
//                .padding(.horizontal, 24)
//                .padding(.vertical, 12)
//                .background(
//                    RoundedRectangle(cornerRadius: 20)
//                        .fill(
//                            viewModel.canSave ? 
//                            LinearGradient(
//                                colors: [Color.blue, Color.blue.opacity(0.8)],
//                                startPoint: .topLeading,
//                                endPoint: .bottomTrailing
//                            ) :
//                            LinearGradient(
//                                colors: [Color.gray.opacity(0.3), Color.gray.opacity(0.2)],
//                                startPoint: .topLeading,
//                                endPoint: .bottomTrailing
//                            )
//                        )
//                        .shadow(
//                            color: viewModel.canSave ? Color.blue.opacity(0.3) : Color.clear,
//                            radius: 8,
//                            x: 0,
//                            y: 4
//                        )
//                )
//                .scaleEffect(saveButtonScale)
//            }
//            .buttonStyle(PlainButtonStyle())
//            .disabled(!viewModel.canSave)
//            .onAppear {
//                startSaveButtonAnimation()
//            }
//        }
//        .padding(.horizontal, 20)
//        .padding(.vertical, 16)
//        .background(
//            RoundedRectangle(cornerRadius: 16)
//                .fill(Color.white.opacity(0.08))
//                .overlay(
//                    RoundedRectangle(cornerRadius: 16)
//                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
//                )
//        )
//    }
//    
//    private func startSaveButtonAnimation() {
//        guard viewModel.canSave else { return }
//        
//        withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
//            saveButtonScale = 1.05
//        }
//    }
//}

struct VoiceTipsView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Voice Input Tips")
                            .font(.title.bold())
                            .foregroundColor(.primary)
                        
                        Text("Make the most of voice input for your spiritual journaling")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    // Tips
                    VStack(spacing: 16) {
                        TipCard(
                            icon: "mic.fill",
                            title: "Speak Clearly",
                            description: "Find a quiet space and speak at a normal pace. The app works better with clear pronunciation."
                        )
                        
                        TipCard(
                            icon: "pause.circle",
                            title: "Natural Pauses",
                            description: "Take natural pauses while speaking. The app will detect sentence breaks and add punctuation automatically."
                        )
                        
                        TipCard(
                            icon: "textformat",
                            title: "Spiritual Terms",
                            description: "The app recognizes spiritual vocabulary like 'God', 'Jesus', 'prayer', and 'blessing' and capitalizes them appropriately."
                        )
                        
                        TipCard(
                            icon: "hand.raised",
                            title: "Edit After Speaking",
                            description: "Voice input creates a foundation. You can always edit, add, or refine your text afterward."
                        )
                        
                        TipCard(
                            icon: "arrow.triangle.2.circlepath",
                            title: "Mix Voice & Typing",
                            description: "Switch between voice input and typing seamlessly. Start with voice, then type to add details."
                        )
                        
                        TipCard(
                            icon: "heart.fill",
                            title: "Speak from the Heart",
                            description: "Voice input captures the emotion and authenticity of your spiritual reflections better than typing alone."
                        )
                    }
                }
                .padding(20)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct TipCard: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(.blue)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

#if DEBUG
struct VoiceInputToolbar_Previews: PreviewProvider {
    static var previews: some View {
        VoiceInputToolbar(
            voiceManager: VoiceInputManager(),
            viewModel: EntryViewModel(contentType: .affirmation)
        )
        .background(Color.black)
        .previewDisplayName("Voice Toolbar")
    }
}
#endif
