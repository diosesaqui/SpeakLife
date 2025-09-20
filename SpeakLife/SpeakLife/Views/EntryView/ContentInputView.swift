//
//  ContentInputView.swift
//  SpeakLife
//
//  Main text editing area with voice input integration for spiritual journaling
//

import SwiftUI

struct ContentInputView: View {
    @Binding var text: String
    @ObservedObject var voiceManager: VoiceInputManager
    let contentType: ContentType
    @Binding var isTextFieldFocused: Bool
    
    @State private var showVoiceHint = false
    @State private var animatePrompt = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Top section with prompts
            VStack(spacing: 12) {
                contextualPromptSection
               // liveTranscriptionSection
                voiceCorrectionsSection
            }
            .padding(.bottom, 20)
            
            // Text input section - takes most space
            textInputSection
            
            // Voice quick corrections
            if voiceManager.hasContent || voiceManager.voiceInputState == .error {
                VoiceQuickCorrections(voiceManager: voiceManager, text: $text)
                    .padding(.vertical, 8)
            }
            
            // Bottom guidance
            contentGuidanceSection
                .padding(.top, 12)
        }
        .onAppear {
            setupAnimations()
        }
        .onTapGesture {
            if !isTextFieldFocused {
                isTextFieldFocused = true
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    hideKeyboard()
                }
                .foregroundColor(.blue)
            }
        }
    }
    
    // MARK: - Computed Properties
    private var wordCount: Int {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .count
    }
    
    // MARK: - View Components
    private var contextualPromptSection: some View {
        ContextualPromptView(
            contentType: contentType,
            wordCount: wordCount,
            animate: animatePrompt
        )
        .padding(.top, 20)
    }
    
    private var textInputSection: some View {
        TextInputAreaView(
            text: $text,
            voiceManager: voiceManager,
            showVoiceHint: showVoiceHint,
            placeholder: getPlaceholder(),
            isTextFieldFocused: isTextFieldFocused
        )
        .padding(.horizontal, 20)
        .frame(maxHeight: .infinity)
    }
    
    @ViewBuilder
    private var liveTranscriptionSection: some View {
        if voiceManager.isListening && !voiceManager.transcribedText.isEmpty {
            LiveTranscriptionView(
                transcribedText: voiceManager.transcribedText,
                voiceState: voiceManager.voiceInputState
            )
            .padding(.horizontal, 20)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
    
    @ViewBuilder
    private var voiceCorrectionsSection: some View {
        if voiceManager.hasContent || voiceManager.transcriptionConfidence > 0 {
            VoiceCorrectionsView(voiceManager: voiceManager, text: $text)
                .transition(.opacity)
        }
    }
    
    private var contentGuidanceSection: some View {
        ContentGuidanceView(
            contentType: contentType,
            characterCount: text.count,
            wordCount: wordCount
        )
        .padding(.horizontal, 20)
    }
    
    private var keyboardSpacer: some View {
        Color.clear.frame(height: 60)
    }
    
    // MARK: - Private Methods
    private func getPlaceholder() -> String {
        switch contentType {
        case .affirmation:
            return "I am blessed, chosen, and deeply loved by God..."
        case .journal:
            return "Today I'm grateful for God's faithfulness..."
        }
    }
    
    private func setupAnimations() {
        withAnimation(.easeInOut(duration: 0.8)) {
            animatePrompt = true
        }
        
//        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
//            withAnimation(.easeInOut(duration: 0.6)) {
//                showVoiceHint = true
//            }
//        }
    }
    
    private func hideKeyboard() {
        isTextFieldFocused = false
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

struct ContextualPromptView: View {
    let contentType: ContentType
    let wordCount: Int
    let animate: Bool
    
    var body: some View {
        VStack(spacing: 12) {
            // Main prompt
            Text(getMainPrompt())
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .opacity(animate ? 1.0 : 0.8)
            
            // Contextual subtitle
            Text(getSubPrompt())
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .opacity(animate ? 1.0 : 0.7)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
    }
    
    private func getMainPrompt() -> String {
        switch contentType {
        case .affirmation:
            if wordCount == 0 {
                return "What truth do you want to speak over your life?"
            } else if wordCount < 5 {
                return "Let God's promises flow..."
            } else {
                return "Speak life and watch it manifest!"
            }
        case .journal:
            if wordCount == 0 {
                return "What is God showing you today?"
            } else if wordCount < 10 {
                return "Pour out your heart..."
            } else {
                return "Your faith journey matters!"
            }
        }
    }
    
    private func getSubPrompt() -> String {
        switch contentType {
        case .affirmation:
            return "Declare God's truth with confidence"
        case .journal:
            return "He's listening to every word"
        }
    }
}

struct LiveTranscriptionView: View {
    let transcribedText: String
    let voiceState: VoiceInputState
    
    @State private var showCursor = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "waveform")
                    .font(.system(size: 14))
                    .foregroundColor(.blue)
                    .opacity(voiceState == .transcribing ? 0.6 : 1.0)
                    .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: voiceState == .transcribing)
                
                Text("Live transcription:")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                
                Spacer()
                
                if voiceState == .transcribing {
                    Text("Converting...")
                        .font(.system(size: 12))
                        .foregroundColor(.blue)
                        .opacity(0.8)
                }
            }
            
            HStack {
                Text(transcribedText)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(.white)
                    .lineLimit(nil)
                
                if showCursor && voiceState == .listening {
                    Text("|")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.blue)
                        .opacity(showCursor ? 1 : 0)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.blue.opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                )
        )
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8).repeatForever()) {
                showCursor.toggle()
            }
        }
    }
}

struct ContentGuidanceView: View {
    let contentType: ContentType
    let characterCount: Int
    let wordCount: Int
    
    var body: some View {
        VStack(spacing: 8) {
            if wordCount > 0 {
                HStack {
                    progressIndicator
                    Spacer()
                    progressText
                }
                .padding(.horizontal, 4)
            }
            
            if shouldShowLengthGuidance {
                lengthGuidanceMessage
            }
        }
        .padding(.vertical, 8)
    }
    
    @ViewBuilder
    private var progressIndicator: some View {
        HStack(spacing: 4) {
            ForEach(0..<5, id: \.self) { index in
                Circle()
                    .fill(index < progressLevel ? Color.green : Color.gray.opacity(0.3))
                    .frame(width: 6, height: 6)
                    .animation(.easeInOut(duration: 0.3), value: progressLevel)
            }
        }
    }
    
    private var progressText: some View {
        Text(getProgressMessage())
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(.white.opacity(0.7))
    }
    
    private var lengthGuidanceMessage: some View {
        HStack(spacing: 8) {
            Image(systemName: characterCount > 1000 ? "exclamationmark.triangle" : "info.circle")
                .font(.system(size: 12))
                .foregroundColor(characterCount > 1000 ? .orange : .blue)
            
            Text(getLengthMessage())
                .font(.system(size: 12))
                .foregroundColor(characterCount > 1000 ? .orange : .white.opacity(0.7))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill((characterCount > 1000 ? Color.orange : Color.blue).opacity(0.1))
        )
    }
    
    // MARK: - Computed Properties
    private var progressLevel: Int {
        switch wordCount {
        case 0: return 0
        case 1...5: return 1
        case 6...15: return 2
        case 16...30: return 3
        case 31...50: return 4
        default: return 5
        }
    }
    
    private var shouldShowLengthGuidance: Bool {
        characterCount > 500
    }
    
    // MARK: - Private Methods
    private func getProgressMessage() -> String {
        switch contentType {
        case .affirmation:
            switch wordCount {
            case 0: return "Start declaring truth"
            case 1...5: return "Building your affirmation"
            case 6...15: return "Powerful declarations"
            case 16...30: return "Comprehensive affirmation"
            default: return "Strong foundation of truth"
            }
        case .journal:
            switch wordCount {
            case 0: return "Begin your reflection"
            case 1...10: return "Opening your heart"
            case 11...25: return "Meaningful reflection"
            case 26...50: return "Deep spiritual insight"
            default: return "Rich spiritual journey"
            }
        }
    }
    
    private func getLengthMessage() -> String {
        if characterCount > 1000 {
            return "Consider shortening for better mobile reading"
        } else if characterCount > 750 {
            return "Getting lengthy but still manageable"
        } else {
            return "Perfect length for reflection and sharing"
        }
    }
}

// MARK: - Text Input Area Component
struct TextInputAreaView: View {
    @Binding var text: String
    @ObservedObject var voiceManager: VoiceInputManager
    let showVoiceHint: Bool
    let placeholder: String
    let isTextFieldFocused: Bool
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            placeholderAndHint
            textEditor
        }
    }
    
    @ViewBuilder
    private var placeholderAndHint: some View {
        if text.isEmpty && !voiceManager.isListening {
            VStack(alignment: .leading, spacing: 16) {
                placeholderText
                if showVoiceHint {
                    voiceHintBanner
                }
            }
        }
    }
    
    private var placeholderText: some View {
        Text(placeholder)
            .font(.system(size: 16, weight: .regular))
            .foregroundColor(.gray.opacity(0.8))
            .padding(.top, 16)
            .padding(.leading, 16)
            .lineLimit(3)
    }
    
    private var voiceHintBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "mic.fill")
                .font(.system(size: 16))
                .foregroundColor(.blue.opacity(0.7))
            
            Text("Tap the microphone to speak your thoughts")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.blue.opacity(0.1))
        .cornerRadius(12)
        .padding(.horizontal, 16)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
    
    private var textEditor: some View {
        ZStack(alignment: .topLeading) {
            // Background
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.08))
            
            // TextEditor
            if #available(iOS 16.0, *) {
                TextEditor(text: $text)
                    .font(.system(size: 16, weight: .regular, design: .rounded))
                    .foregroundColor(.white)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .padding(16)
            } else {
                TextEditor(text: $text)
                    .font(.system(size: 16, weight: .regular, design: .rounded))
                    .foregroundColor(.white)
                    .background(Color.clear)
                    .padding(16)
            }
        }
        .frame(minHeight: 200)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    voiceManager.isListening ?
                    Color.red.opacity(0.6) :
                    Color.white.opacity(isTextFieldFocused ? 0.4 : 0.2),
                    lineWidth: voiceManager.isListening ? 2 : 1
                )
        )
    }
    
}

#if DEBUG
struct ContentInputView_Previews: PreviewProvider {
    static var previews: some View {
        ContentInputViewPreviewWrapper()
            .background(Color.black)
            .previewDisplayName("Content Input")
    }
}

private struct ContentInputViewPreviewWrapper: View {
    @State private var text = "I am blessed and highly favored by God..."
    @State private var isTextFieldFocused = false
    
    var body: some View {
        ContentInputView(
            text: $text,
            voiceManager: VoiceInputManager(),
            contentType: .affirmation,
            isTextFieldFocused: $isTextFieldFocused
        )
    }
}
#endif
