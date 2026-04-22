//
//  HighlightedDeclarationText.swift
//  SpeakLife
//
//  Renders declaration text word-by-word with real-time highlighting
//  as the user speaks each word during verification.
//

import SwiftUI

struct HighlightedDeclarationText: View {
    /// Raw declaration words (pre-split, preserves original capitalisation/punctuation for display)
    let displayWords: [String]
    /// Indices of matched words from DeclarationVerificationService
    let matchedIndices: Set<Int>
    /// Whether recording is active (dims unspoken words for contrast)
    let isRecording: Bool

    var body: some View {
        Text(attributed)
            .font(.system(size: 26, weight: .semibold, design: .rounded))
            .lineSpacing(6)
            .multilineTextAlignment(.leading)
            .animation(.easeInOut(duration: 0.12), value: matchedIndices)
    }

    private var attributed: AttributedString {
        var result = AttributedString()
        for (i, word) in displayWords.enumerated() {
            var attr = AttributedString(word)
            if matchedIndices.contains(i) {
                // Spoken — gold highlight
                attr.foregroundColor = Color(red: 1.0, green: 0.82, blue: 0.28)
                attr.font = .system(size: 26, weight: .bold, design: .rounded)
            } else if isRecording {
                // Not yet spoken — dimmed while mic is active
                attr.foregroundColor = Color.white.opacity(0.3)
            } else {
                // Idle / done
                attr.foregroundColor = Color.white
            }
            result += attr
            if i < displayWords.count - 1 {
                result += AttributedString(" ")
            }
        }
        return result
    }
}
