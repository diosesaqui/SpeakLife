//
//  VoiceDictationButton.swift
//  SpeakLife
//
//  A compact mic button that dictates speech into a bound text field using the
//  shared VoiceInputManager. Drop it into any input bar (chat, search, etc.);
//  it appends the recognized text to `text`.
//

import SwiftUI

struct VoiceDictationButton: View {
    @Binding var text: String
    /// Glyph point size; the frosted circle is sized around it.
    var size: CGFloat = 18

    @StateObject private var voiceManager = VoiceInputManager()
    @State private var voiceTask: Task<Void, Never>?

    private var isTranscribing: Bool {
        voiceManager.voiceInputState == .processing || voiceManager.voiceInputState == .transcribing
    }

    private var diameter: CGFloat { size + 16 }

    private var glyphColor: Color {
        if isTranscribing { return .white.opacity(0.4) }
        return voiceManager.isListening ? .white : .white.opacity(0.9)
    }

    var body: some View {
        Button(action: toggle) {
            Image(systemName: voiceManager.isListening ? "stop.fill" : "mic.fill")
                .font(.system(size: size, weight: .semibold))
                .foregroundColor(glyphColor)
                .frame(width: diameter, height: diameter)
                .background(
                    Circle().fill(voiceManager.isListening
                                  ? AnyShapeStyle(Color.red)
                                  : AnyShapeStyle(.ultraThinMaterial))
                )
                .overlay(
                    Circle().stroke(Color.white.opacity(voiceManager.isListening ? 0 : 0.18), lineWidth: 1)
                )
        }
        .disabled(isTranscribing)
        .accessibilityLabel(voiceManager.isListening ? "Stop dictation" : "Dictate")
        .onChange(of: voiceManager.voiceInputState) { state in
            // Recognition is final-only, so the transcript is ready on .completed.
            if state == .completed { append(voiceManager.transcribedText) }
        }
        .onDisappear {
            // Cancel a pending permission request so it can't start recording
            // after the view is gone, and stop any active recording.
            voiceTask?.cancel()
            voiceManager.stopListening()
        }
    }

    private func toggle() {
        if voiceManager.isListening {
            voiceManager.stopListening()
            return
        }
        if voiceManager.hasPermissions {
            voiceManager.startListening()
        } else {
            voiceTask = Task {
                let granted = await voiceManager.requestPermissions()
                if Task.isCancelled { return }
                if granted {
                    voiceManager.startListening()
                } else {
                    voiceManager.errorMessage = "Microphone access is off. Enable it in Settings to dictate."
                }
            }
        }
    }

    /// Append a finished transcription to the bound text, then clear it so the
    /// same text isn't merged twice on the next state change.
    private func append(_ transcription: String) {
        let trimmed = transcription.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            text = trimmed
        } else {
            let separator = text.hasSuffix(" ") || text.hasSuffix("\n") ? "" : " "
            text += separator + trimmed
        }
        voiceManager.clearTranscription()
    }
}
