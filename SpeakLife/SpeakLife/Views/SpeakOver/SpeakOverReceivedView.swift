//
//  SpeakOverReceivedView.swift
//  SpeakLife
//
//  The receiving half of "Speak it over someone": a declaration a friend sent,
//  opened like a gift.
//
//  The sender is standing with them; the recipient is the one who speaks. So
//  the screen says who is standing with them, hands them the line, and asks
//  for one thing: say it out loud. The speaking step uses the same validator
//  as the personal declaration card and Take It Captive, so "spoken" means one
//  thing across the app, and it always has a way through without the mic.
//
//  Everything shown came from a link, so it is rendered as plain `Text` and
//  nothing else.
//

import SwiftUI
import UIKit
import AVFoundation

struct SpeakOverReceivedView: View {

    let delivery: SpeakOverDelivery
    /// The verse, only when the line is one of the app's own word for word.
    var verse: String? = nil
    let background: UIImage?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @StateObject private var verifier = DeclarationVerificationService()

    private enum Phase {
        case ready, listening, fallback, spoken
    }

    @State private var phase: Phase = .ready
    @State private var isSecondPass = false
    @State private var isVerifying = false
    @State private var showMicRationale = false
    /// Set the moment the screen is closing. Every step of the speaking flow
    /// checks it after each await, so a transcript that comes back after the
    /// user left can never re-arm the mic behind a screen that is gone.
    @State private var isClosed = false
    /// Whether the mic was used here, so closing puts the audio session back.
    @State private var usedMic = false
    @State private var showSendBack = false

    // Staged reveal.
    @State private var showHeader = false
    @State private var showLine = false
    @State private var showActions = false

    private var gift: SpeakOverGift { delivery.gift }

    private static let gold = Color(red: 0.945, green: 0.824, blue: 0.604)   // card gold
    private static let navy = Color(hex: "#1A264D")
    /// Same bar as the personal declaration card and Take It Captive.
    private static let matchThreshold: Double = 0.65

    var body: some View {
        ZStack {
            backgroundLayer
            grade

            VStack(spacing: 0) {
                closeBar

                Spacer(minLength: DS.Spacing.md)

                header
                    .opacity(showHeader ? 1 : 0)
                    .offset(y: showHeader || reduceMotion ? 0 : 10)

                declaration
                    .padding(.top, DS.Spacing.xl)
                    .opacity(showLine ? 1 : 0)
                    .scaleEffect(showLine || reduceMotion ? 1 : 0.96)
                    .blur(radius: showLine || reduceMotion ? 0 : 10)

                Spacer(minLength: DS.Spacing.lg)

                actions
                    .opacity(showActions ? 1 : 0)
                    .offset(y: showActions || reduceMotion ? 0 : 14)
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.bottom, DS.Spacing.lg)
        }
        .environment(\.colorScheme, .dark)
        .onAppear {
            // Once per delivery, even if the app was killed with it open and
            // it came back.
            if SpeakOverInbox.markOpened(delivery) {
                AnalyticsService.shared.track("speak_over_opened", parameters: [
                    "source": delivery.source.rawValue,
                    "has_sender_name": gift.from != nil,
                    "has_recipient_name": gift.to != nil,
                    "has_verse": verse != nil,
                    "is_jesus_voice": gift.isJesusVoice
                ])
            }
            reveal()
        }
        .onDisappear { close() }
        // The speaker stopped. Let the transcript decide, as Take It Captive does.
        .onChange(of: verifier.endpointedAt) { _, stamped in
            guard stamped != nil, phase == .listening, !isVerifying, !isClosed else { return }
            Task { await verify() }
        }
        .alert("Turn on the mic?", isPresented: $showMicRationale) {
            Button("Not now", role: .cancel) { phase = .fallback }
            Button("Continue") { Task { await listen() } }
        } message: {
            // True of DeclarationVerificationService: it deletes the file
            // after transcribing and on cancel.
            Text("SpeakLife listens to check you said the line. iOS will ask for the mic and speech recognition. The audio is deleted once it's checked.")
        }
        .sheet(isPresented: $showSendBack) {
            SpeakOverSheet(
                declaration: Declaration(text: gift.text, book: gift.book, bibleVerseText: verse),
                background: background,
                recipientName: gift.from,
                origin: .sentBack
            )
        }
    }

    // MARK: - Background

    @ViewBuilder
    private var backgroundLayer: some View {
        if let background {
            GeometryReader { geo in
                Image(uiImage: background)
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
            }
            .ignoresSafeArea()
        } else {
            // The story card's fallback, so both ends of the gift match.
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.04, blue: 0.16),
                    Color(red: 0.20, green: 0.10, blue: 0.36),
                    Color(red: 0.42, green: 0.22, blue: 0.40),
                    Color(red: 0.08, green: 0.05, blue: 0.14)
                ],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()
        }
    }

    /// Keeps white text readable on any photo, with a warm glow behind the line.
    private var grade: some View {
        ZStack {
            LinearGradient(
                stops: [
                    .init(color: .black.opacity(0.65), location: 0.00),
                    .init(color: .black.opacity(0.35), location: 0.30),
                    .init(color: .black.opacity(0.45), location: 0.60),
                    .init(color: .black.opacity(0.88), location: 1.00)
                ],
                startPoint: .top, endPoint: .bottom
            )
            RadialGradient(colors: [Self.gold.opacity(showLine ? 0.18 : 0), .clear],
                           center: .center, startRadius: 10, endRadius: 340)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    // MARK: - Top

    /// Always reachable. A full-screen cover with no way out is a trap.
    private var closeBar: some View {
        HStack {
            Spacer()
            Button {
                close()
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white.opacity(0.6))
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Color.white.opacity(0.10)))
            }
            .accessibilityLabel("Close")
        }
        .padding(.top, DS.Spacing.xs)
    }

    private var header: some View {
        VStack(spacing: DS.Spacing.xs) {
            HStack(spacing: DS.Spacing.sm) {
                LinearGradient(colors: [.clear, Self.gold], startPoint: .leading, endPoint: .trailing)
                    .frame(width: 32, height: 1.5)
                Image(systemName: "gift.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Self.gold)
                LinearGradient(colors: [Self.gold, .clear], startPoint: .leading, endPoint: .trailing)
                    .frame(width: 32, height: 1.5)
            }
            .accessibilityHidden(true)

            Text(SpeakOverCopy.headline(from: gift.from))
                .font(.system(size: 26, weight: .semibold, design: .serif))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .shadow(color: .black.opacity(0.5), radius: 8, y: 1)

            Text(phase == .spoken ? "You spoke it. It's yours." : SpeakOverCopy.subline(to: gift.to))
                .font(DS.Typography.callout)
                .foregroundColor(.white.opacity(0.78))
                .multilineTextAlignment(.center)
                .contentTransition(.opacity)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - The line

    /// Steps down with length instead of shrinking to fit, like the card.
    private var lineFontSize: CGFloat {
        switch gift.text.count {
        case ..<60:  return 34
        case ..<110: return 30
        case ..<170: return 26
        default:     return 22
        }
    }

    /// The reference, unless the line is Jesus' own words (labelled above it).
    private var reference: String? {
        guard let book = gift.book, !gift.isJesusVoice else { return nil }
        return book.uppercased()
    }

    private var declaration: some View {
        VStack(spacing: 0) {
            if gift.isJesusVoice {
                Text("JESUS SAYS")
                    .font(.system(size: 12, weight: .semibold))
                    .tracking(4)
                    .foregroundColor(Self.gold)
                    .padding(.bottom, DS.Spacing.sm)
            }

            Text("\u{201C}")
                .font(.system(size: 72, weight: .regular, design: .serif))
                .foregroundColor(Self.gold.opacity(0.95))
                .shadow(color: Self.gold.opacity(0.35), radius: 12)
                .frame(height: 34, alignment: .top)
                .accessibilityHidden(true)

            Text(gift.text)
                .font(.system(size: lineFontSize, weight: .medium, design: .serif))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .minimumScaleFactor(0.7)
                .shadow(color: .black.opacity(0.55), radius: 10, y: 2)
                .padding(.top, DS.Spacing.sm)
                // Not fixedSize: on a small phone the longest lines shrink to fit
                // (minimumScaleFactor) instead of pushing the buttons off screen.
                .layoutPriority(1)

            if reference != nil || verse != nil {
                Capsule()
                    .fill(Self.gold)
                    .frame(width: 40, height: 2)
                    .padding(.top, DS.Spacing.lg)
            }

            if let verse {
                Text(verse)
                    .font(.system(size: 15, weight: .regular, design: .serif).italic())
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .lineLimit(4)
                    .minimumScaleFactor(0.85)
                    .shadow(color: .black.opacity(0.6), radius: 6, y: 1)
                    .padding(.top, DS.Spacing.sm)
            }

            if let reference {
                Text(reference)
                    .font(.system(size: 13, weight: .semibold))
                    .tracking(3)
                    .foregroundColor(Self.gold)
                    .padding(.top, DS.Spacing.sm)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Actions

    @ViewBuilder
    private var actions: some View {
        VStack(spacing: DS.Spacing.md) {
            switch phase {
            case .ready:
                goldButton("Speak it out loud", icon: "mic.fill") { startSpeaking() }
                sendBackButton
            case .listening:
                listeningControls
            case .fallback:
                goldButton("I said it", icon: "checkmark") { settle(method: "tap") }
                Text("Say it when you can. It's still yours.")
                    .font(DS.Typography.caption)
                    .foregroundColor(.white.opacity(0.55))
                    .multilineTextAlignment(.center)
            case .spoken:
                goldButton("Done", icon: nil) { dismiss() }
                sendBackButton
            }
        }
        .animation(reduceMotion ? nil : DS.Motion.smooth, value: phase)
    }

    private var listeningControls: some View {
        VStack(spacing: DS.Spacing.sm) {
            GuardWaveform(levels: verifier.levels, tint: Self.gold, isSettled: false, maxBarHeight: 44)
                .frame(height: 52)

            Text(listeningPrompt)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.7))

            Button {
                verifier.finishSpeaking()
            } label: {
                Text("I've said it")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.92))
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Capsule().stroke(Color.white.opacity(0.3), lineWidth: 1))
            }
            .buttonStyle(.dsPressable(feel: .tapSolid))
            // `finishSpeaking()` does nothing unless a recording is live, so
            // the button greys out rather than sitting there dead.
            .disabled(!canFinish)
            .opacity(canFinish ? 1 : 0.4)

            Button {
                verifier.cancel()
                phase = .fallback
            } label: {
                Text("Can't speak out loud right now")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.45))
                    .underline()
            }
            .buttonStyle(.plain)
            .padding(.top, 2)
        }
    }

    private var listeningPrompt: String {
        if isVerifying { return "One moment..." }
        if isSecondPass { return "Once more, the whole line" }
        return verifier.isRecording ? "Read it out loud" : "Getting the mic ready..."
    }

    private var canFinish: Bool {
        verifier.isRecording && !isVerifying
    }

    private var sendBackButton: some View {
        Button {
            AnalyticsService.shared.track("speak_over_send_back_tapped", parameters: [
                "spoken": phase == .spoken
            ])
            showSendBack = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "arrowshape.turn.up.left.fill")
                    .font(.system(size: 13, weight: .semibold))
                Text("Send one back")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
            }
            .foregroundColor(.white.opacity(0.9))
            .frame(maxWidth: .infinity)
            .frame(height: 48)
        }
        .buttonStyle(.dsPressable(feel: .tapLight))
    }

    private func goldButton(_ title: String, icon: String?, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: DS.Spacing.xs) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .bold))
                }
                Text(title)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
            }
            .foregroundColor(Self.navy)
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .background(Capsule().fill(DS.Gradient.gold))
            .shadow(color: DS.Palette.gold.opacity(0.4), radius: 16, y: 6)
        }
        .buttonStyle(.dsPressable(feel: .tapSolid))
    }

    // MARK: - Reveal

    /// Header first, then the line arrives out of a soft blur with a heartbeat,
    /// then the buttons. Reduce Motion gets a plain fade.
    @MainActor
    private func reveal() {
        let ease = reduceMotion ? Animation.easeOut(duration: 0.25) : DS.Motion.gentle
        withAnimation(ease.delay(0.15)) { showHeader = true }
        withAnimation((reduceMotion ? ease : DS.Motion.smooth).delay(reduceMotion ? 0.15 : 0.75)) {
            showLine = true
        }
        withAnimation(ease.delay(reduceMotion ? 0.15 : 1.5)) { showActions = true }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: reduceMotion ? 150_000_000 : 800_000_000)
            PremiumHaptics.safeHeartbeat()
        }
    }

    // MARK: - Speaking

    @MainActor
    private func startSpeaking() {
        guard !isClosed else { return }
        if AVAudioApplication.shared.recordPermission == .denied {
            // Denied before. Asking again is a nag; the tap way is honoured.
            phase = .fallback
            return
        }
        verifier.prepare(declarationText: gift.text)
        if AVAudioApplication.shared.recordPermission == .granted {
            Task { await listen() }
        } else {
            // One line of reason before the system dialog.
            showMicRationale = true
        }
    }

    @MainActor
    private func listen() async {
        guard !isClosed, phase == .ready || phase == .listening else { return }
        phase = .listening
        usedMic = true
        do {
            try await verifier.startRecording(autoStopAfterSilence: 1.2, preferOnDevice: true)
        } catch {
            // Permission refused or the engine failed. Never an error screen.
            if !isClosed, phase == .listening { phase = .fallback }
            return
        }
        // The permission dialogs can take as long as the user likes. If they
        // closed the screen or chose the tap way meanwhile, the recording
        // that just started must stop at once.
        if isClosed || phase != .listening {
            verifier.cancel()
            if isClosed { restoreAudioSession() }
        }
    }

    /// A match settles it. A miss listens once more, then offers the tap. It
    /// never says "wrong": a low score cannot tell a quiet voice from a
    /// recognizer that missed it.
    @MainActor
    private func verify() async {
        isVerifying = true
        let matched = await verifier.stopAndTranscribe()
        isVerifying = false

        // Transcribing takes up to 8 seconds. Whatever the user did in that
        // time (closed the screen, chose the tap way) wins over the result.
        guard !isClosed, phase == .listening else { return }

        if matched >= Self.matchThreshold {
            settle(method: "mic")
            return
        }
        guard !isSecondPass else {
            phase = .fallback
            return
        }
        isSecondPass = true
        await listen()
    }

    @MainActor
    private func settle(method: String) {
        guard phase != .spoken, !isClosed else { return }
        verifier.cancel()
        PremiumHaptics.safeSuccess()
        withAnimation(reduceMotion ? nil : DS.Motion.smooth) { phase = .spoken }
        // Spoken is done: it must not come back if the app is killed before
        // this screen is closed.
        SpeakOverInbox.markShown(delivery)
        AnalyticsService.shared.track("speak_over_spoken", parameters: [
            "method": method,
            "source": delivery.source.rawValue,
            "is_jesus_voice": gift.isJesusVoice
        ])
    }

    /// Both exits (X and the cover going away) end here. Stops the mic and
    /// hands the audio session back to playback.
    @MainActor
    private func close() {
        guard !isClosed else { return }
        isClosed = true
        verifier.cancel()
        restoreAudioSession()
    }

    /// The verifier leaves the session in `.record`, which silences the app's
    /// background music until something else resets it. Put back the category
    /// `AudioPlayerService` plays with. Only if the mic was actually used.
    @MainActor
    private func restoreAudioSession() {
        guard usedMic else { return }
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
    }
}

#Preview("From Maria") {
    SpeakOverReceivedView(
        delivery: SpeakOverDelivery(
            gift: SpeakOverGift(
                text: "By His wounds I am healed, and strength rises in this body every morning.",
                book: "Isaiah 53:5", from: "Maria", to: "Ana"),
            source: .link,
            receivedAt: Date()),
        verse: "But he was pierced for our transgressions, he was crushed for our iniquities; the punishment that brought us peace was on him, and by his wounds we are healed.",
        background: nil
    )
}

#Preview("No name, Jesus voice") {
    SpeakOverReceivedView(
        delivery: SpeakOverDelivery(
            gift: SpeakOverGift(
                text: "I took your sickness to the cross, and your body is healed.",
                book: "Jesus", from: nil, to: nil),
            source: .deferred,
            receivedAt: Date()),
        background: nil
    )
}

#Preview("Longest, no verse") {
    SpeakOverReceivedView(
        delivery: SpeakOverDelivery(
            gift: SpeakOverGift(
                text: String(repeating: "I am rooted, sealed and unshakeable in Christ. ", count: 6)
                    .trimmingCharacters(in: .whitespaces),
                book: nil, from: "Jonathan", to: nil),
            source: .link,
            receivedAt: Date()),
        background: nil
    )
}
