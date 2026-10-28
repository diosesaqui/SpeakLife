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
    /// The ripple and sparks: gathered at the centre, then thrown out.
    @State private var burstArmed = false
    @State private var burstFired = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: "#1A264D"), Color(hex: "#0C1226")],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            RadialGradient(colors: [DS.Palette.gold.opacity(glowing ? 0.34 : 0.18), .clear],
                           center: .center, startRadius: 8, endRadius: glowing ? 380 : 300)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            VStack(spacing: DS.Spacing.md) {
                Spacer()

                // The +1 pops out of a blur on a bouncy spring, with a gold
                // ripple and a ring of sparks thrown out behind it.
                ZStack {
                    GoldBurst(armed: burstArmed, fired: burstFired)
                    Text("+1")
                        .font(.system(size: 64, weight: .heavy, design: .rounded))
                        .foregroundStyle(DS.Gradient.gold)
                        .shadow(color: GuardStyle.gold.opacity(showPlusOne ? 0.55 : 0), radius: 22)
                        .scaleEffect(showPlusOne || reduceMotion ? 1 : 0.4)
                        .blur(radius: showPlusOne || reduceMotion ? 0 : 12)
                        .opacity(showPlusOne ? 1 : 0)
                }

                VStack(spacing: 4) {
                    Text("\(displayedTotal ?? max(total - 1, 0))")
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .contentTransition(.numericText(countsDown: false))
                    Text(total == 1 ? "thought taken captive" : "thoughts taken captive")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(GuardStyle.secondary)
                }
                .guardReveal(showCount, distance: 12)

                VStack(spacing: 12) {
                    GuardRule(shown: showCount, delay: 0.15)
                    Text("That's ground you don't give back.")
                        .font(GuardStyle.scripture(18))
                        .foregroundColor(GuardStyle.scriptureInk.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .guardReveal(showCount, delay: 0.22)
                }
                .padding(.top, 10)

                Spacer()

                Button(action: onDone) {
                    Text("Done")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(Color(hex: "#1A264D"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Capsule().fill(DS.Gradient.gold))
                        .shadow(color: GuardStyle.gold.opacity(0.35), radius: 16, y: 6)
                }
                .buttonStyle(.dsPressable(feel: .tapSolid))
                .guardReveal(showCount, delay: 0.4, distance: 20)
                .padding(.top, 12)
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 32)
        }
        .onAppear(perform: celebrate)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Ground taken. \(total) thoughts taken captive.")
    }

    /// The whole beat, in order: pop and bloom, ripple and sparks, the count
    /// arriving, then the number rolling over with a tick.
    private func celebrate() {
        GuardHaptics.shared.celebrate()
        burstArmed = true
        withAnimation(.spring(duration: 0.55, bounce: 0.5)) { showPlusOne = true }
        withAnimation(.easeOut(duration: 0.45)) { glowing = true }
        // The next frame, so the sparks start gathered and fly from there.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            burstFired = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.easeInOut(duration: 1.0)) { glowing = false }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            showCount = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.85) {
            GuardHaptics.shared.tick()
            withAnimation(.spring(duration: 0.5, bounce: 0.25)) { displayedTotal = total }
        }
    }
}
