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
//  The mic ARMS ITSELF. There is no record button to START, because a button
//  turns speaking into an extra decision at exactly the moment the user should
//  just open their mouth.
//
//  There IS a way to say you have FINISHED. Stopping is inferred from a pause,
//  but inference alone stranded people: it only fires from trailing silence
//  after speech was heard, so a re-armed mic and a silent user waited on a
//  30-second backstop with nothing on screen saying so.
//
//  Verification is `DeclarationVerificationService` — the same validator the
//  personal-declaration card uses. It transcribes and scores the spoken words
//  against the line, so "did they say it" has a real answer. The amplitude
//  heuristic this replaced could only answer "was there a noise", and got even
//  that wrong in both directions: an empty room completed a rep, and then two
//  words did.
//
//  What it still must never do is tell someone they said it wrong. A low score
//  cannot tell "they didn't say it" apart from "the recognizer missed it" —
//  accents, a noisy room, a cased mic. So a miss re-listens once, phrased as an
//  invitation, and then hands over to press-and-hold. No failure state, no
//  attempt counter, no correction.
//

import SwiftUI
import AVFoundation

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

    /// The same validator the personal-declaration card uses. It transcribes
    /// on device and scores the spoken words against the line, which is a real
    /// answer to "did they say it" — the amplitude heuristic this replaced
    /// could only ever answer "was there a noise", and got that wrong in both
    /// directions: an empty room completed a rep, then two words did.
    @StateObject private var verifier = DeclarationVerificationService()
    @State private var startedAt = Date()
    /// Nudges the copy on a re-listen. Never a failure state — see `promptText`.
    @State private var isSecondPass = false
    @State private var isVerifying = false
    @State private var usingHoldFallback = false
    @State private var holdProgress: CGFloat = 0
    @State private var holdTimer: Timer?
    @State private var settled = false
    /// Shown before the system dialog so the ask has a reason attached.
    @State private var showMicRationale = false
    /// Drives the staged entrance. The screen used to appear fully formed in the
    /// same frame the card burned off, which read as one continuous blur rather
    /// than as arriving somewhere new.
    @State private var revealed = false

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
                        verifier.cancel()
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
                    .opacity(revealed ? 1 : 0)

                // Words light gold as the transcript matches them, so the
                // screen shows the line being taken rather than a bar filling.
                HighlightedDeclarationText(
                    displayWords: displayWords,
                    matchedIndices: verifier.matchedIndices,
                    isRecording: verifier.isRecording
                )
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .shadow(color: gold.opacity(0.25), radius: 18)
                .opacity(revealed ? 1 : 0)
                .offset(y: revealed ? 0 : 14)

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
        // The reveal lives in onAppear, not in the task: `.task`'s closure is
        // @Sendable and carries no actor guarantee, and this writes @State and
        // drives an animation.
        .onAppear { withAnimation(DS.Motion.smooth) { revealed = true } }
        .task { await arm() }
        .onDisappear { verifier.cancel(); holdTimer?.invalidate() }
        // The speaker stopped. Close the recording and let the transcript
        // decide, rather than guessing from how loud the room was.
        .onChange(of: verifier.endpointedAt) { _, stamped in
            guard stamped != nil, !settled, !isVerifying else { return }
            Task { await verify() }
        }
        .alert("Turn on the mic?", isPresented: $showMicRationale) {
            Button("Not now", role: .cancel) { usingHoldFallback = true }
            Button("Continue") { Task { await requestMic() } }
        } message: {
            // Honest, because this now transcribes. It checks the words
            // against the line, on device where the phone supports it, and
            // deletes the audio the moment the check is done. Saying "nothing
            // is transcribed" here would be a lie told inside a permission ask.
            Text("SpeakLife listens to check you spoke the line out loud. The audio is deleted the moment it's checked, and never saved.")
        }
    }

    // MARK: - Arming

    @MainActor
    private func arm() async {
        startedAt = Date()
        verifier.prepare(declarationText: thought.counterDeclaration)
        if Self.micPreviouslyDenied {
            // Denied before: go straight to the fallback. Asking again is the
            // nag the spec rules out.
            usingHoldFallback = true
            return
        }
        if Self.micAlreadyAuthorized {
            await listen()
        } else {
            // One line of reason BEFORE the system dialog. This is the whole
            // difference between a permission people grant and one they don't.
            showMicRationale = true
        }
    }

    @MainActor
    private func requestMic() async {
        // The validator asks for speech recognition as well as the mic, so the
        // system dialogs are left to it rather than pre-empted here.
        await listen()
    }

    /// Arms the validator. The trailing-silence window is what makes this feel
    /// like the mic auto-arming rather than a record button: the user just
    /// speaks, and stopping is inferred.
    @MainActor
    private func listen() async {
        do {
            try await verifier.startRecording(autoStopAfterSilence: 1.2, preferOnDevice: true)
        } catch {
            // Permission refused or the engine failed. Never a nag and never an
            // error screen — the press-and-hold way through is always honoured.
            usingHoldFallback = true
        }
    }

    /// Closes the recording and scores it.
    ///
    /// A match completes the rep. A miss re-listens ONCE and then hands over to
    /// press-and-hold. It never accuses: a low score cannot distinguish "they
    /// didn't say it" from "the recognizer didn't catch it", and this feature
    /// does not get to call someone a liar about the one act it exists to
    /// encourage.
    @MainActor
    private func verify() async {
        isVerifying = true
        let matched = await verifier.stopAndTranscribe()
        isVerifying = false

        if matched >= Self.matchThreshold {
            settle(method: "mic")
            return
        }
        guard !isSecondPass else {
            usingHoldFallback = true
            return
        }
        isSecondPass = true
        await listen()
    }

    /// Same bar the personal-declaration card uses, so "spoken" means one thing
    /// across the app.
    private static let matchThreshold: Double = 0.65

    /// Read without prompting, so the screen can show its one-line reason
    /// BEFORE the system dialog — the difference between a permission people
    /// grant and one they don't.
    private static var micAlreadyAuthorized: Bool {
        AVAudioApplication.shared.recordPermission == .granted
    }

    private static var micPreviouslyDenied: Bool {
        AVAudioApplication.shared.recordPermission == .denied
    }

    // MARK: - Mic

    private var micControl: some View {
        VStack(spacing: 14) {
            GuardWaveform(levels: verifier.levels, tint: gold, isSettled: settled)
                .frame(height: 64)

            Text(promptText)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(settled ? 0.95 : 0.65))
                .multilineTextAlignment(.center)

            // "I've said it." The way to finish on purpose.
            //
            // Auto-endpointing handles the common case, but it only fires from
            // trailing silence after speech was heard, or from a 30-second
            // backstop. Re-arm the mic after a missed pass and say nothing, and
            // there was no way to finish and no sign of how long the wait was.
            // A screen that asks someone to speak must always let them say when
            // they're done.
            if !settled {
                Button {
                    verifier.finishSpeaking()
                } label: {
                    Text("Done — I've said it")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.9))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(
                            Capsule()
                                .stroke(Color.white.opacity(0.28), lineWidth: 1)
                        )
                }
                .buttonStyle(.dsPressable(feel: .tapSolid))
                .disabled(isVerifying)
                .opacity(isVerifying ? 0.4 : 1)
            }

            // Always reachable. Someone in a quiet room, on a bus, or beside a
            // sleeping child should never be stuck at this screen.
            Button {
                verifier.cancel()
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

    /// The words of the line, for the highlighter. Split on whitespace so the
    /// indices line up with `DeclarationVerificationService.declarationWords`,
    /// which tokenizes the same way.
    private var displayWords: [String] {
        thought.counterDeclaration.split(separator: " ").map(String.init)
    }

    /// Never says "wrong", never says "failed", never counts attempts.
    ///
    /// A poor match cannot tell "they didn't say it" apart from "the recognizer
    /// missed it" — accents, a noisy room, a cased mic. So the second pass is
    /// phrased as an invitation, not a correction, and the press-and-hold way
    /// through is on screen the whole time.
    private var promptText: String {
        if settled { return "Heard." }
        if isVerifying { return "…" }
        if isSecondPass { return "Once more — the whole line" }
        return verifier.isRecording ? "Read it out loud" : "Listening…"
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
                let stepped: CGFloat = holdProgress + (0.02 / 1.1)
                holdProgress = stepped > 1 ? 1 : stepped
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
        settle(method: "hold")
    }

    // MARK: - Settle

    /// The waveform fills, then settles. That settle IS the confirmation — there
    /// is no checkmark, no score, and nothing to dismiss.
    private func settle(method: String) {
        guard !settled else { return }
        settled = true
        PremiumHaptics.safeSuccess()
        verifier.cancel()
        // 1.4s, not 0.7. The settle IS the confirmation, so it has to be on
        // screen long enough to be read as one — otherwise the +1 arrives before
        // the user has registered that anything acknowledged them.
        let duration = Date().timeIntervalSince(startedAt)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
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
        let scaled: CGFloat = CGFloat(level) * 56
        return scaled < 4 ? 4 : scaled
    }
}
