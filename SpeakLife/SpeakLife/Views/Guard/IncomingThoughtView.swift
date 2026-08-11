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
//  **This screen is for a thought the app served.** It asks "does this line up
//  with who you are?" and has the user throw it off — the right question for a
//  line they are meeting for the first time, and the whole point of the bank.
//  A thought the user TYPED never comes here: they answered that question by
//  writing the sentence down, and re-asking it puts a gate in front of the word
//  they came for. That route runs through `TakenCaptiveView` instead.
//
//  **The rejection is a swipe.** A tap is too passive to encode a reflex; the
//  physical throw is what does the work, and it stays the primary interaction.
//  The card does not politely slide back — past the threshold it burns off, with
//  a heavy haptic at the moment of release.
//
//  There is ALSO a button, and it is not a "simplification" of the swipe — it is
//  the floor under it. Shipped swipe-only, this screen was a dead end: the drag
//  only lived on the card itself, so a swipe across the empty field beside it
//  did nothing, and the sole instruction was one line of 14pt grey text. People
//  landed here and could not get out — they never reached the declaration this
//  whole flow exists to put in their mouth. The gesture keeps top billing; the
//  button guarantees nobody is trapped holding the lie because they didn't
//  guess the mechanic.
//
//  Swipe direction is LEFT, and left only (open decision #1 in the spec,
//  resolved): the declaration feed pages VERTICALLY and this flow is presented
//  full-screen, so a horizontal throw collides with nothing. A right swipe
//  springs back and does nothing — there is no gesture here that agrees with a
//  lie, and no second destination worth having, since the user typed this
//  thought themselves precisely in order to reject it.
//

import SwiftUI

struct IncomingThoughtView: View {

    let thought: IncomingThought
    /// The user threw it off screen. Carries how long they took, which is the
    /// reflex-training metric.
    let onReject: (TimeInterval) -> Void
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

                // The gesture lives on this whole band, not on the card alone.
                // Attached to the card, the drag was only live inside a shape
                // that occupies about a third of the screen and moves out from
                // under the finger as soon as it starts travelling — so a swipe
                // that began on the empty field beside it did nothing at all,
                // with no way to tell that from the gesture being broken.
                //
                // The clear layer stays put while the card flies, so the hit
                // area does not travel with the throw.
                ZStack {
                    Color.clear.contentShape(Rectangle())

                    thoughtCard
                        .offset(x: dragX, y: 0)
                        .rotationEffect(.degrees(tiltDegrees))
                        // Keyed to `burnOff`, not `isGone`. `isGone` is set
                        // outside the animation block (it has to be, it's the
                        // re-entry guard), so keying the fade to it would snap
                        // the card to invisible and swallow the burn-off
                        // entirely.
                        .opacity(cardOpacity)
                        .blur(radius: burnOff ? 18 : 0)
                        .scaleEffect(burnOff ? 0.86 : 1)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .gesture(throwGesture)

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
            //
            // 2.6 is safe here BECAUSE this screen is now bank-only. A thought
            // the user typed themselves never reaches it — that route goes
            // through `TakenCaptiveView`, which asks nothing and plays out on
            // its own. Holding someone for 2.6s in front of their own sentence,
            // with no visible way forward, is most of why this read as frozen.
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
            // Clears the moment the throw commits, so the held beat before the
            // navy screen rises is an empty field rather than a grey button
            // still sitting under a card that has already burned off.
            if isJudging, !isGone {
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

                    rejectButton
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
        // `isGone` is set outside the animation block — it is the re-entry
        // guard and has to be — so the footer keys its own animation to it.
        .animation(DS.Motion.smooth, value: isGone)
    }

    /// The way through for everyone the gesture loses.
    ///
    /// It says the same word the throw says, so tapping it is not a lesser
    /// answer — it is the same verdict, spoken instead of thrown. It runs
    /// `commitThrow()`, so the card still burns off and the haptic still fires:
    /// the tap buys the same moment, not a shortcut past it.
    private var rejectButton: some View {
        Button(action: commitThrow) {
            Text("No. That's not me.")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(Color(hex: "#E2574C"))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    Capsule().fill(Color(hex: "#E2574C").opacity(0.12))
                )
                .overlay(
                    Capsule().stroke(Color(hex: "#E2574C").opacity(0.55), lineWidth: 1.5)
                )
        }
        .buttonStyle(.dsPressable(feel: .tapSolid))
        .padding(.top, 4)
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
                } else {
                    // Right does nothing, on purpose.
                    //
                    // It used to route to an "I'm not sure" screen, which then
                    // continued to the same declaration — so both directions
                    // reached the same place and the gesture meant nothing. And
                    // now that the user TYPES the thought rather than being
                    // handed one, "not sure" is not a state they can be in:
                    // they already named it as something to reject.
                    //
                    // Left is the only committing throw. Everything else springs
                    // back, which is what makes the left one deliberate.
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
