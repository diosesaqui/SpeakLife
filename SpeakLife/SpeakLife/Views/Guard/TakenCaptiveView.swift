//
//  TakenCaptiveView.swift
//  SpeakLife
//
//  What happens between naming the thought and speaking against it. Every
//  thought comes through here now, typed or served.
//
//  There is no question on this screen and nothing to answer. The screen this
//  replaced asked "does this line up with who you are?" and made the user throw
//  the thought off the display to answer it — and every control it offered was a
//  way of saying no. Swipe left for NO. "No. That's not me." "Something else is
//  on my mind." There was no way to say yes, which is the tell: it was never a
//  question. It was a gate with one key, standing between the user and the word
//  they came for.
//
//  So the app answers it. This screen is not an interaction, it is the action
//  taken in front of them:
//
//    the thought, cold and grey  →  seized and pulled down to nothing
//    →  the grey field warms to navy  →  the declaration rises
//
//  Four things it must keep doing:
//
//  1. **It has to be seen to happen.** A cut straight to the declaration is
//     indistinguishable from a screen that lost their input. The card visibly
//     goes, and the heavy haptic lands at the moment it does — that is the
//     receipt.
//  2. **It hands over already warm.** The background finishes navy so REPLACE
//     rises into a field that is already its own colour, and the two screens
//     read as one motion rather than two loads.
//  3. **The taking never waits on the user, the verse does.** No tap or
//     gesture starts the seize. But once the verse has landed the screen holds
//     on it until they tap Continue: a timed hand-off pulled the scripture away
//     while people were still reading it.
//  4. **A served thought gets read time first.** Someone who typed the sentence
//     wrote it seconds ago; someone handed one from the bank has never seen it,
//     and seizing a line they have not finished reading is a flicker rather than
//     an event. `isOwnWords` is the whole difference, and it only moves when the
//     seize starts — see `seizeAt`.
//

import SwiftUI

struct TakenCaptiveView: View {

    /// The thought, plus the counter it is being traded for. Only `text` is
    /// shown here — the declaration is the next screen's.
    let thought: IncomingThought
    /// True when the user typed this sentence, false when the bank served it.
    ///
    /// Controls one thing: how long the card sits before it is seized. Their own
    /// words need no reading time; a served line has never been seen before and
    /// gets a beat to land, or the seize is a flicker instead of an event.
    var isOwnWords: Bool = true
    /// Fired once the transition has played out.
    let onFinished: () -> Void
    /// Offered only on a served thought, and only while it is still on screen:
    /// the way back to the ask for someone the bank guessed wrong for. Nil on
    /// the typed route, where it would mean nothing.
    var onEscapeHatch: (() -> Void)?
    let onClose: () -> Void

    /// The card is seized: it desaturates, tightens, and is pulled down to
    /// nothing.
    @State private var seized = false
    /// The beat before the seize: the card lifts a hair, the way a hand closes
    /// before it pulls. The haptic's rising pull plays across this beat.
    @State private var bracing = false
    /// The field warms grey to navy under it.
    @State private var warmed = false
    /// The line that names what just happened, after the card has gone.
    @State private var showVerdict = false
    /// The verse lands a beat after the headline, then its reference, so the
    /// moment arrives in three steps rather than as one block of text.
    @State private var showVerse = false
    @State private var showReference = false
    /// Continue appears once the verse is fully on screen. The screen waits
    /// here for as long as they want to read.
    @State private var showContinue = false
    /// Set the instant the screen stops being live — by finishing, by the user
    /// closing it, or by the escape hatch.
    ///
    /// The schedule below is a run of `asyncAfter` calls and none of them can be
    /// cancelled. Without this, leaving the screen early still fires the heavy
    /// haptic on a dismissed view and still reports a thought taken at hand-off,
    /// right after `guard_task_abandoned` said the opposite. Every step checks
    /// it.
    @State private var ended = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let cold = Color(hex: "#1B1D22")
    private let colder = Color(hex: "#101216")
    private let navy = Color(hex: "#1A264D")
    private let deepNavy = Color(hex: "#0F1730")
    private let gold = GuardStyle.gold

    // The whole schedule, in one place so the timings can be read against each
    // other rather than hunted through the file.
    //
    // Everything after the seize is measured FROM the seize, so the read beat is
    // the only variable and the taking itself is identical on both routes.

    /// How long the thought sits before it is taken.
    ///
    /// 0.30s for their own words — they wrote it, they are waiting on the app,
    /// and a pause here is dead air. 1.70s for a served one, which is read time
    /// for a line they have never seen. The screen this replaced held that same
    /// line for 2.6s and then asked a question about it; this holds it long
    /// enough to land and then acts.
    private var seizeAt: Double { isOwnWords ? 0.30 : 1.70 }
    private var warmAt: Double { seizeAt + 0.42 }
    private var verdictAt: Double { seizeAt + 0.65 }
    /// The pull starts this long before the snap, so the haptic's rise and the
    /// card's lift share one beat.
    private let braceLead: Double = 0.14
    private var verseAt: Double { seizeAt + 0.95 }
    /// After the last word of the verse has come into focus.
    private var referenceAt: Double { seizeAt + 1.65 }
    /// A beat after the reference, so the button never competes with the
    /// verse for the eye. There is no timed hand-off: the screen waits on the
    /// tap.
    private var continueAt: Double { seizeAt + 2.05 }

    private static let verse = "\u{201C}We take captive every thought to make it obedient to Christ.\u{201D}"

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

                // One row, two occupants that never show together: the hatch
                // before the seize, Continue after the verse. Both stay in the
                // layout so the card never reflows when one swaps for the other.
                ZStack {
                    escapeHatch
                    continueButton
                }
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
            // It is not taken until it is taken, so the header never claims it
            // early. It fades on the seize rather than flipping to "TAKEN
            // CAPTIVE": the verdict says exactly that a beat later, and saying
            // it twice on one screen dulls both.
            Text("INCOMING")
                .font(GuardStyle.eyebrow)
                .tracking(GuardStyle.eyebrowTracking)
                .foregroundColor(GuardStyle.tertiary)
                .opacity(seized ? 0 : 1)
                .animation(DS.Motion.smooth, value: seized)
            Spacer()
            // The only control on the screen. A full-screen cover with no way
            // out is a trap even when it lasts a second and a half.
            Button(action: close) {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(GuardStyle.tertiary)
                    .frame(width: 32, height: 32)
            }
            .accessibilityLabel("Close")
        }
    }

    // MARK: - The card

    /// The thought, in cold treatment — thin grey type behind glass, no gold, no
    /// warmth, none of what the rest of the app uses to say "this is yours,
    /// receive it". It has to look foreign right up to the moment it goes, or
    /// its leaving means nothing, and the warm navy that follows lands on
    /// nothing.
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
            // Under Reduce Motion the card only fades: no lift, no shrink, no
            // blur, no drop.
            .scaleEffect(reduceMotion ? 1 : (seized ? 0.72 : (bracing ? 1.035 : 1)))
            .opacity(seized ? 0 : 1)
            .blur(radius: seized && !reduceMotion ? 22 : 0)
            .offset(y: reduceMotion ? 0 : (seized ? 26 : (bracing ? -4 : 0)))
            .accessibilityLabel("Taking captive: \(thought.text)")
    }

    /// The door out of a thought the bank guessed wrong, open for exactly as
    /// long as that thought is on screen.
    ///
    /// It is NOT a confirm step and it is not a question — the drill runs
    /// whether or not it is touched. It is there because a served thought can
    /// simply be the wrong one, and the honest answer to that is the ask, not a
    /// declaration against a lie the person was not fighting.
    ///
    /// Gone the instant the seize starts, because a declaration against a lie
    /// you already decided to keep fighting is not what that tap meant.
    ///
    /// It FADES rather than being removed, and the row holds its height on both
    /// routes even when there is no hatch to show. Removing it from the layout
    /// would let the spacers redistribute and shift the card at the exact frame
    /// the seize begins and the verdict lands in its place — a reflow disguised
    /// as an animation.
    private var escapeHatch: some View {
        let live = onEscapeHatch != nil && !seized
        return Button {
            guard !ended, let onEscapeHatch else { return }
            ended = true
            onEscapeHatch()
        } label: {
            Text("Something else is on my mind")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(GuardStyle.tertiary)
                .underline()
        }
        .buttonStyle(.plain)
        .opacity(live ? 1 : 0)
        .allowsHitTesting(live)
        .animation(DS.Motion.quick, value: seized)
    }

    /// The hand-off to REPLACE, on their timing rather than a clock.
    private var continueButton: some View {
        Button(action: finish) {
            Text("Continue")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(navy)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Capsule().fill(DS.Gradient.gold))
                .shadow(color: gold.opacity(0.35), radius: 16, y: 6)
        }
        .buttonStyle(.dsPressable(feel: .tapSolid))
        .guardReveal(showContinue, distance: 12)
        .allowsHitTesting(showContinue)
        .accessibilityHidden(!showContinue)
    }

    /// What just happened, in the words the feature is built on. It lands on the
    /// empty field after the card has gone, so the screen is never blank, and
    /// it stays until they tap Continue.
    ///
    /// The verse is quoted, not just cited. A bare "2 Corinthians 10:5" on
    /// every run read like a stray reference that never changed; the words say
    /// it is the verse the whole feature stands on.
    private var verdict: some View {
        VStack(spacing: 14) {
            // Comes into focus out of a blur, with its glow arriving after it.
            Text("Taken captive.")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .shadow(color: gold.opacity(showVerdict ? 0.5 : 0), radius: 18)
                .guardReveal(showVerdict, distance: 14)

            GuardRule(shown: showVerse)

            // The verse arrives one word at a time, so it is read as it lands.
            WordByWordText(text: Self.verse,
                           font: GuardStyle.scripture(17),
                           color: GuardStyle.scriptureInk.opacity(0.9),
                           shown: showVerse,
                           delay: 0.08)
                .frame(maxWidth: 300)

            Text("2 Corinthians 10:5")
                .textCase(.uppercase)
                .font(GuardStyle.reference)
                .tracking(GuardStyle.referenceTracking)
                .foregroundColor(gold.opacity(0.9))
                .guardReveal(showReference, distance: 4)
        }
        .multilineTextAlignment(.center)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Schedule

    private func play() {
        GuardHaptics.shared.prepare()
        // Brace. The card lifts as the haptic pull rises under the thumb.
        step(at: seizeAt - braceLead) {
            GuardHaptics.shared.seize()
            withAnimation(.spring(duration: 0.18, bounce: 0.3)) { bracing = true }
        }
        // Seize. The snap in the haptic lands on this frame, as the card goes.
        step(at: seizeAt) {
            withAnimation(.easeIn(duration: 0.34)) { seized = true }
        }
        // Warm. Grey to navy, so REPLACE rises into its own field.
        step(at: warmAt) {
            withAnimation(.easeInOut(duration: 0.6)) { warmed = true }
        }
        // The reveals carry their own springs (see `GuardReveal`), so these
        // only flip the state.
        step(at: verdictAt) {
            showVerdict = true
        }
        step(at: verseAt) {
            GuardHaptics.shared.verse()
            showVerse = true
        }
        step(at: referenceAt) {
            showReference = true
        }
        step(at: continueAt) {
            showContinue = true
        }
    }

    private func finish() {
        guard !ended else { return }
        ended = true
        onFinished()
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
