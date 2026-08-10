//
//  IncomingThoughtView.swift
//  SpeakLife
//
//  Screens 1 and 2 of Take It Captive: the thought arrives, and the user throws
//  it off the screen.
//
//  Two design rules carry these screens.
//
//  **The thought must look foreign.** Thin grey type, desaturated, recessed
//  behind glass, no gold, no navy, no warmth, no display face. Everything the
//  rest of the app uses to say "this is yours, receive it" is deliberately
//  withheld. The user should feel a low-grade wrongness looking at this. That
//  reaction is the training.
//
//  **The rejection is a swipe, not a tap.** A tap is too passive to encode a
//  reflex; the physical throw is what does the work. This is the single most
//  important interaction in the feature and must not be "simplified" into a
//  button. The card does not politely slide back — past the threshold it burns
//  off, with a heavy haptic at the moment of release.
//
//  Swipe direction is LEFT (open decision #1 in the spec, resolved): the
//  declaration feed pages VERTICALLY and this flow is presented full-screen, so
//  a horizontal throw collides with nothing. Right is handled too, but never as
//  "keep the thought" — see `onUnsure`.
//

import SwiftUI

struct IncomingThoughtView: View {

    let thought: IncomingThought
    /// The user threw it off screen. Carries how long they took, which is the
    /// reflex-training metric.
    let onReject: (TimeInterval) -> Void
    /// Swiped right. Never an "I'll keep it" — the app does not affirm a lie.
    let onUnsure: () -> Void
    let onEscapeHatch: () -> Void
    let onClose: () -> Void

    /// False on screen 1 (the thought alone), true on screen 2 (the question).
    @State private var isJudging = false
    @State private var dragX: CGFloat = 0
    @State private var isGone = false
    @State private var appearedAt = Date()
    @State private var burnOff = false

    /// Past this the throw commits. Generous, because a hesitant swipe is still
    /// a rejection and should not bounce back as a failure.
    private let commitThreshold: CGFloat = 110

    // Both of these were inline in the modifier chain, mixing CGFloat literals,
    // a Double conversion and generic `min`/`abs` inside a ternary. That is the
    // same shape that timed out the type checker in `TakeItCaptiveService` and
    // failed the archive, so they are computed here with explicit types.

    /// The card leans into the throw.
    private var tiltDegrees: Double {
        Double(dragX) / 22
    }

    /// Fades out as it travels, so the throw feels like it costs the thought
    /// something before the burn-off finishes it.
    private var cardOpacity: Double {
        if burnOff { return 0 }
        let travelled: Double = Double(abs(dragX))
        let capped: Double = travelled > 260 ? 260 : travelled
        return 1 - (capped / 420)
    }

    /// How far into a leftward throw the finger is, 0...1.
    ///
    /// Drives the NO stamp. The gesture had no feedback at all until the card
    /// left the screen, so "swipe left" was a thing you either already knew or
    /// discovered by accident — and the result arrived with nothing connecting
    /// it to what you did. Watching NO fade in under your thumb is what makes
    /// the direction mean something.
    private var rejectProgress: Double {
        guard dragX < 0 else { return 0 }
        let travelled: Double = Double(-dragX)
        let ratio: Double = travelled / Double(commitThreshold)
        return ratio > 1 ? 1 : ratio
    }

    var body: some View {
        ZStack {
            // No brand field. The screen the thought arrives on is cold and
            // slightly dead — the inversion on the REPLACE screen is what makes
            // that screen land.
            LinearGradient(colors: [Color(hex: "#1B1D22"), Color(hex: "#101216")],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                header

                Spacer(minLength: 0)

                thoughtCard
                    .offset(x: dragX, y: 0)
                    .rotationEffect(.degrees(tiltDegrees))
                    // Keyed to `burnOff`, not `isGone`. `isGone` is set outside
                    // the animation block (it has to be, it's the re-entry
                    // guard), so keying the fade to it would snap the card to
                    // invisible and swallow the burn-off entirely.
                    .opacity(cardOpacity)
                    .blur(radius: burnOff ? 18 : 0)
                    .scaleEffect(burnOff ? 0.86 : 1)
                    .gesture(throwGesture)

                Spacer(minLength: 0)

                footer
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
        }
        .onAppear {
            appearedAt = Date()
            // The thought gets a beat alone before the question arrives — that
            // pause is where the wrongness registers. An eager user can throw it
            // immediately; the gesture is live from the first frame.
            //
            // 2.6s, not the 1.4 this shipped with. At 1.4 the whole drill went
            // past before anyone could tell what had happened: the question
            // appeared and the card was already gone. The target is still under
            // a minute end to end, and a minute is a lot of room.
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.6) {
                withAnimation(DS.Motion.smooth) { isJudging = true }
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("INCOMING")
                .font(.system(size: 11, weight: .bold))
                .tracking(2.6)
                .foregroundColor(Color.white.opacity(0.38))
            Spacer()
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white.opacity(0.32))
                    .frame(width: 32, height: 32)
            }
            .accessibilityLabel("Close")
        }
    }

    // MARK: - The thought

    private var thoughtCard: some View {
        VStack(spacing: 0) {
            Text(thought.text)
                .font(.system(size: 26, weight: .light, design: .default))
                .foregroundColor(Color(hex: "#8B8F98"))
                .multilineTextAlignment(.center)
                .lineSpacing(6)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 26)
                .padding(.vertical, 44)
                .frame(maxWidth: .infinity)
                .background(
                    // Behind glass: the thought sits IN the surface, not on it.
                    RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                        .fill(Color.white.opacity(0.035))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                        .stroke(Color.white.opacity(0.07), lineWidth: 1)
                )
                // The card lights up as it is thrown, so the direction reads as
                // a verdict rather than a scroll.
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                        .stroke(Color(hex: "#E2574C").opacity(rejectProgress * 0.9), lineWidth: 2)
                )
                .overlay(rejectStamp)
                // An inward shadow is not a SwiftUI primitive; a soft inner
                // stroke reads the same way and costs nothing.
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                        .stroke(Color.black.opacity(0.5), lineWidth: 6)
                        .blur(radius: 6)
                        .mask(RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
                )
                .accessibilityLabel("An incoming thought: \(thought.text)")
                .accessibilityHint("Swipe left to reject it")
                .accessibilityAction(named: "Reject this thought") { commitThrow() }
        }
    }

    /// The verdict, appearing under the thumb as the card is thrown.
    ///
    /// Answers "Does this line up with who you are?" in the one word the
    /// gesture actually means. Without it the swipe was a mystery move that
    /// produced a declaration from nowhere.
    private var rejectStamp: some View {
        Text("NO")
            .font(.system(size: 44, weight: .black, design: .rounded))
            .tracking(4)
            .foregroundColor(Color(hex: "#E2574C"))
            .padding(.horizontal, 18)
            .padding(.vertical, 6)
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color(hex: "#E2574C"), lineWidth: 4)
            )
            .rotationEffect(.degrees(-12))
            .opacity(rejectProgress)
            .scaleEffect(0.85 + (rejectProgress * 0.15))
            .allowsHitTesting(false)
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: 18) {
            if isJudging {
                VStack(spacing: 10) {
                    Text("Does this line up with who you are?")
                        .font(.system(size: 19, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.92))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    // Names the answer, not the mechanic. "Swipe it off" told
                    // people what to do with their thumb but never what it
                    // meant, so the verdict arrived unexplained.
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 13, weight: .bold))
                        Text("Swipe left for NO")
                            .font(.system(size: 14, weight: .bold))
                    }
                    .foregroundColor(rejectProgress > 0.1
                                     ? Color(hex: "#E2574C")
                                     : .white.opacity(0.5))
                }
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            // Quiet on purpose. The drill is the default path; this is the door
            // out for someone who came in already carrying something.
            Button(action: onEscapeHatch) {
                Text("Something else is on my mind")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.36))
                    .underline()
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .animation(DS.Motion.smooth, value: isJudging)
    }

    // MARK: - Gesture

    private var throwGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                guard !isGone else { return }
                dragX = value.translation.width
            }
            .onEnded { value in
                guard !isGone else { return }
                if value.translation.width <= -commitThreshold {
                    commitThrow()
                } else if value.translation.width >= commitThreshold {
                    // Swiping right is NOT "keep the thought". There is no
                    // gesture in this app that agrees with a lie. It reads as
                    // "I'm not sure", and the flow answers with what God says.
                    withAnimation(DS.Motion.quick) { dragX = 0 }
                    PremiumHaptics.safeLight()
                    onUnsure()
                } else {
                    withAnimation(DS.Motion.bouncy) { dragX = 0 }
                }
            }
    }

    private func commitThrow() {
        guard !isGone else { return }
        isGone = true
        // The heaviest haptic the app has, fired at the moment of release. This
        // is the physical half of the reflex being trained.
        PremiumHaptics.safeHeavy()
        withAnimation(.easeIn(duration: 0.26)) {
            dragX = -520
            burnOff = true
        }
        // 0.26s of burn-off, then a held beat on the empty grey field before
        // the navy screen rises. Handing straight over at 0.26 meant the
        // declaration appeared in the same blink as the swipe, with nothing to
        // connect the two — "it all happened so fast I didn't know what was
        // happening". The pause is what makes it read as cause and effect.
        let elapsed = Date().timeIntervalSince(appearedAt)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.62) {
            onReject(elapsed)
        }
    }
}

// MARK: - Not sure

/// Where a right swipe lands: what God says about the thought, then straight on
/// to speaking it. Never a screen that agrees, and never a dead end.
struct ThoughtAnswerView: View {
    let thought: IncomingThought
    let onContinue: () -> Void
    /// Every screen in this full-screen flow carries a way out. A cover with no
    /// close control is a trap.
    let onClose: () -> Void

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: "#1B1D22"), Color(hex: "#101216")],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            VStack(spacing: DS.Spacing.lg) {
                HStack {
                    Spacer()
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white.opacity(0.32))
                            .frame(width: 32, height: 32)
                    }
                    .accessibilityLabel("Close")
                }

                Spacer()

                Text("HERE'S WHAT GOD SAYS")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(2.6)
                    .foregroundColor(DS.Palette.gold.opacity(0.85))

                Text(thought.verseText)
                    .font(.system(size: 19, weight: .regular))
                    .foregroundColor(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .lineSpacing(5)
                    .fixedSize(horizontal: false, vertical: true)

                Text(thought.book)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(DS.Palette.gold.opacity(0.8))

                Spacer()

                Button(action: onContinue) {
                    Text("Say it out loud")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(Color(hex: "#1A264D"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Capsule().fill(DS.Gradient.gold))
                }
                .buttonStyle(.dsPressable(feel: .tapSolid))
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 32)
        }
    }
}
