//
//  VoiceCorrectionsView.swift
//  SpeakLife
//
//  Shows voice transcription alternatives and confidence for manual correction
//

import SwiftUI

struct VoiceCorrectionsView: View {
    @ObservedObject var voiceManager: VoiceInputManager
    @Binding var text: String
    @State private var showAlternatives = false
    
    var body: some View {
        VStack(spacing: 8) {
            // Confidence indicator
            if voiceManager.transcriptionConfidence > 0 && voiceManager.hasContent {
                confidenceIndicator
            }
            
            // Show alternatives button
            if !voiceManager.alternativeTranscriptions.isEmpty {
                alternativesSection
            }
        }
        .padding(.horizontal, 20)
        .animation(.easeInOut(duration: 0.3), value: showAlternatives)
    }
    
    private var confidenceIndicator: some View {
        HStack(spacing: 8) {
            Image(systemName: getConfidenceIcon())
                .foregroundColor(getConfidenceColor())
                .font(.system(size: 14))
            
            Text("Confidence: \(Int(voiceManager.transcriptionConfidence * 100))%")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
            
            if voiceManager.transcriptionConfidence < 0.7 {
                Button(action: { showAlternatives.toggle() }) {
                    Text("See alternatives")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.blue)
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
    
    @ViewBuilder
    private var alternativesSection: some View {
        if showAlternatives {
            VStack(alignment: .leading, spacing: 8) {
                Text("Did you mean:")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                
                ForEach(voiceManager.alternativeTranscriptions, id: \.self) { alternative in
                    Button(action: {
                        // Replace the current transcription with the alternative
                        let currentVoiceText = voiceManager.transcribedText
                        if text.hasSuffix(currentVoiceText) {
                            // Replace the last part
                            text = String(text.dropLast(currentVoiceText.count)) + alternative
                        } else {
                            // Just replace the voice text
                            text = alternative
                        }
                        voiceManager.transcribedText = alternative
                        showAlternatives = false
                    }) {
                        HStack {
                            Text(alternative)
                                .font(.system(size: 14))
                                .foregroundColor(.white)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                            
                            Spacer()
                            
                            Image(systemName: "arrow.right.circle")
                                .foregroundColor(.white.opacity(0.5))
                                .font(.system(size: 14))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
                
                Button(action: { showAlternatives = false }) {
                    Text("Keep original")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                }
                .padding(.top, 4)
            }
            .padding(12)
            .background(Color.black.opacity(0.3))
            .cornerRadius(12)
            .transition(.asymmetric(
                insertion: .scale.combined(with: .opacity),
                removal: .scale.combined(with: .opacity)
            ))
        }
    }
    
    private func getConfidenceIcon() -> String {
        switch voiceManager.transcriptionConfidence {
        case 0.8...1.0:
            return "checkmark.circle.fill"
        case 0.6..<0.8:
            return "exclamationmark.circle.fill"
        default:
            return "questionmark.circle.fill"
        }
    }
    
    private func getConfidenceColor() -> Color {
        switch voiceManager.transcriptionConfidence {
        case 0.8...1.0:
            return .green
        case 0.6..<0.8:
            return .yellow
        default:
            return .orange
        }
    }
}

// MARK: - Quick Corrections Menu
struct VoiceQuickCorrections: View {
    @ObservedObject var voiceManager: VoiceInputManager
    @Binding var text: String
    
    private let commonCorrections = [
        ("Add period", "."),
        ("Add comma", ","),
        ("New paragraph", "\n\n"),
        ("Capitalize", nil)
    ]
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(commonCorrections, id: \.0) { correction in
                    Button(action: {
                        applyCorrection(correction)
                    }) {
                        Text(correction.0)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.white.opacity(0.15))
                            .cornerRadius(16)
                    }
                }
                
                if voiceManager.voiceInputState == .error {
                    Button(action: {
                        voiceManager.startListening()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 11))
                            Text("Retry")
                        }
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.orange)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.orange.opacity(0.15))
                        .cornerRadius(16)
                    }
                }
            }
            .padding(.horizontal, 20)
        }
        .frame(height: 40)
    }
    
    private func applyCorrection(_ correction: (String, String?)) {
        if let addition = correction.1 {
            text += addition
        } else if correction.0 == "Capitalize" {
            // Capitalize last sentence
            if let lastSentenceRange = text.range(of: #"[.!?]\s*[a-z]"#, options: [.regularExpression, .backwards]) {
                let charToCapitalize = text[lastSentenceRange].last!
                text.replaceSubrange(lastSentenceRange, with: text[lastSentenceRange].uppercased())
            } else if let firstChar = text.first, firstChar.isLowercase {
                text = text.prefix(1).uppercased() + text.dropFirst()
            }
        }
    }
}