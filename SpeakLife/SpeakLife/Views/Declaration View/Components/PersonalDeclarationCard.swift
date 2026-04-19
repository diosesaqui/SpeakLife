//
//  PersonalDeclarationCard.swift
//  SpeakLife
//

import SwiftUI

struct PersonalDeclarationCard: View {
    let declaration: PersonalDeclaration
    let onSpeak: () -> Void
    let onMarkReceived: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {

            // Header row
            HStack(alignment: .center) {
                Label("YOUR PERSONAL DECLARATION", systemImage: "hands.sparkles.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.yellow)

                Spacer()

                Text("Day \(declaration.dayCount)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white.opacity(0.4))
            }

            // Declaration text
            Text(declaration.declarationText)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(.white)
                .lineLimit(4)
                .fixedSize(horizontal: false, vertical: true)

            // Verse reference
            Text("\u{1F4D6} \(declaration.verseReference)")
                .font(.system(size: 12, weight: .regular))
                .foregroundColor(.white.opacity(0.55))

            // Action buttons
            HStack(spacing: 10) {
                Button(action: onSpeak) {
                    HStack(spacing: 6) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 12))
                        Text("Speak It")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.white.opacity(0.12))
                    )
                    .foregroundColor(.white)
                }
                .buttonStyle(PlainButtonStyle())

                Button(action: onMarkReceived) {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12))
                        Text("It Came to Pass")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.green.opacity(0.2))
                    )
                    .foregroundColor(.green)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.07))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.yellow.opacity(0.25), lineWidth: 1)
                )
        )
        .padding(.horizontal, 16)
    }
}
