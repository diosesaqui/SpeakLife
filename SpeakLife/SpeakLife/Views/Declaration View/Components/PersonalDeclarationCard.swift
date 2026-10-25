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
/// Seconds of heard voice per word for the follow-along cursor. Speech runs
/// near 2.5 words a second, and the meter only counts the loud part of each.
private let kVoicedSecondsPerWord = 0.3

// MARK: - PersonalDeclarationCard

struct PersonalDeclarationCard: View {

    /// The declaration as it was when the card opened. `progress` carries the
    /// live copy — speak counters advance as the user speaks.
    let declaration: PersonalDeclaration
    let onBreakthrough: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    private var isIPad: Bool { horizontalSizeClass == .regular }

    /// Speak progress for *this* declaration. A user carrying several burdens
    /// gets a separate streak for each, so the counters live on the record
    /// rather than in shared UserDefaults keys.
    @State private var progress: PersonalDeclaration

    init(declaration: PersonalDeclaration, onBreakthrough: @escaping () -> Void) {
        self.declaration = declaration
        self.onBreakthrough = onBreakthrough
        _progress = State(initialValue: declaration)
    }

    /// The number of speaks recorded for *today* — zero if the stored count
    /// is from a previous day.
    private var todaySpeakCount: Int { progress.todaySpeakCount }

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
    @State private var cardAppear = false

    /// Matched words shown in gold. Filled one by one after transcription so
    /// the user watches what was caught land before the result appears.
    @State private var revealedIndices: Set<Int> = []
    @State private var isRevealing = false
    /// True from the "done" tap until the result shows. Bridges the gap before
    /// the verifier flips `isTranscribing`, so the panel never flickers.
    @State private var isChecking = false

    private let gold = Color(red: 1, green: 0.82, blue: 0.28)
    private let green = Color(red: 0.3, green: 0.9, blue: 0.55)
    private let recordRed = Color(red: 0.85, green: 0.22, blue: 0.22)

    /// From tap to result: the mic is live, the words are being checked, or
    /// the caught words are landing.
    private var isListeningPhase: Bool {
        speakState == .recording || isChecking
    }

    /// How far the voice has carried through the declaration.
    private var followIndex: Int {
        min(displayWords.count, Int(verifier.voicedSeconds / kVoicedSecondsPerWord))
    }

    /// Newest mic level, 0...1. Drives the button glow.
    private var liveLevel: CGFloat {
        guard speakState == .recording, let last = verifier.levels.last else { return 0 }
        return CGFloat(last)
    }

    private var dayCount: Int { progress.dayCount }

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
                            matchedIndices: revealedIndices,
                            isRecording: isListeningPhase,
                            followIndex: (speakState == .recording || (isChecking && !isRevealing))
                                ? followIndex : nil
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

                    // Secondary slot: live listening feedback while speaking,
                    // otherwise the breakthrough button. Same height, so the
                    // layout never jumps.
                    ZStack {
                        if isListeningPhase {
                            listeningPanel
                                .transition(.opacity.combined(with: .scale(scale: 0.96)))
                        } else {
                            breakthroughButton
                                .transition(.opacity)
                        }
                    }
                    .frame(height: 52)
                    .animation(DS.Motion.smooth, value: isListeningPhase)
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
            // Re-read progress rather than trusting the copy the parent handed
            // us: it may be stale, and SwiftUI can reuse this view's @State
            // across presentations of different declarations.
            let id = declaration.id
            Task {
                let latest = await DIContainer.shared.personalDeclarationRepository.loadAll()
                if let current = latest.first(where: { $0.id == id }) {
                    await MainActor.run { progress = current }
                }
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

    // MARK: - Breakthrough Button

    private var breakthroughButton: some View {
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

    // MARK: - Listening Panel
    //
    // Proof the phone hears them: a status line that reacts to their voice and
    // a waveform that moves with it. Purely a mirror. The transcript alone
    // decides whether the declaration was spoken.

    private var listeningStatus: (text: String, color: Color) {
        if isRevealing {
            let caught = revealedIndices.count
            return ("Caught \(caught) of \(displayWords.count) words", gold)
        }
        if isChecking { return ("Checking your words…", gold) }
        if verifier.isVoiceActive { return ("I hear you. Keep going", green) }
        if verifier.hasHeardSpeech || verifier.voicedSeconds > 0 {
            return ("Listening… tap when you're done", .white)
        }
        return ("Listening… speak it out loud", .white)
    }

    private var listeningPanel: some View {
        let status = listeningStatus
        return VStack(spacing: 6) {
            HStack(spacing: 7) {
                Circle()
                    .fill(status.color)
                    .frame(width: 7, height: 7)
                    .shadow(color: status.color.opacity(0.8), radius: verifier.isVoiceActive ? 5 : 0)
                    .scaleEffect(verifier.isVoiceActive ? 1.3 : 1.0)
                Text(status.text)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(status.color.opacity(0.9))
                    .contentTransition(.opacity)
                    .lineLimit(1)
            }
            .animation(.easeOut(duration: 0.18), value: verifier.isVoiceActive)
            .animation(.easeOut(duration: 0.2), value: status.text)
            .accessibilityElement(children: .combine)

            GuardWaveform(
                levels: verifier.levels,
                tint: verifier.isVoiceActive ? green : gold,
                isSettled: speakState != .recording,
                maxBarHeight: 30
            )
            .frame(height: 30)
            .accessibilityHidden(true)
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Speak Button

    @ViewBuilder
    private var speakButton: some View {
        ZStack {
            Button(action: handleSpeakTap) {
                HStack(spacing: 10) {
                    if isChecking {
                        ProgressView().tint(.white).scaleEffect(0.85)
                        Text("Checking...")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                    } else if speakState == .recording {
                        Image(systemName: "waveform")
                            .font(.system(size: 18, weight: .semibold))
                            .symbolEffect(.variableColor.iterative, isActive: verifier.isVoiceActive)
                        Text("Tap When Done")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                    } else {
                        Image(systemName: "mic.fill")
                            .font(.system(size: 18, weight: .semibold))
                        Text("Speak It")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 60)
                .background(
                    Group {
                        if speakState == .recording {
                            RoundedRectangle(cornerRadius: 18).fill(recordRed)
                        } else {
                            RoundedRectangle(cornerRadius: 18)
                                .fill(LinearGradient(
                                    colors: [Color(red: 0.38, green: 0.35, blue: 0.95),
                                             Color(red: 0.55, green: 0.35, blue: 0.95)],
                                    startPoint: .leading, endPoint: .trailing))
                        }
                    }
                )
                // While recording the glow breathes with the voice, so the
                // button itself shows the mic is catching every word.
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .strokeBorder(Color.white.opacity(0.15 + Double(liveLevel) * 0.5), lineWidth: 1.5)
                        .opacity(speakState == .recording ? 1 : 0)
                )
                .shadow(color: speakState == .recording
                    ? recordRed.opacity(0.35 + Double(liveLevel) * 0.45)
                    : Color(red: 0.38, green: 0.35, blue: 0.95).opacity(0.4),
                    radius: speakState == .recording ? 10 + liveLevel * 22 : 12, x: 0, y: 6)
                .scaleEffect(speakState == .recording ? 0.97 + liveLevel * 0.04 : 1.0)
                .animation(DS.Motion.quick, value: speakState)
                .animation(.easeOut(duration: 0.1), value: liveLevel)
            }
            .padding(.horizontal, DS.Spacing.lg)
            .disabled(isChecking)
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
                        revealedIndices = []
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
                revealedIndices = []
                withAnimation(DS.Motion.smooth) { speakState = .recording }
                Juice.play(.tapSolid)
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
        // The 90s auto-stop can race a tap. Only the first one counts.
        guard speakState == .recording else { return }
        autoStopTimer?.invalidate()
        autoStopTimer = nil
        Juice.play(.tapLight)
        isChecking = true
        withAnimation { speakState = .idle }
        Task {
            let pct = await verifier.stopAndTranscribe()
            lastMatchPct = pct
            await revealMatchedWords(verifier.matchedIndices)
            isChecking = false
            if pct >= kMatchThreshold {
                showSuccess()
            } else {
                showTryAgain()
            }
        }
    }

    /// Lights the caught words gold one at a time, in reading order, so the
    /// user sees exactly what was heard before the result appears.
    @MainActor
    private func revealMatchedWords(_ indices: Set<Int>) async {
        let ordered = indices.sorted()
        guard !ordered.isEmpty else { return }
        isRevealing = true
        // Whole sweep stays under ~0.9s however long the declaration is.
        let step = min(0.07, 0.9 / Double(ordered.count))
        for index in ordered {
            withAnimation(.easeOut(duration: 0.18)) {
                _ = revealedIndices.insert(index)
            }
            try? await Task.sleep(nanoseconds: UInt64(step * 1_000_000_000))
        }
        // Let the last word land before the overlay covers it.
        try? await Task.sleep(nanoseconds: 350_000_000)
        isRevealing = false
    }

    private func showSuccess() {
        // First speak of the day resets the daily counter to 1 and bumps
        // "Day N"; subsequent speaks only raise the daily counter, so the day
        // badge can give richer visual rewards for repeated declaration
        // ("the more you speak, the better the visual").
        //
        // The badge updates immediately off local state; the write goes through
        // the repository so the record — and every other surface reading it —
        // stays in step.
        progress.recordSpeak()
        let id = progress.id
        Task {
            if let saved = try? await DIContainer.shared.personalDeclarationRepository.recordSpeak(id: id) {
                await MainActor.run { progress = saved }
            }
            // Today's reminder is now redundant — they just spoke it. Rescheduling
            // pushes this one's push to tomorrow instead of letting it fire in a
            // couple of hours to nag them about work already done. Runs after the
            // write so `spokenToday` is true when the scheduler reads it back.
            await MainActor.run {
                // Mirrors AppState's @AppStorage default. `integer(forKey:)`
                // returns 0 for an absent key, which would move every reminder
                // to midnight for anyone who has not set a time.
                let defaults = UserDefaults.standard
                let timeIndex = defaults.object(forKey: "personalDeclarationTimeIndex") as? Int ?? 16
                DIContainer.shared.rescheduleActivePersonalDeclarationIfNeeded(startTimeIndex: timeIndex)
            }
        }

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
}
