//
//  TakenCaptiveView.swift
//  SpeakLife
//
//  What happens between naming the thought and speaking against it, when the
//  user typed the thought themselves.
//
//  There is no question on this screen and nothing to answer. They wrote the
//  sentence ten seconds ago precisely in order to be rid of it — asking "does
//  this line up with who you are?" and making them throw it off the screen is
//  asking them to re-answer a question they already answered by typing. The
//  swipe still owns `IncomingThoughtView`, where it belongs: a thought served
//  from the bank is one they are meeting for the first time, and rejecting it
//  is the training.
//
//  So this screen is not an interaction. It is the app taking the action, in
//  front of them, in about a second and a half:
//
//    their words, cold and grey  →  seized and pulled down to nothing
//    →  the grey field warms to navy  →  the declaration rises
//
//  Three things it must keep doing:
//
//  1. **It has to be seen to happen.** A cut straight to the declaration is
//     indistinguishable from a screen that lost their input. The card visibly
//     goes, and the heavy haptic lands at the moment it does — that is the
//     receipt.
//  2. **It hands over already warm.** The background finishes navy so REPLACE
//     rises into a field that is already its own colour, and the two screens
//     read as one motion rather than two loads.
//  3. **It never waits on the user.** No tap, no gesture, no way to get stuck.
//     The only control on screen is the close button.
//

import SwiftUI

struct TakenCaptiveView: View {

    /// The thought in the user's own words, plus the counter it is being traded
    /// for. Only `text` is shown here — the declaration is the next screen's.
    let thought: IncomingThought
    /// Fired once the transition has played out.
    let onFinished: () -> Void
    let onClose: () -> Void

    /// The card is seized: it desaturates, tightens, and is pulled down to
    /// nothing.
    @State private var seized = false
    /// The field warms grey to navy under it.
    @State private var warmed = false
    /// The line that names what just happened, after the card has gone.
    @State private var showVerdict = false
    /// Set the instant the screen stops being live — by finishing, or by the
    /// user closing it.
    ///
    /// The schedule below is four `asyncAfter` calls and none of them can be
    /// cancelled. Without this, closing the screen at 0.4s still fires the
    /// heavy haptic on a dismissed view and still reports a thought taken at
    /// 1.85s, right after `guard_task_abandoned` said the opposite. Every step
    /// checks it.
    @State private var ended = false

    private let cold = Color(hex: "#1B1D22")
    private let colder = Color(hex: "#101216")
    private let navy = Color(hex: "#1A264D")
    private let deepNavy = Color(hex: "#0F1730")
    private let gold = Color(hex: "#F5B742")

    // The whole schedule, in one place so the timings can be read against each
    // other rather than hunted through the file.
    private static let seizeAt: Double = 0.30
    private static let warmAt: Double = 0.72
    private static let verdictAt: Double = 0.95
    private static let handOffAt: Double = 1.85

    var body: some View {
        ZStack {
            LinearGradient(colors: warmed ? [navy, deepNavy] : [cold, colder],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            // The warmth arrives with the navy, so the field is already lit when
            // REPLACE rises into it.
            RadialGradient(colors: [gold.opacity(warmed ? 0.16 : 0), .clear],
                           center: .center, startRadius: 10, endRadius: 320)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            VStack(spacing: 0) {
                header

                Spacer(minLength: 0)

                ZStack {
                    thoughtCard
                    verdict
                }
                .frame(maxWidth: .infinity)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
        }
        .onAppear(perform: play)
        // The catch-all. `close()` covers the button, but the host can take the
        // screen away for its own reasons, and a pending step that outlives the
        // view would report a thought taken that nobody was there for.
        .onDisappear { ended = true }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("TAKEN CAPTIVE")
                .font(.system(size: 11, weight: .bold))
                .tracking(2.6)
                .foregroundColor(warmed ? gold.opacity(0.9) : .white.opacity(0.38))
            Spacer()
            // The only control on the screen. A full-screen cover with no way
            // out is a trap even when it lasts a second and a half.
            Button(action: close) {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white.opacity(0.32))
                    .frame(width: 32, height: 32)
            }
            .accessibilityLabel("Close")
        }
    }

    // MARK: - The card

    /// Their sentence, in the same cold treatment `IncomingThoughtView` gives a
    /// thought — thin grey type behind glass, no gold, no warmth. It has to look
    /// foreign right up to the moment it goes, or its leaving means nothing.
    private var thoughtCard: some View {
        Text(thought.text)
            .font(.system(size: 26, weight: .light))
            .foregroundColor(Color(hex: "#8B8F98"))
            .multilineTextAlignment(.center)
            .lineSpacing(6)
            // The bank's thoughts are one short line each; a typed one is
            // whatever the person needed to write, and the field they wrote it
            // in does not stop them. The card shrinks to hold it rather than
            // running off the bottom of the screen.
            .lineLimit(7)
            .minimumScaleFactor(0.55)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 26)
            .padding(.vertical, 44)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                    .fill(Color.white.opacity(0.035))
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                    .stroke(Color.white.opacity(0.07), lineWidth: 1)
            )
            // The border flares red as it is taken, the way the swipe lights the
            // card as it is thrown. It needs no fade of its own — the card's
            // opacity is running to zero across the same 0.34s, so the flare
            // arrives and leaves with it.
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                    .stroke(Color(hex: "#E2574C").opacity(seized ? 0.9 : 0), lineWidth: 2)
            )
            .scaleEffect(seized ? 0.72 : 1)
            .opacity(seized ? 0 : 1)
            .blur(radius: seized ? 22 : 0)
            .offset(y: seized ? 26 : 0)
            .accessibilityLabel("Taking captive: \(thought.text)")
    }

    /// What just happened, in the words the feature is built on. It lands on the
    /// empty field after the card has gone, so the screen is never blank and the
    /// second and a half never reads as a stall.
    private var verdict: some View {
        VStack(spacing: 10) {
            Text("Taken captive.")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            Text("2 Corinthians 10:5")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(gold.opacity(0.85))
        }
        .multilineTextAlignment(.center)
        .opacity(showVerdict ? 1 : 0)
        .scaleEffect(showVerdict ? 1 : 0.94)
    }

    // MARK: - Schedule

    private func play() {
        // Seize. The heaviest haptic the app has, on the frame the card goes —
        // the same one the throw fires, because it is the same event.
        step(at: Self.seizeAt) {
            PremiumHaptics.safeHeavy()
            withAnimation(.easeIn(duration: 0.34)) { seized = true }
        }
        // Warm. Grey to navy, so REPLACE rises into its own field.
        step(at: Self.warmAt) {
            withAnimation(.easeInOut(duration: 0.6)) { warmed = true }
        }
        step(at: Self.verdictAt) {
            withAnimation(DS.Motion.smooth) { showVerdict = true }
        }
        step(at: Self.handOffAt) {
            ended = true
            onFinished()
        }
    }

    /// One beat of the schedule, skipped if the screen is no longer live.
    private func step(at delay: Double, _ body: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            guard !ended else { return }
            body()
        }
    }

    /// Closing ends the schedule before it can report a thought taken that the
    /// user walked away from.
    private func close() {
        guard !ended else { return }
        ended = true
        onClose()
    }
}
