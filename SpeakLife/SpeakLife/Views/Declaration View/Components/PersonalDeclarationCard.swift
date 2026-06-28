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

private let kMatchThreshold = 0.65

// MARK: - PersonalDeclarationCard

struct PersonalDeclarationCard: View {

    let declaration: PersonalDeclaration
    let onBreakthrough: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    private var isIPad: Bool { horizontalSizeClass == .regular }

    // Spoken-today tracking
    @AppStorage(PersonalDeclaration.lastSpokenDateKey) private var lastSpokenDateStr: String = ""
    /// How many times the user has spoken this declaration today. Resets to
    /// 1 on first speak of a new day, increments on subsequent speaks.
    /// Drives the tiered visual reward in `dayBadge`.
    @AppStorage(PersonalDeclaration.dailySpeakCountKey) private var dailySpeakCount: Int = 0
    /// Count of unique calendar days the user has successfully spoken this
    /// declaration. Drives the "Day N" label so the number reflects work done,
    /// not calendar drift since the declaration was created.
    @AppStorage(PersonalDeclaration.completedDayCountKey) private var completedDayCount: Int = 0

    private var spokenToday: Bool {
        let today = ISO8601DateFormatter().string(from: Calendar.current.startOfDay(for: Date()))
        return lastSpokenDateStr == today
    }

    /// The number of speaks recorded for *today* — zero if the stored count
    /// is from a previous day (the badge view normalises this on render).
    private var todaySpeakCount: Int {
        spokenToday ? dailySpeakCount : 0
    }

    // Pulse animation for the highest streak tier.
    @State private var dayBadgePulse = false

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

    // Permission alert (shown in-app instead of silently yanking the user to
    // the Settings app when mic/speech access isn't granted).
    @State private var showPermissionDeniedAlert = false
    @State private var permissionAlertMessage = ""

    // Animations
    @State private var successScale: CGFloat = 0.3
    @State private var successOpacity: Double = 0
    @State private var ringScale: [CGFloat] = [1, 1, 1]
    @State private var ringOpacity: [Double] = [0.5, 0.35, 0.2]
    @State private var cardAppear = false

    private var dayCount: Int {
        max(1, completedDayCount)
    }

    var body: some View {
        ZStack {
            // Background — solid black first to block any sheet translucency,
            // then the dark navy on top so the card colour is consistent.
            Color.black.ignoresSafeArea()
            Color(red: 0.07, green: 0.08, blue: 0.14)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Top bar: centered drag handle (iPhone sheet affordance) plus an
                // explicit close button on iPad, where this card is presented as a
                // fullScreenCover with no swipe-to-dismiss gesture.
                ZStack {
                    Capsule()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 36, height: 4)

                    if isIPad {
                        HStack {
                            Spacer()
                            Button(action: { dismiss() }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(.white.opacity(0.5))
                                    .padding(.horizontal, 16)
                                    .contentShape(Rectangle())
                            }
                            .accessibilityLabel("Close")
                        }
                    }
                }
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
        .onDisappear {
            // Abort cleanly on dismiss — invalidate the auto-stop timer and tear
            // down the recorder without kicking off a transcription we'd discard.
            autoStopTimer?.invalidate()
            autoStopTimer = nil
            verifier.cancel()
        }
        .alert("Permission Needed", isPresented: $showPermissionDeniedAlert) {
            Button("Not Now", role: .cancel) { }
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
        } message: {
            Text(permissionAlertMessage)
        }
    }

    // MARK: - Day Badge
    //
    // Tiered progression — the more times the user speaks today, the
    // richer the visual reward:
    //   0  → muted ember (not spoken yet today)
    //   1× → green ✓ (first speak — completion)
    //   2× → 🔥 single flame, warm orange (momentum)
    //   3× → 🔥🔥 double flame, deeper orange (fire)
    //   4+ → 👑 crown, gold, glow + pulse (warrior tier)
    //
    // The intent is to make every additional declaration feel like it
    // earned the user something visible, instead of "spoken/not spoken"
    // being the only signal.

    private struct StreakTier {
        let symbol: String          // emoji rendered to the badge's left
        let primaryColor: Color     // foreground colour for "Day N · Nx"
        let backgroundOpacity: Double
        let glowColor: Color
        let glowRadius: CGFloat
    }

    private var streakTier: StreakTier {
        switch todaySpeakCount {
        case 0:
            return StreakTier(
                symbol: "·",
                primaryColor: Color(red: 1, green: 0.82, blue: 0.28),  // ember yellow
                backgroundOpacity: 0.08,
                glowColor: .clear,
                glowRadius: 0
            )
        case 1:
            return StreakTier(
                symbol: "✓",
                primaryColor: Color(red: 0.3, green: 0.9, blue: 0.55),  // green
                backgroundOpacity: 0.14,
                glowColor: Color(red: 0.3, green: 0.9, blue: 0.55).opacity(0.35),
                glowRadius: 6
            )
        case 2:
            return StreakTier(
                symbol: "🔥",
                primaryColor: Color(red: 1, green: 0.62, blue: 0.25),  // warm orange
                backgroundOpacity: 0.18,
                glowColor: Color(red: 1, green: 0.55, blue: 0.2).opacity(0.4),
                glowRadius: 8
            )
        case 3:
            return StreakTier(
                symbol: "🔥🔥",
                primaryColor: Color(red: 1, green: 0.45, blue: 0.2),   // deep orange
                backgroundOpacity: 0.22,
                glowColor: Color(red: 1, green: 0.4, blue: 0.15).opacity(0.5),
                glowRadius: 10
            )
        default:  // 4+
            return StreakTier(
                symbol: "👑",
                primaryColor: Color(red: 1, green: 0.84, blue: 0.36),  // gold
                backgroundOpacity: 0.28,
                glowColor: Color(red: 1, green: 0.78, blue: 0.3).opacity(0.7),
                glowRadius: 14
            )
        }
    }

    private var dayBadge: some View {
        let tier = streakTier
        let countSuffix = todaySpeakCount >= 2 ? " · \(todaySpeakCount)×" : ""

        return HStack(spacing: 5) {
            Text(tier.symbol)
                .font(.system(size: tier.symbol == "·" ? 14 : 11))
            Text("Day \(dayCount)\(countSuffix)")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(tier.primaryColor.opacity(0.95))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(Color.white.opacity(tier.backgroundOpacity))
        )
        .overlay(
            Capsule()
                .stroke(tier.primaryColor.opacity(0.35), lineWidth: 0.8)
        )
        .shadow(color: tier.glowColor, radius: tier.glowRadius)
        // Brief spring pulse fires from showSuccess() when a new speak is
        // recorded, drawing the eye to the upgraded tier.
        .scaleEffect(dayBadgePulse ? 1.12 : 1.0)
        .animation(.easeInOut(duration: 0.3), value: todaySpeakCount)
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
                    if verifier.isTranscribing {
                        ProgressView().tint(.white).scaleEffect(0.85)
                        Text("Analyzing...")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                    } else {
                        Image(systemName: speakState == .recording ? "stop.fill" : "mic.fill")
                            .font(.system(size: 18, weight: .semibold))
                        Text(speakState == .recording ? "Tap to Finish" : "Speak It")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                    }
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
                .animation(DS.Motion.quick, value: speakState)
            }
            .padding(.horizontal, DS.Spacing.lg)
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
                    Text("You spoke \(Int(lastMatchPct * 100))% of the declaration.\nSpeak at least 65% to complete it.")
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
                withAnimation(DS.Motion.smooth) { speakState = .recording }
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
        // Surface an in-app alert rather than silently opening the Settings app.
        // Auto-jumping to Settings on iPad felt like the app had crashed or
        // booted the user out. The alert explains why and lets them choose.
        permissionAlertMessage = "\(permission) access is turned off. To speak your declaration out loud, enable it in Settings."
        showPermissionDeniedAlert = true
    }

    private func finishRecording() {
        autoStopTimer?.invalidate()
        autoStopTimer = nil
        withAnimation { speakState = .idle } // stop pulse rings while transcribing
        Task {
            let pct = await verifier.stopAndTranscribe()
            lastMatchPct = pct
            if pct >= kMatchThreshold {
                showSuccess()
            } else {
                showTryAgain()
            }
        }
    }

    private func showSuccess() {
        let today = ISO8601DateFormatter().string(from: Calendar.current.startOfDay(for: Date()))
        // First speak of the day resets the counter to 1; subsequent speaks
        // increment so the day badge can give richer visual rewards for
        // repeated declaration ("the more you speak, the better the visual").
        // First speak on a new day also bumps `completedDayCount` so "Day N"
        // tracks unique completion days, not calendar drift since save.
        if lastSpokenDateStr == today {
            dailySpeakCount += 1
        } else {
            dailySpeakCount = 1
            completedDayCount += 1
        }
        lastSpokenDateStr = today

        withAnimation(DS.Motion.smooth) { speakState = .success }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.1)) {
            successScale = 1.0
            successOpacity = 1.0
        }
        // Brief pulse on the day badge to draw the eye to the streak tier.
        withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) {
            dayBadgePulse = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation(.easeOut(duration: 0.3)) { dayBadgePulse = false }
        }
        // Completing a spoken declaration is a real win: reward it with the
        // matched success sequence (light → medium → heavy) instead of a flat tap.
        Juice.play(.success)
    }

    private func showTryAgain() {
        withAnimation(DS.Motion.smooth) { speakState = .tryAgain }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.1)) {
            successScale = 1.0
            successOpacity = 1.0
        }
        Juice.play(.warning)
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
