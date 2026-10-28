//
//  GroundTakenView.swift
//  SpeakLife
//
//  Screen 4. One number, and nothing else.
//
//  What is deliberately absent is the whole design:
//    · no chart
//    · no weekly summary
//    · no streak
//    · no "you missed 3 days"
//    · no percentage, no average, no comparison
//
//  Thought-monitoring features drift into self-surveillance fast, and a broken
//  streak tells a believer mid-storm that they failed at guarding their mind.
//  That is law, and it is the exact inversion of this app's grace-first,
//  finished-work positioning. Ground taken only ever goes up. If a future change
//  wants a metric on this screen, the answer is no.
//

import SwiftUI

struct GroundTakenView: View {

    let total: Int
    let onDone: () -> Void

    @State private var showCount = false
    @State private var showPlusOne = false
    /// Starts one below the new total and rolls up, so the number is seen to
    /// grow rather than simply appear.
    @State private var displayedTotal: Int?
    /// The bloom swells once as the +1 lands, then settles back.
    @State private var glowing = false

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: "#1A264D"), Color(hex: "#0C1226")],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            RadialGradient(colors: [DS.Palette.gold.opacity(glowing ? 0.34 : 0.18), .clear],
                           center: .center, startRadius: 8, endRadius: glowing ? 360 : 300)
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
                    Text("\(displayedTotal ?? max(total - 1, 0))")
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .contentTransition(.numericText())
                    Text(total == 1 ? "thought taken captive" : "thoughts taken captive")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.7))
                }
                .opacity(showCount ? 1 : 0)
                .offset(y: showCount ? 0 : 10)

                VStack(spacing: 12) {
                    GuardRule()
                    Text("That's ground you don't give back.")
                        .font(GuardStyle.scripture(18))
                        .foregroundColor(GuardStyle.scriptureInk.opacity(0.9))
                        .multilineTextAlignment(.center)
                }
                .opacity(showCount ? 1 : 0)
                .padding(.top, 10)

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
                .padding(.top, 12)
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 32)
        }
        .onAppear {
            PremiumHaptics.safeCelebrationBurst()
            withAnimation(DS.Motion.bouncy) { showPlusOne = true }
            withAnimation(.easeOut(duration: 0.45)) { glowing = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(.easeInOut(duration: 0.9)) { glowing = false }
            }
            withAnimation(DS.Motion.smooth.delay(0.35)) { showCount = true }
            // Rolls the digit up once the count is on screen.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
                withAnimation(DS.Motion.smooth) { displayedTotal = total }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Ground taken. \(total) thoughts taken captive.")
    }
}
