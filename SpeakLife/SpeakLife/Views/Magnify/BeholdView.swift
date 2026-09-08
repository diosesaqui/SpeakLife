//
//  BeholdView.swift
//  SpeakLife
//
//  The moment God gets bigger. This is the emotional centre of the feature and
//  the one screen that teaches the mechanism without saying it.
//
//  It is a deliberate inversion of `TakenCaptiveView`, which it replaces. That
//  screen took a thought — cold, grey, foreign — and shrank it to nothing:
//
//      scale 1.0 → 0.72   ·   opacity 1 → 0   ·   blur 0 → 22   ·   pulled down
//
//  This one runs the same choreography backwards, on God rather than on a lie:
//
//      a dim point of light  →  it EXPANDS and fills the screen
//      →  the field blooms gold  →  the name lands, then the reason
//
//  The user is not told that magnifying enlarges what you look at. They watch it
//  happen. That is worth more than the sentence, and the sentence is on the
//  screen anyway, underneath, rotating a new one every day.
//
//  Four things it must keep doing:
//
//  1. **The growth has to be seen.** A cut straight to the declaration is
//     indistinguishable from a screen that loaded slowly. The name visibly
//     swells, and the haptic lands on the frame it does — that is the receipt.
//  2. **It hands over already warm.** The field finishes navy-and-gold so SPEAK
//     rises into a field that is already its own colour, and the two screens read
//     as one motion rather than two loads.
//  3. **It never traps the user, and never stalls them.** It advances on its own,
//     and a tap anywhere advances it early. Someone who has read it should not
//     have to wait out an animation to say the thing.
//  4. **Storm mode is faster.** Someone who reached for this at 2am is not here
//     to admire a transition. `isStorm` cuts the dwell roughly in half and
//     changes the kicker; nothing else about the screen moves, because the thing
//     they need to see is the same thing.
//

import SwiftUI

struct BeholdView: View {

    let entry: MagnifyEntry
    /// Today's rotating reason, from `MagnifyService.whyLine(for:)`. Nil is
    /// supported — the screen simply holds its shape without it.
    var whyLine: String?
    /// Storm mode: shorter dwell, different kicker.
    var isStorm: Bool = false
    /// Fired once the sequence has played out, or when the user taps to skip it.
    let onFinished: () -> Void
    let onClose: () -> Void

    /// The name of God swells from a dim point to fill the screen.
    @State private var magnified = false
    /// The field blooms gold behind it.
    @State private var bloomed = false
    /// The plain-English attribute and the verse, after the name has landed.
    @State private var showMeaning = false
    /// The rotating reason, last, so it reads as a footnote to what was just
    /// seen rather than as an instruction in front of it.
    @State private var showWhy = false
    /// Set the instant the screen stops being live — by finishing, by a tap, or
    /// by the user closing it.
    ///
    /// The schedule below is five `asyncAfter` calls and none of them can be
    /// cancelled. Without this, leaving early still fires the haptic on a
    /// dismissed view and still hands off to SPEAK behind the user's back. Every
    /// step checks it.
    @State private var ended = false

    private let dim = Color(hex: "#0F1730")
    private let field = Color(hex: "#1A264D")
    private let lit = Color(hex: "#22336B")
    private let gold = Color(hex: "#F5B742")

    // The whole schedule, in one place so the timings can be read against each
    // other rather than hunted through the file.

    /// How long the point sits before it swells. Short — the growth IS the
    /// screen, and a delay in front of it is dead air.
    private var magnifyAt: Double { isStorm ? 0.18 : 0.32 }
    private var bloomAt: Double { magnifyAt + 0.30 }
    private var meaningAt: Double { magnifyAt + 0.62 }
    private var whyAt: Double { magnifyAt + 1.15 }
    /// The dwell. Long enough to actually behold something, short enough that the
    /// whole rep still lands under a minute.
    private var handOffAt: Double { magnifyAt + (isStorm ? 1.85 : 3.15) }

    var body: some View {
        ZStack {
            LinearGradient(colors: bloomed ? [lit, field] : [field, dim],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            // The bloom grows with the name. This is the field getting brighter
            // because something in it got bigger, which is the whole metaphor.
            RadialGradient(colors: [gold.opacity(bloomed ? 0.30 : 0.03), .clear],
                           center: .center,
                           startRadius: 8,
                           endRadius: bloomed ? 420 : 120)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            VStack(spacing: 0) {
                header

                Spacer(minLength: 0)

                VStack(spacing: DS.Spacing.md) {
                    nameOfGod
                    meaning
                }
                .frame(maxWidth: .infinity)

                Spacer(minLength: 0)

                why
            }
            .padding(.horizontal, 26)
            .padding(.vertical, 20)
        }
        .preferredColorScheme(.dark)
        // A tap anywhere moves on. Someone who has read it should never have to
        // wait out the rest of an animation to speak.
        .contentShape(Rectangle())
        .onTapGesture { finish() }
        .onAppear(perform: play)
        // The catch-all. `close()` covers the button and `finish()` covers the
        // tap, but the host can take the screen away for its own reasons, and a
        // pending step that outlives the view would hand off to SPEAK with nobody
        // watching.
        .onDisappear { ended = true }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(entry.nameOfGod). \(entry.attribute). \(entry.verseText)")
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text(isStorm ? "HE IS BIGGER THAN THIS" : "BEHOLD HIM")
                .font(.system(size: 11, weight: .bold))
                .tracking(2.6)
                .foregroundColor(magnified ? gold.opacity(0.9) : .white.opacity(0.35))
                .animation(DS.Motion.smooth, value: magnified)
            Spacer()
            // The only control on the screen. A full-screen cover with no way out
            // is a trap even when it lasts three seconds.
            Button(action: close) {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white.opacity(0.32))
                    .frame(width: 32, height: 32)
            }
            .accessibilityLabel("Close")
        }
    }

    // MARK: - The name

    /// The name of God, in the warmest treatment the app has — gold gradient,
    /// heavy, glowing. It starts small and dim and grows into that.
    ///
    /// Compare `TakenCaptiveView.thoughtCard`, which had to look foreign right up
    /// to the moment it went. This has to look like the most true thing on the
    /// screen from the moment it arrives, because it is.
    private var nameOfGod: some View {
        Text(entry.nameOfGod)
            .font(.system(size: 34, weight: .heavy, design: .rounded))
            .foregroundStyle(nameFill)
            .multilineTextAlignment(.center)
            .lineSpacing(2)
            .minimumScaleFactor(0.55)
            .fixedSize(horizontal: false, vertical: true)
            .shadow(color: gold.opacity(magnified ? 0.45 : 0), radius: 26)
            // The inversion, in four modifiers. Every one of them is the exact
            // opposite of the seize it replaces.
            .scaleEffect(magnified ? 1 : 0.55)
            .opacity(magnified ? 1 : 0.35)
            .blur(radius: magnified ? 0 : 8)
    }

    /// Lifted out of the modifier chain — a ternary between two `AnyShapeStyle`
    /// wrappers inside `.foregroundStyle` is the kind of nesting that costs the
    /// type checker real time, and this feature's predecessor failed an Xcode
    /// Cloud archive on exactly that class of expression.
    private var nameFill: AnyShapeStyle {
        magnified
            ? AnyShapeStyle(DS.Gradient.gold)
            : AnyShapeStyle(Color.white.opacity(0.30))
    }

    /// What the name means, in plain English, and the verse under it.
    ///
    /// The attribute exists because rule 15 outranks reverence for the vocabulary:
    /// "Jehovah Rapha" is the weightier line and "The God who heals" is the one
    /// that lands instantly, so the screen carries both rather than choosing.
    private var meaning: some View {
        VStack(spacing: DS.Spacing.sm) {
            Text(entry.attribute)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.92))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 5) {
                Text(entry.verseText)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(.white.opacity(0.66))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                Text(entry.book)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(gold.opacity(0.85))
            }
            .padding(.top, 2)
        }
        .opacity(showMeaning ? 1 : 0)
        .offset(y: showMeaning ? 0 : 10)
    }

    /// The teaching layer, one line a day.
    ///
    /// This is how the "why" actually gets into someone — not from the three
    /// cards they saw once on first run, but from ninety mornings of a different
    /// sentence under the name of God. It is set apart and quiet on purpose: it
    /// is a footnote to what was just seen, never an instruction in front of it.
    private var why: some View {
        Group {
            if let whyLine {
                Text(whyLine)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.48))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 8)
            }
        }
        .opacity(showWhy ? 1 : 0)
        .frame(minHeight: 34)
    }

    // MARK: - Schedule

    private func play() {
        // The swell. The heaviest haptic the app has, on the frame the name grows
        // — the same one the seize it replaces fired, because it is the same size
        // of event pointed the other way.
        step(at: magnifyAt) {
            PremiumHaptics.safeHeavy()
            withAnimation(.spring(response: 0.62, dampingFraction: 0.72)) { magnified = true }
        }
        step(at: bloomAt) {
            withAnimation(.easeInOut(duration: 0.75)) { bloomed = true }
        }
        step(at: meaningAt) {
            withAnimation(DS.Motion.smooth) { showMeaning = true }
        }
        step(at: whyAt) {
            withAnimation(DS.Motion.smooth) { showWhy = true }
        }
        step(at: handOffAt) { finish() }
    }

    /// One beat of the schedule, skipped if the screen is no longer live.
    private func step(at delay: Double, _ body: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            guard !ended else { return }
            body()
        }
    }

    private func finish() {
        guard !ended else { return }
        ended = true
        onFinished()
    }

    /// Closing ends the schedule before it can hand off to a screen the user
    /// walked away from.
    private func close() {
        guard !ended else { return }
        ended = true
        onClose()
    }
}
