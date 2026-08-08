//
//  WeeklyFocusCard.swift
//  SpeakLife
//
//  Layer 2 of the Sunday ask, and the one that actually matters.
//
//  Push tap-through is low single digits, so the notification is the
//  invitation and this card is the capture surface. It stays pinned for the
//  whole window (Sunday 7 PM → Monday 11:59 PM local) and disappears when the
//  week locks.
//
//  Dismissal hides it for the rest of THIS window only — never for future
//  weeks. "Not now" is about tonight.
//

import SwiftUI

struct WeeklyFocusCard: View {

    let question: String
    /// True at three-plus carry-overs, when the question itself has changed.
    var isEscalating: Bool = false
    let onSpeak: () -> Void
    let onDismiss: () -> Void

    @State private var appeared = false

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {

            HStack(spacing: 6) {
                Image(systemName: isEscalating ? "flame.fill" : "calendar")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.yellow.opacity(0.9))
                Text(isEscalating ? "STILL CARRYING THIS" : "THIS WEEK")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.yellow.opacity(0.85))
                    .kerning(1.2)

                Spacer()

                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white.opacity(0.45))
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
                .accessibilityLabel("Not now")
            }

            Text(question.replacingOccurrences(of: "\n", with: " "))
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: DS.Spacing.sm) {
                Button(action: onSpeak) {
                    HStack(spacing: 8) {
                        Image(systemName: "mic.fill")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Speak it")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 11)
                    .background(
                        Capsule().fill(
                            LinearGradient(
                                colors: [Color(red: 0.25, green: 0.55, blue: 1.0),
                                         Color(red: 0.40, green: 0.30, blue: 1.0)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    )
                }
                .buttonStyle(PlainButtonStyle())

                Text("Takes 15 seconds")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.5))

                Spacer(minLength: 0)
            }
        }
        .padding(DS.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .dsGlass(cornerRadius: DS.Radius.md)
        .padding(.horizontal, DS.Spacing.md)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : -12)
        .onAppear {
            withAnimation(DS.Motion.smooth) { appeared = true }
        }
    }
}
