//
//  VoiceStateIndicator.swift
//  SpeakLife
//
//  Voice state indicator UI component for showing voice input status
//

import SwiftUI

struct VoiceStateIndicator: View {
    let state: VoiceInputState
    
    var body: some View {
        HStack(spacing: 12) {
            // Status icon
            statusIcon
                .foregroundColor(statusColor)
                .font(.system(size: 16, weight: .medium))
            
            // Status text
            Text(statusText)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.9))
            
            Spacer()
            
            // Animated pulse indicator
            if state == .listening || state == .transcribing {
                pulseIndicator
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(statusBackgroundColor)
        .cornerRadius(12)
    }
    
    // MARK: - Computed Properties
    private var statusIcon: Image {
        switch state {
        case .idle:
            return Image(systemName: "mic")
        case .listening:
            return Image(systemName: "mic.fill")
        case .processing:
            return Image(systemName: "waveform")
        case .transcribing:
            return Image(systemName: "text.bubble")
        case .paused:
            return Image(systemName: "pause.circle")
        case .completed:
            return Image(systemName: "checkmark.circle")
        case .error:
            return Image(systemName: "exclamationmark.triangle")
        }
    }
    
    private var statusText: String {
        switch state {
        case .idle:
            return "Ready to listen"
        case .listening:
            return "Listening..."
        case .processing:
            return "Processing speech"
        case .transcribing:
            return "Converting to text"
        case .paused:
            return "Paused"
        case .completed:
            return "Speech captured"
        case .error:
            return "Voice input error"
        }
    }
    
    private var statusColor: Color {
        switch state {
        case .idle:
            return .white.opacity(0.7)
        case .listening, .transcribing:
            return .green
        case .processing:
            return .blue
        case .paused:
            return .orange
        case .completed:
            return .green
        case .error:
            return .red
        }
    }
    
    private var statusBackgroundColor: Color {
        switch state {
        case .error:
            return Color.red.opacity(0.2)
        case .listening, .transcribing:
            return Color.green.opacity(0.1)
        case .processing:
            return Color.blue.opacity(0.1)
        default:
            return Color.white.opacity(0.05)
        }
    }
    
    private var pulseIndicator: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(statusColor)
                    .frame(width: 6, height: 6)
                    .scaleEffect(animationScale)
                    .animation(
                        .easeInOut(duration: 0.6)
                        .repeatForever()
                        .delay(Double(index) * 0.2),
                        value: animationScale
                    )
            }
        }
        .onAppear {
            animationScale = 1.2
        }
    }
    
    @State private var animationScale: CGFloat = 0.8
}

// MARK: - Preview
#if DEBUG
struct VoiceStateIndicator_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 16) {
            VoiceStateIndicator(state: .idle)
            VoiceStateIndicator(state: .listening)
            VoiceStateIndicator(state: .transcribing)
            VoiceStateIndicator(state: .processing)
            VoiceStateIndicator(state: .completed)
            VoiceStateIndicator(state: .error)
        }
        .padding()
        .background(Color.black)
        .previewDisplayName("Voice State Indicators")
    }
}
#endif