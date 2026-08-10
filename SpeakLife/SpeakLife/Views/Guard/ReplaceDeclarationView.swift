//
//  ReplaceDeclarationView.swift
//  SpeakLife
//
//  Screen 3 of Take It Captive. Everything inverts.
//
//  The INCOMING screen was cold, grey, recessed, wrong. This one is navy, gold,
//  lit and warm. That contrast is doing real work: the user should feel like
//  they walked out of one room and into another. Do not harmonize these two
//  screens.
//
//  The mic ARMS ITSELF. There is no record button, because a button turns
//  speaking into an extra decision at exactly the moment the user should just
//  open their mouth. Confirmation is the waveform filling and then settling.
//
//  Nothing here grades the speaker. No transcription, no accuracy, no "try
//  again" — see `VoicePresenceService` for why that line is not negotiable.
//

import SwiftUI

struct ReplaceDeclarationView: View {

    let thought: IncomingThought
    /// - Parameters:
    ///   - spoken: whether a voice was actually heard (or the hold confirmed).
    ///   - method: "mic" or "hold", for the speak-rate metric.
    ///   - duration: how long the speaking step took.
    let onSpoken: (_ spoken: Bool, _ method: String, _ duration: TimeInterval) -> Void
    /// Leaving without speaking. The drill must always have a way out — a
    /// full-screen cover with no close control is a trap, and trapping someone
    /// inside a screen that is asking them to speak is the worst place to do it.
    let onClose: () -> Void

    @StateObject private var voice = VoicePresenceService()
    @State private var startedAt = Date()
    @State private var usingHoldFallback = false
    @State private var holdProgress: CGFloat = 0
    @State private var holdTimer: Timer?
    @State private var settled = false
    /// Shown before the system dialog so the ask has a reason attached.
    @State private var showMicRationale = false

    /// Navy field, per spec.
    private let field = Color(hex: "#1A264D")
    private let gold = Color(hex: "#F5B742")

    var body: some View {
        ZStack {
            LinearGradient(colors: [field, Color(hex: "#0F1730")],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            // Warmth: a soft gold bloom behind the declaration. The grey screen
            // had nothing like this.
            RadialGradient(colors: [gold.opacity(0.16), .clear],
                           center: .center, startRadius: 10, endRadius: 320)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            VStack(spacing: DS.Spacing.lg) {
                HStack {
                    Spacer()
                    Button(action: {
                        voice.stop()
                        onClose()
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white.opacity(0.35))
                            .frame(width: 32, height: 32)
                    }
                    .accessibilityLabel("Close")
                }

                Spacer(minLength: 0)

                Text("SPEAK IT")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(2.6)
                    .foregroundColor(gold.opacity(0.9))

                // The spec calls for Caveat Bold here. Caveat is a brand-deck
                // font and is NOT bundled in the app target, so `.custom` would
                // silently fall back to system and the headline would land
                // flatter than the body copy around it. AppleSDGothicNeo-Bold is
                // the display face this app actually ships (see
                // `DS.Typography`), so the headline gets real weight. Swap this
                // for Caveat the day the font is added to the target.
                Text(thought.counterDeclaration)
                    .font(.custom("AppleSDGothicNeo-Bold", size: 30))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .shadow(color: gold.opacity(0.25), radius: 18)

                VStack(spacing: 6) {
                    Text(thought.verseText)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(thought.book)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(gold.opacity(0.85))
                }
                .padding(.horizontal, 8)

                Spacer(minLength: 0)

                if usingHoldFallback {
                    holdControl
                } else {
                    micControl
                }
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 32)
        }
        .task { await arm() }
        .onDisappear { voice.stop(); holdTimer?.invalidate() }
        .onChange(of: voice.heardVoice) { _, heard in
            guard heard, !settled else { return }
            settle(method: "mic")
        }
        // The mic window closed with nothing heard. Hand them the hold button
        // rather than leaving the screen sitting on "Listening…" forever. Not
        // framed as a failure — see `holdControl`.
        .onChange(of: voice.timedOutWithoutVoice) { _, timedOut in
            guard timedOut, !settled else { return }
            usingHoldFallback = true
        }
        .alert("Turn on the mic?", isPresented: $showMicRationale) {
            Button("Not now", role: .cancel) { usingHoldFallback = true }
            Button("Continue") { Task { await requestMic() } }
        } message: {
            Text("SpeakLife listens only to confirm you spoke it out loud. Nothing is recorded, transcribed, or saved.")
        }
    }

    // MARK: - Arming

    @MainActor
    private func arm() async {
        startedAt = Date()
        if VoicePresenceService.micPreviouslyDenied {
            // Denied before: go straight to the fallback. Asking again is the
            // nag the spec rules out.
            usingHoldFallback = true
            return
        }
        if VoicePresenceService.micAlreadyAuthorized {
            let started = await voice.start()
            if !started { usingHoldFallback = true }
        } else {
            // One line of reason BEFORE the system dialog. This is the whole
            // difference between a permission people grant and one they don't.
            showMicRationale = true
        }
    }

    @MainActor
    private func requestMic() async {
        let granted = await voice.requestMicPermission()
        if granted {
            let started = await voice.start()
            if !started { usingHoldFallback = true }
        } else {
            usingHoldFallback = true
        }
    }

    // MARK: - Mic

    private var micControl: some View {
        VStack(spacing: 14) {
            GuardWaveform(levels: voice.levels, tint: gold, isSettled: settled)
                .frame(height: 64)

            Text(settled ? "Heard." : (voice.isListening ? "Say it out loud." : "Listening…"))
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(settled ? 0.95 : 0.6))

            // Always reachable. Someone in a quiet room, on a bus, or beside a
            // sleeping child should never be stuck at this screen.
            Button {
                voice.stop()
                usingHoldFallback = true
            } label: {
                Text("Can't speak out loud right now")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.35))
                    .underline()
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Hold fallback

    /// Press and hold "I spoke it". Same log, same ground, no nagging, and no
    /// second-class framing — someone who whispered it in a waiting room took
    /// the same ground as someone who shouted it in their car.
    private var holdControl: some View {
        VStack(spacing: 14) {
            ZStack {
                Capsule().fill(Color.white.opacity(0.10))
                GeometryReader { geo in
                    Capsule()
                        .fill(DS.Gradient.gold)
                        .frame(width: geo.size.width * holdProgress)
                }
                Text(settled ? "Ground taken" : "Hold to confirm you spoke it")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(holdProgress > 0.55 ? Color(hex: "#1A264D") : .white)
            }
            .frame(height: 56)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Color.white.opacity(0.22), lineWidth: 1))
            .contentShape(Capsule())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in beginHold() }
                    .onEnded { _ in endHold() }
            )
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel("I spoke it")
            .accessibilityAction { confirmHold() }

            Text("Speak it wherever you are. Out loud, or under your breath.")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.4))
                .multilineTextAlignment(.center)
        }
    }

    private func beginHold() {
        guard holdTimer == nil, !settled else { return }
        PremiumHaptics.safeLight()
        holdTimer = Timer.scheduledTimer(withTimeInterval: 0.02, repeats: true) { _ in
            Task { @MainActor in
                holdProgress = min(1, holdProgress + 0.02 / 1.1)
                if holdProgress >= 1 { confirmHold() }
            }
        }
    }

    private func endHold() {
        holdTimer?.invalidate(); holdTimer = nil
        guard !settled else { return }
        withAnimation(DS.Motion.quick) { holdProgress = 0 }
    }

    private func confirmHold() {
        holdTimer?.invalidate(); holdTimer = nil
        guard !settled else { return }
        holdProgress = 1
        voice.confirmSpokenByHold()
        settle(method: "hold")
    }

    // MARK: - Settle

    /// The waveform fills, then settles. That settle IS the confirmation — there
    /// is no checkmark, no score, and nothing to dismiss.
    private func settle(method: String) {
        guard !settled else { return }
        settled = true
        PremiumHaptics.safeSuccess()
        voice.stop()
        let duration = Date().timeIntervalSince(startedAt)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            onSpoken(true, method, duration)
        }
    }
}

// MARK: - Waveform

/// Bars that respond to the voice. Purely a mirror — it measures nothing and
/// judges nothing, it just shows the user that the room heard them.
struct GuardWaveform: View {
    let levels: [Float]
    let tint: Color
    let isSettled: Bool

    private let barCount = 28

    var body: some View {
        HStack(alignment: .center, spacing: 4) {
            ForEach(0..<barCount, id: \.self) { index in
                Capsule()
                    .fill(isSettled ? tint : tint.opacity(0.85))
                    .frame(width: 4, height: height(at: index))
            }
        }
        .frame(maxWidth: .infinity)
        .animation(.easeOut(duration: 0.12), value: levels.count)
        .animation(DS.Motion.smooth, value: isSettled)
    }

    private func height(at index: Int) -> CGFloat {
        // Settled: a calm, even line. The visual equivalent of exhaling.
        if isSettled { return 8 }
        guard !levels.isEmpty else { return 4 }
        // Newest sample on the right, so the wave reads left-to-right like speech.
        let offset = barCount - index
        guard offset <= levels.count else { return 4 }
        let level = levels[levels.count - offset]
        return max(4, CGFloat(level) * 56)
    }
}
