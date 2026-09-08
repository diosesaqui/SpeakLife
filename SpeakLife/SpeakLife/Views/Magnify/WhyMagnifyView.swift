//
//  WhyMagnifyView.swift
//  SpeakLife
//
//  Why this works, shown once before the first rep.
//
//  The whole feature rests on one idea that is genuinely counter-intuitive, and
//  a user who does not have it will read the daily task as "say a nice thing
//  about God" and quietly stop doing it. The idea is this: magnifying does not
//  make God bigger. He is already infinite and nothing anyone says adds an inch
//  to Him. It makes Him bigger TO THE SPEAKER. A telescope never moved a
//  mountain; it filled the eye with it.
//
//  Three constraints on this screen, all of them learned from onboarding
//  screens that did not survive contact:
//
//  1. **It is skippable from the first frame.** A wall of teaching between
//     someone and the thing they opened the app for is a gate, and this app has
//     already shipped one of those and had to take it out.
//  2. **It is shown ONCE, ever.** `MagnifyService.hasSeenWhy` is one-way. The
//     rotating line on BEHOLD carries the teaching from then on, a sentence a
//     day, which is how it actually lands — nobody absorbs a doctrine of praise
//     from three cards, and everybody absorbs it from ninety mornings.
//  3. **The proof is people, not argument.** Mary, Paul, Jehoshaphat, Job. Every
//     one of them magnified God BEFORE anything changed, and every one of them
//     was in a worse spot than the person reading this. That is the load-bearing
//     beat — it is what makes this credible at 2am rather than sentimental.
//

import SwiftUI

struct WhyMagnifyView: View {

    let onBegin: () -> Void
    let onClose: () -> Void

    @State private var beat = 0
    @State private var shown = false

    private let field = Color(hex: "#1A264D")
    private let deepField = Color(hex: "#0F1730")
    private let gold = Color(hex: "#F5B742")

    /// Three beats, in the only order that works: the mechanism, then what it
    /// costs you to believe it, then the people who did it first.
    private struct Beat {
        let kicker: String
        let headline: String
        let body: String
    }

    private let beats: [Beat] = [
        Beat(kicker: "WHAT MAGNIFY MEANS",
             headline: "A telescope never moved a mountain.",
             body: "It just filled your eyes with it. Magnifying doesn't make God bigger. He is already infinite. It makes Him bigger to you."),
        Beat(kicker: "WHY IT CHANGES THE DAY",
             headline: "Whatever you magnify, you get more of.",
             body: "Stare at the storm and it fills the sky. Lift Him higher and everything else finds its actual size. Nothing about the day has to change first."),
        Beat(kicker: "WHO DID IT FIRST",
             headline: "Every one of them did this before anything changed.",
             body: "Mary, with her life in ruins. Paul and Silas, in chains at midnight. Jehoshaphat, sending the worshippers out ahead of the army. Job, on the worst day he ever had.")
    ]

    private var current: Beat { beats[min(beat, beats.count - 1)] }
    private var isLast: Bool { beat >= beats.count - 1 }

    var body: some View {
        ZStack {
            LinearGradient(colors: [field, deepField], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            RadialGradient(colors: [gold.opacity(0.14), .clear],
                           center: .center, startRadius: 10, endRadius: 320)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                header

                Spacer(minLength: 0)

                Text(current.kicker)
                    .font(.system(size: 11, weight: .bold))
                    .tracking(2.6)
                    .foregroundColor(gold.opacity(0.9))

                Text(current.headline)
                    .font(.system(size: 27, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .minimumScaleFactor(0.7)
                    .fixedSize(horizontal: false, vertical: true)

                Text(current.body)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.75))
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Psalm 34:3")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(gold.opacity(0.8))
                    .padding(.top, 2)

                Spacer(minLength: 0)

                progressDots

                Button(action: advance) {
                    Text(isLast ? "Let's magnify Him" : "Next")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(Color(hex: "#1A264D"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Capsule().fill(DS.Gradient.gold))
                }
                .buttonStyle(.dsPressable(feel: .tapSolid))
            }
            .padding(.horizontal, 26)
            .padding(.vertical, 22)
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : 12)
            // Keyed on `beat` so each card re-enters rather than cross-fading
            // its text in place, which reads as a typo correction.
            .id(beat)
            .transition(.opacity)
        }
        .preferredColorScheme(.dark)
        .onAppear { withAnimation(DS.Motion.smooth) { shown = true } }
    }

    private var header: some View {
        HStack {
            Text("MAGNIFY")
                .font(.system(size: 11, weight: .bold))
                .tracking(2.6)
                .foregroundColor(.white.opacity(0.38))
            Spacer()
            // Live from the first frame. Someone who already knows this, or who
            // opened the app to speak and not to read, must never be held here.
            Button(action: onClose) {
                Text("Skip")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.45))
                    .frame(height: 32)
            }
            .accessibilityLabel("Skip")
        }
    }

    private var progressDots: some View {
        HStack(spacing: 6) {
            ForEach(0..<beats.count, id: \.self) { index in
                Capsule()
                    .fill(index == beat ? gold : Color.white.opacity(0.18))
                    .frame(width: index == beat ? 18 : 6, height: 6)
            }
        }
        .animation(DS.Motion.quick, value: beat)
        .frame(maxWidth: .infinity)
    }

    private func advance() {
        PremiumHaptics.safeLight()
        guard !isLast else {
            onBegin()
            return
        }
        withAnimation(DS.Motion.smooth) { beat += 1 }
    }
}
