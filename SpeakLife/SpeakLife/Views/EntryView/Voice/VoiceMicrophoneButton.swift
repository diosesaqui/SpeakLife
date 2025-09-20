//
//  VoiceMicrophoneButton.swift
//  SpeakLife
//
//  Beautiful microphone button with audio visualization for voice input
//

import SwiftUI

struct VoiceMicrophoneButton: View {
    let isListening: Bool
    let audioLevels: [Float]
    let action: () -> Void
    
    @State private var pulseScale: CGFloat = 1.0
    @State private var glowIntensity: Double = 0.3
    @State private var rotationAngle: Double = 0
    
    var body: some View {
        Button(action: action) {
            ZStack {
                // Outer glow ring
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                (isListening ? Color.red : Color.blue).opacity(glowIntensity),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 20,
                            endRadius: 40
                        )
                    )
                    .frame(width: 80, height: 80)
                    .scaleEffect(pulseScale)
                
                // Background circle
                Circle()
                    .fill(isListening ? Color.red.opacity(0.2) : Color.blue.opacity(0.1))
                    .frame(width: 60, height: 60)
                    .overlay(
                        Circle()
                            .stroke(
                                isListening ? Color.red.opacity(0.6) : Color.blue.opacity(0.4),
                                lineWidth: 2
                            )
                    )
                
                // Audio level visualization (when listening)
                if isListening && !audioLevels.isEmpty {
                    AudioWaveformView(levels: audioLevels)
                        .frame(width: 44, height: 44)
                } else {
                    // Microphone icon
                    Image(systemName: isListening ? "mic.fill" : "mic")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(isListening ? .red : .blue)
                }
                
                // Recording indicator dot
                if isListening {
                    VStack {
                        HStack {
                            Spacer()
                            Circle()
                                .fill(Color.red)
                                .frame(width: 8, height: 8)
                                .opacity(pulseScale > 1.05 ? 1 : 0.5)
                        }
                        Spacer()
                    }
                    .frame(width: 60, height: 60)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .onChange(of: isListening) { listening in
            withAnimation(.easeInOut(duration: 0.3)) {
                if listening {
                    startListeningAnimations()
                } else {
                    stopListeningAnimations()
                }
            }
        }
        .onAppear {
            startIdleAnimations()
        }
    }
    
    private func startIdleAnimations() {
        withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
            glowIntensity = 0.6
        }
        
        withAnimation(.linear(duration: 8.0).repeatForever(autoreverses: false)) {
            rotationAngle = 360
        }
    }
    
    private func startListeningAnimations() {
        withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
            pulseScale = 1.15
        }
        
        withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
            glowIntensity = 0.9
        }
    }
    
    private func stopListeningAnimations() {
        withAnimation(.easeInOut(duration: 0.5)) {
            pulseScale = 1.0
            glowIntensity = 0.3
        }
    }
}

struct AudioWaveformView: View {
    let levels: [Float]
    @State private var animateWaves = false
    
    var body: some View {
        HStack(alignment: .center, spacing: 1.5) {
            ForEach(0..<min(levels.count, 12), id: \.self) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(
                        LinearGradient(
                            colors: [Color.red.opacity(0.8), Color.red],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .frame(width: 2.5)
                    .frame(height: max(CGFloat(levels[index]) * 30 + 4, 4))
                    .animation(.easeInOut(duration: 0.1), value: levels[index])
                    .scaleEffect(animateWaves ? 1.1 : 1.0)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.3).repeatForever(autoreverses: true)) {
                animateWaves = true
            }
        }
    }
}

//struct VoiceStateIndicator: View {
//    let state: VoiceInputState
//    @State private var pulseOpacity: Double = 1.0
//    
//    var body: some View {
//        HStack(spacing: 8) {
//            stateIcon
//            stateText
//        }
//        .padding(.horizontal, 16)
//        .padding(.vertical, 8)
//        .background(stateBackgroundColor)
//        .foregroundColor(stateTextColor)
//        .cornerRadius(20)
//        .shadow(color: stateBackgroundColor.opacity(0.3), radius: 4, x: 0, y: 2)
//        .opacity(pulseOpacity)
//        .animation(.easeInOut(duration: 0.3), value: state)
//        .onAppear {
//            if state == .listening || state == .transcribing {
//                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
//                    pulseOpacity = 0.7
//                }
//            }
//        }
//    }
//    
//    @ViewBuilder
//    private var stateIcon: some View {
//        switch state {
//        case .idle:
//            Image(systemName: "mic")
//        case .listening:
//            Image(systemName: "mic.fill")
//                .scaleEffect(pulseOpacity > 0.8 ? 1.1 : 1.0)
//                .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: pulseOpacity)
//        case .processing:
//            ProgressView()
//                .scaleEffect(0.8)
//                .tint(stateTextColor)
//        case .transcribing:
//            Image(systemName: "waveform")
//                .opacity(pulseOpacity)
//                .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: pulseOpacity)
//        case .paused:
//            Image(systemName: "pause.circle.fill")
//        case .completed:
//            Image(systemName: "checkmark.circle.fill")
//        case .error:
//            Image(systemName: "exclamationmark.triangle.fill")
//        }
//    }
//    
//    private var stateText: Text {
//        switch state {
//        case .idle: 
//            return Text("Tap to speak")
//        case .listening: 
//            return Text("Listening...")
//        case .processing: 
//            return Text("Processing...")
//        case .transcribing: 
//            return Text("Converting speech...")
//        case .paused: 
//            return Text("Paused")
//        case .completed: 
//            return Text("Voice input complete")
//        case .error: 
//            return Text("Voice input error")
//        }
//    }
//    
//    private var stateBackgroundColor: Color {
//        switch state {
//        case .idle: 
//            return .blue.opacity(0.15)
//        case .listening: 
//            return .red.opacity(0.2)
//        case .processing, .transcribing: 
//            return .orange.opacity(0.2)
//        case .paused: 
//            return .yellow.opacity(0.2)
//        case .completed: 
//            return .green.opacity(0.2)
//        case .error: 
//            return .red.opacity(0.25)
//        }
//    }
//    
//    private var stateTextColor: Color {
//        switch state {
//        case .idle: 
//            return .blue
//        case .listening: 
//            return .red
//        case .processing, .transcribing: 
//            return .orange
//        case .paused: 
//            return .yellow.opacity(0.9)
//        case .completed: 
//            return .green
//        case .error: 
//            return .red
//        }
//    }
//}
//
//#if DEBUG
//struct VoiceMicrophoneButton_Previews: PreviewProvider {
//    static var previews: some View {
//        VStack(spacing: 40) {
//            VoiceMicrophoneButton(
//                isListening: false,
//                audioLevels: [],
//                action: {}
//            )
//            .previewDisplayName("Idle State")
//            
//            VoiceMicrophoneButton(
//                isListening: true,
//                audioLevels: [0.2, 0.5, 0.8, 0.3, 0.6, 0.4, 0.7, 0.2],
//                action: {}
//            )
//            .previewDisplayName("Listening State")
//            
//            VoiceStateIndicator(state: .listening)
//                .previewDisplayName("State Indicator")
//        }
//        .padding()
//        .background(Color.black)
//    }
//}
//#endif
