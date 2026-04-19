//
//  PersonalDeclarationCard.swift
//  SpeakLife
//
//  Full-sheet personal declaration card.
//  "Speak It" records the user speaking their declaration (voice → faith loop).
//  Success animation fires when they finish.
//

import SwiftUI
import AVFoundation

// MARK: - Speak State

private enum SpeakState {
    case idle, recording, success
}

// MARK: - PersonalDeclarationCard

struct PersonalDeclarationCard: View {

    let declaration: PersonalDeclaration
    let onBreakthrough: () -> Void

    @Environment(\.dismiss) private var dismiss

    // Recording state
    @State private var speakState: SpeakState = .idle
    @State private var audioLevel: CGFloat = 0
    @State private var recorder: AVAudioRecorder?
    @State private var levelTimer: Timer?
    @State private var autoStopTimer: Timer?
    @State private var silenceSeconds: Double = 0

    // Animations
    @State private var successScale: CGFloat = 0.3
    @State private var successOpacity: Double = 0
    @State private var ringScale: [CGFloat] = [1, 1, 1]
    @State private var ringOpacity: [Double] = [0.5, 0.35, 0.2]
    @State private var cardAppear = false

    private var dayCount: Int {
        let days = Calendar.current.dateComponents([.day], from: declaration.startDate, to: Date()).day ?? 0
        return max(1, days + 1)
    }

    var body: some View {
        ZStack {
            // Background
            Color(red: 0.07, green: 0.08, blue: 0.14)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Drag handle
                Capsule()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 36, height: 4)
                    .padding(.top, 12)
                    .padding(.bottom, 24)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {

                        // ── Header ──────────────────────────────────────
                        HStack(alignment: .center) {
                            HStack(spacing: 6) {
                                Text("🙌")
                                    .font(.system(size: 14))
                                Text("YOUR DECLARATION")
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .tracking(1.2)
                                    .foregroundColor(Color(red: 1, green: 0.82, blue: 0.28))
                            }
                            Spacer()
                            dayBadge
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 28)

                        // ── Divider ──────────────────────────────────────
                        Rectangle()
                            .fill(Color.white.opacity(0.08))
                            .frame(height: 1)
                            .padding(.horizontal, 24)
                            .padding(.bottom, 32)

                        // ── Declaration text ────────────────────────────
                        Text(declaration.declarationText)
                            .font(.system(size: 26, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                            .lineSpacing(6)
                            .multilineTextAlignment(.leading)
                            .padding(.horizontal, 24)
                            .padding(.bottom, 24)

                        // ── Verse reference ──────────────────────────────
                        HStack(spacing: 6) {
                            Image(systemName: "book.closed.fill")
                                .font(.system(size: 12))
                                .foregroundColor(Color(red: 1, green: 0.82, blue: 0.28).opacity(0.8))
                            Text(declaration.verseReference)
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundColor(.white.opacity(0.55))
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 40)

                        // ── What you're believing for ────────────────────
                        VStack(alignment: .leading, spacing: 8) {
                            Text("WHAT YOU'RE BELIEVING FOR")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .tracking(1.2)
                                .foregroundColor(.white.opacity(0.35))
                            Text(declaration.beliefText)
                                .font(.system(size: 16, weight: .medium, design: .rounded))
                                .foregroundColor(.white.opacity(0.7))
                                .lineSpacing(3)
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 20)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.white.opacity(0.05))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                                )
                        )
                        .padding(.horizontal, 16)
                        .padding(.bottom, 40)
                    }
                }

                // ── Bottom action area ────────────────────────────────
                VStack(spacing: 16) {
                    // Primary: Speak It / Recording / Success
                    speakButton

                    // Secondary: Breakthrough
                    Button(action: onBreakthrough) {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 15, weight: .semibold))
                            Text("It Came to Pass")
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                        }
                        .foregroundColor(Color(red: 0.3, green: 0.9, blue: 0.55))
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(red: 0.3, green: 0.9, blue: 0.55).opacity(0.12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .strokeBorder(Color(red: 0.3, green: 0.9, blue: 0.55).opacity(0.3), lineWidth: 1)
                                )
                        )
                    }
                    .padding(.horizontal, 24)
                }
                .padding(.bottom, 36)
                .background(
                    // Fade from transparent to background
                    LinearGradient(
                        colors: [
                            Color(red: 0.07, green: 0.08, blue: 0.14).opacity(0),
                            Color(red: 0.07, green: 0.08, blue: 0.14)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 180)
                    .offset(y: -100)
                    .allowsHitTesting(false)
                )
            }

            // ── Success overlay ───────────────────────────────────────
            if speakState == .success {
                successOverlay
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                cardAppear = true
            }
        }
        .onDisappear { stopRecording() }
    }

    // MARK: - Day Badge

    private var dayBadge: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(Color(red: 1, green: 0.82, blue: 0.28))
                .frame(width: 6, height: 6)
            Text("Day \(dayCount)")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.7))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.08))
        )
    }

    // MARK: - Speak Button

    @ViewBuilder
    private var speakButton: some View {
        ZStack {
            // Pulse rings (visible during recording)
            if speakState == .recording {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .strokeBorder(Color(red: 0.98, green: 0.36, blue: 0.35).opacity(ringOpacity[i]), lineWidth: 1.5)
                        .frame(width: 72 + CGFloat(i) * 28 + audioLevel * 20,
                               height: 72 + CGFloat(i) * 28 + audioLevel * 20)
                        .scaleEffect(ringScale[i])
                        .animation(.easeInOut(duration: 0.1), value: audioLevel)
                }
            }

            Button(action: handleSpeakTap) {
                HStack(spacing: 10) {
                    Image(systemName: speakState == .recording ? "stop.fill" : "mic.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .symbolEffect(.bounce, value: speakState == .recording)
                    Text(speakState == .recording ? "Tap to Finish" : "Speak It")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 60)
                .background(
                    Group {
                        if speakState == .recording {
                            RoundedRectangle(cornerRadius: 18)
                                .fill(Color(red: 0.85, green: 0.22, blue: 0.22))
                        } else {
                            RoundedRectangle(cornerRadius: 18)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color(red: 0.38, green: 0.35, blue: 0.95),
                                            Color(red: 0.55, green: 0.35, blue: 0.95)
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        }
                    }
                )
                .shadow(color: speakState == .recording
                    ? Color(red: 0.85, green: 0.22, blue: 0.22).opacity(0.4)
                    : Color(red: 0.38, green: 0.35, blue: 0.95).opacity(0.4),
                    radius: 12, x: 0, y: 6)
                .scaleEffect(speakState == .recording ? 0.97 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: speakState)
            }
            .padding(.horizontal, 24)
        }
        .frame(height: 80)
    }

    // MARK: - Success Overlay

    private var successOverlay: some View {
        ZStack {
            Color.black.opacity(0.65)
                .ignoresSafeArea()
                .onTapGesture { dismissSuccess() }

            VStack(spacing: 20) {
                // Animated checkmark circle
                ZStack {
                    Circle()
                        .fill(Color(red: 0.3, green: 0.9, blue: 0.55).opacity(0.15))
                        .frame(width: 110, height: 110)
                    Circle()
                        .fill(Color(red: 0.3, green: 0.9, blue: 0.55).opacity(0.25))
                        .frame(width: 90, height: 90)
                    Image(systemName: "checkmark")
                        .font(.system(size: 38, weight: .bold))
                        .foregroundColor(Color(red: 0.3, green: 0.9, blue: 0.55))
                }
                .scaleEffect(successScale)
                .opacity(successOpacity)

                VStack(spacing: 8) {
                    Text("Well Spoken! 🙌")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text("Your faith is being built.\nKeep declaring this every day.")
                        .font(.system(size: 15, weight: .regular, design: .rounded))
                        .foregroundColor(.white.opacity(0.65))
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                }
                .opacity(successOpacity)

                Button(action: dismissSuccess) {
                    Text("Done")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .frame(width: 140, height: 48)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.15))
                                .overlay(Capsule().strokeBorder(Color.white.opacity(0.2), lineWidth: 1))
                        )
                }
                .opacity(successOpacity)
            }
            .padding(32)
        }
    }

    // MARK: - Recording Logic

    private func handleSpeakTap() {
        switch speakState {
        case .idle:   startRecording()
        case .recording: stopRecording(); showSuccess()
        case .success:   dismissSuccess()
        }
    }

    private func startRecording() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true)
        } catch { return }

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("pd_speak.m4a")
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 12000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.min.rawValue
        ]
        guard let rec = try? AVAudioRecorder(url: url, settings: settings) else { return }
        rec.isMeteringEnabled = true
        rec.record()
        recorder = rec

        withAnimation(.spring()) { speakState = .recording }
        startPulseAnimation()

        // Poll audio level
        levelTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            rec.updateMeters()
            let power = rec.averagePower(forChannel: 0) // dBFS, -160 to 0
            let normalized = CGFloat(max(0, (power + 50) / 50)) // map -50…0 → 0…1
            DispatchQueue.main.async { audioLevel = normalized }
        }

        // Auto-stop after 60s max
        autoStopTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: false) { _ in
            DispatchQueue.main.async {
                stopRecording()
                showSuccess()
            }
        }
    }

    private func stopRecording() {
        levelTimer?.invalidate(); levelTimer = nil
        autoStopTimer?.invalidate(); autoStopTimer = nil
        recorder?.stop()
        recorder = nil
        try? AVAudioSession.sharedInstance().setActive(false)
        audioLevel = 0
    }

    private func showSuccess() {
        withAnimation(.spring()) { speakState = .success }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.1)) {
            successScale = 1.0
            successOpacity = 1.0
        }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    private func dismissSuccess() {
        withAnimation(.easeOut(duration: 0.25)) {
            successOpacity = 0
            successScale = 0.8
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            speakState = .idle
            successScale = 0.3
        }
    }

    private func startPulseAnimation() {
        let delays: [Double] = [0, 0.15, 0.3]
        for i in 0..<3 {
            withAnimation(
                .easeInOut(duration: 0.8)
                .repeatForever(autoreverses: true)
                .delay(delays[i])
            ) {
                ringScale[i] = 1.12
                ringOpacity[i] = 0.08
            }
        }
    }
}
