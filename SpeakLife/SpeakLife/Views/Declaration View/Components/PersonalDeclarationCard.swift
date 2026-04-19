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
    case idle, recording, success, tryAgain
}

private let kMatchThreshold = 0.75

// MARK: - PersonalDeclarationCard

struct PersonalDeclarationCard: View {

    let declaration: PersonalDeclaration
    let onBreakthrough: () -> Void

    @Environment(\.dismiss) private var dismiss

    // Spoken-today tracking
    @AppStorage("personalDeclaration_lastSpokenDate") private var lastSpokenDateStr: String = ""

    private var spokenToday: Bool {
        let today = ISO8601DateFormatter().string(from: Calendar.current.startOfDay(for: Date()))
        return lastSpokenDateStr == today
    }

    // Verification service
    @StateObject private var verifier = DeclarationVerificationService()

    // Display words (original casing for UI, normalised handled by service)
    private var displayWords: [String] {
        declaration.declarationText.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
    }

    // Recording state
    @State private var speakState: SpeakState = .idle
    @State private var autoStopTimer: Timer?
    @State private var lastMatchPct: Double = 0

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

                        // ── Declaration text (highlights as user speaks) ─
                        HighlightedDeclarationText(
                            displayWords: displayWords,
                            matchedIndices: verifier.matchedIndices,
                            isRecording: speakState == .recording
                        )
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

            // ── Try Again overlay ─────────────────────────────────────
            if speakState == .tryAgain {
                tryAgainOverlay
            }
        }
        .onAppear {
            verifier.prepare(declarationText: declaration.declarationText)
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
                .fill(spokenToday ? Color(red: 0.3, green: 0.9, blue: 0.55) : Color(red: 1, green: 0.82, blue: 0.28))
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
        .animation(.easeInOut(duration: 0.3), value: spokenToday)
    }

    // MARK: - Speak Button

    @ViewBuilder
    private var speakButton: some View {
        ZStack {
            // Pulse rings during recording
            if speakState == .recording {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .strokeBorder(Color(red: 0.98, green: 0.36, blue: 0.35).opacity(ringOpacity[i]), lineWidth: 1.5)
                        .frame(width: CGFloat(72 + i * 28), height: CGFloat(72 + i * 28))
                        .scaleEffect(ringScale[i])
                }
            }

            Button(action: handleSpeakTap) {
                HStack(spacing: 10) {
                    Image(systemName: speakState == .recording ? "stop.fill" : "mic.fill")
                        .font(.system(size: 18, weight: .semibold))
                    Text(speakState == .recording ? "Tap to Finish" : "Speak It")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 60)
                .background(
                    Group {
                        if speakState == .recording {
                            RoundedRectangle(cornerRadius: 18).fill(Color(red: 0.85, green: 0.22, blue: 0.22))
                        } else {
                            RoundedRectangle(cornerRadius: 18)
                                .fill(LinearGradient(
                                    colors: [Color(red: 0.38, green: 0.35, blue: 0.95),
                                             Color(red: 0.55, green: 0.35, blue: 0.95)],
                                    startPoint: .leading, endPoint: .trailing))
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
                    Text("Well Done! 🙌")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text("The more you speak and meditate on this, the faster your results will come. Keep declaring it throughout your day.")
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

    // MARK: - Try Again Overlay

    private var tryAgainOverlay: some View {
        ZStack {
            Color.black.opacity(0.72).ignoresSafeArea()

            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(0.15))
                        .frame(width: 110, height: 110)
                    Circle()
                        .fill(Color.orange.opacity(0.25))
                        .frame(width: 90, height: 90)
                    Image(systemName: "mic.slash.fill")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundColor(.orange)
                }
                .scaleEffect(successScale)
                .opacity(successOpacity)

                VStack(spacing: 8) {
                    Text("Almost There!")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text("You spoke \(Int(lastMatchPct * 100))% of the declaration.\nSpeak at least 75% to complete it.")
                        .font(.system(size: 15, design: .rounded))
                        .foregroundColor(.white.opacity(0.65))
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                }
                .opacity(successOpacity)

                Button {
                    withAnimation(.easeOut(duration: 0.2)) {
                        successOpacity = 0
                        successScale = 0.85
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        speakState = .idle
                        successScale = 0.3
                        verifier.prepare(declarationText: declaration.declarationText)
                    }
                } label: {
                    Text("Try Again")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .frame(width: 160, height: 48)
                        .background(
                            Capsule()
                                .fill(Color.orange.opacity(0.25))
                                .overlay(Capsule().strokeBorder(Color.orange.opacity(0.4), lineWidth: 1))
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
        case .idle:      startRecording()
        case .recording: finishRecording()
        case .success:   dismissSuccess()
        case .tryAgain:  break // handled by overlay button
        }
    }

    private func startRecording() {
        Task {
            do {
                try await verifier.startRecording()
                withAnimation(.spring()) { speakState = .recording }
                startPulseAnimation()
                autoStopTimer = Timer.scheduledTimer(withTimeInterval: 90, repeats: false) { _ in
                    DispatchQueue.main.async { finishRecording() }
                }
            } catch DeclarationVerificationError.microphonePermissionDenied {
                showPermissionAlert(for: "Microphone")
            } catch DeclarationVerificationError.speechPermissionDenied {
                showPermissionAlert(for: "Speech Recognition")
            } catch {
                // Engine failure — stay idle, don't crash
                print("DeclarationVerificationService error: \(error)")
            }
        }
    }

    private func showPermissionAlert(for permission: String) {
        // Open Settings so user can grant access
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    private func finishRecording() {
        autoStopTimer?.invalidate()
        autoStopTimer = nil
        let pct = verifier.stopRecording()
        lastMatchPct = pct

        if pct >= kMatchThreshold {
            showSuccess()
        } else {
            showTryAgain()
        }
    }

    private func stopRecording() {
        autoStopTimer?.invalidate()
        autoStopTimer = nil
        _ = verifier.stopRecording()
    }

    private func showSuccess() {
        lastSpokenDateStr = ISO8601DateFormatter().string(from: Calendar.current.startOfDay(for: Date()))
        withAnimation(.spring()) { speakState = .success }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.1)) {
            successScale = 1.0
            successOpacity = 1.0
        }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    private func showTryAgain() {
        withAnimation(.spring()) { speakState = .tryAgain }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.1)) {
            successScale = 1.0
            successOpacity = 1.0
        }
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
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
                .easeInOut(duration: 0.8).repeatForever(autoreverses: true).delay(delays[i])
            ) {
                ringScale[i] = 1.12
                ringOpacity[i] = 0.08
            }
        }
    }
}
