//
//  BottomSheet.swift
//  SpeakLife
//
//  Created by Riccardo Washington on 3/16/24.
//

import SwiftUI

struct StreakInfoSection: View {
    let viewModel: StreakViewModel

    var body: some View {
        VStack(spacing: 12) {
            StreakRow(title: "Current streak", value: viewModel.titleText, icon: "flame", iconColor: .orange)
            StreakRow(title: "Longest streak", value: viewModel.subTitleText, icon: "bolt.fill", iconColor: Constants.traditionalGold)
            StreakRow(title: "Total Days Speaking Life", value: viewModel.subTitleDetailText, icon: "star.fill", iconColor: Constants.traditionalGold)
        }
        .padding(.horizontal)
    }
}

struct PrimaryActionButton: View {
    var title: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 18, weight: .medium, design: .rounded))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.white.opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }
}


struct StreakRow: View {
    let title: String
    let value: String
    let icon: String
    let iconColor: Color

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 18, weight: .medium, design: .rounded))
                .foregroundColor(.white)
            Spacer()
            HStack(spacing: 6) {
                Text(value)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(.white)
                Image(systemName: icon)
                    .resizable()
                    .scaledToFit()
                    .foregroundColor(iconColor)
                    .frame(width: 18, height: 18)
            }
        }
        .foregroundColor(.white)
    }
}


struct StreakInfoBottomSheet: View {
    @EnvironmentObject var streakViewModel: StreakViewModel
    @Binding var isShown: Bool

    var body: some View {
        VStack(spacing: 12) {
            HandleBar()
                .padding(.top, 10)

            Text("Speak Life Daily")
                .font(.system(size: 24, weight: .semibold, design: .rounded))
                .foregroundColor(.white)

            Text("Practice God’s presence and speak His Word—He promised to never leave you. Let your attitude, mindset, and perspective be shaped by this truth: God is in you, with you, and for you 🙌")
                .foregroundColor(.white.opacity(0.85))
                .font(.system(size: 16, weight: .regular, design: .rounded))
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Spacer()
            
            StreakInfoSection(viewModel: streakViewModel)

            Spacer()

            PrimaryActionButton(title: "Got it!") {
                isShown = false
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            }
            .padding(.horizontal)
            .padding(.bottom, 16)
        }
        .padding(.top, 10)
        .background(
            Gradients().speakLifeCYOCell
                .ignoresSafeArea()
        )
        .transition(.move(edge: .bottom).combined(with: .opacity)) // 💥 transition
        .animation(.easeOut(duration: 0.4), value: isShown) 
    }
}
