//
//  HigherGroundView.swift
//  SpeakLife
//
//  The last screen. One number, and nothing else.
//
//  What is deliberately absent is the whole design:
//    · no chart
//    · no weekly summary
//    · no streak
//    · no "you missed 3 days"
//    · no percentage, no average, no comparison
//
//  A broken streak tells a believer mid-storm that they failed at worship. That
//  is law, and it is the exact inversion of this app's grace-first, finished-work
//  positioning. The count only ever goes up. If a future change wants a metric on
//  this screen, the answer is no.
//
//  The one addition over `GroundTakenView`, which this replaces, is the milestone
//  line — a single sentence at 1, 7, 30, 100 and 365 saying what the practice has
//  been doing. It is not a chart and not a streak: it reads off the same
//  cumulative, monotonic counter the badges already read, so it can never tell
//  someone they lost anything. It exists because the "why" of this feature needs
//  to land more than once, and the moment just after someone has spoken is when
//  they are most able to hear it.
//

import SwiftUI

struct HigherGroundView: View {

    let total: Int
    /// Storm mode closes differently — see `closingLine`.
    var isStorm: Bool = false
    let onDone: () -> Void

    @State private var showCount = false
    @State private var showPlusOne = false

    private let gold = Color(hex: "#F5B742")

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: "#22336B"), Color(hex: "#0C1226")],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            RadialGradient(colors: [gold.opacity(0.20), .clear],
                           center: .center, startRadius: 8, endRadius: 320)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            VStack(spacing: DS.Spacing.md) {
                Spacer()

                Text("+1")
                    .font(.system(size: 64, weight: .heavy, design: .rounded))
                    .foregroundStyle(DS.Gradient.gold)
                    .scaleEffect(showPlusOne ? 1 : 0.6)
                    .opacity(showPlusOne ? 1 : 0)

                VStack(spacing: 4) {
                    Text("\(total)")
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .contentTransition(.numericText())
                    Text(total == 1 ? "time you've magnified the Lord" : "times you've magnified the Lord")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
                .opacity(showCount ? 1 : 0)
                .offset(y: showCount ? 0 : 10)

                Text(closingLine)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(gold.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 24)
                    .padding(.top, 6)
                    .opacity(showCount ? 1 : 0)

                Spacer()

                Button(action: onDone) {
                    Text("Done")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(Color(hex: "#1A264D"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Capsule().fill(DS.Gradient.gold))
                }
                .buttonStyle(.dsPressable(feel: .tapSolid))
                .opacity(showCount ? 1 : 0)
                .padding(.horizontal, 28)
                .padding(.bottom, 24)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear(perform: play)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(total) times you've magnified the Lord. \(closingLine)")
    }

    /// The one sentence under the number.
    ///
    /// Milestones read off the cumulative counter, so they can only ever announce
    /// something gained. Storm mode gets its own line, because the person reading
    /// it is not celebrating a milestone — they came here because it was a lot,
    /// and the honest thing to say is that the size of the storm was never the
    /// variable.
    private var closingLine: String {
        if isStorm {
            return "The storm didn't change size. He was always this big."
        }
        switch total {
        case 1:
            return "He didn't get bigger just now. Your view of Him did."
        case 7:
            return "Seven times you've lifted Him higher than what you were facing."
        case 30:
            return "Thirty. This is becoming a reflex, not an effort."
        case 100:
            return "A hundred times you've made Him the biggest thing in the room."
        case 365:
            return "Three hundred and sixty-five. A whole year of magnifying the Lord."
        default:
            return "He is bigger than this. You just said so out loud."
        }
    }

    private func play() {
        PremiumHaptics.safeSuccess()
        withAnimation(DS.Motion.bouncy) { showPlusOne = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            withAnimation(DS.Motion.smooth) { showCount = true }
        }
    }
}
