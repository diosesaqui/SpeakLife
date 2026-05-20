//
//  PremiumAnniversaryView.swift
//  SpeakLife
//
//  One-time delight overlay for premium subscribers at 30/90/365 days.
//

import SwiftUI

enum PremiumAnniversaryMilestone: Int, CaseIterable, Identifiable {
    case day30 = 30
    case day90 = 90
    case day365 = 365

    var id: Int { rawValue }

    /// All milestones smaller-first, for "highest-unshown" selection.
    static var ascending: [PremiumAnniversaryMilestone] { allCases.sorted { $0.rawValue < $1.rawValue } }

    var days: Int { rawValue }

    var headline: String {
        switch self {
        case .day30:  return "30 Days of Standing"
        case .day90:  return "90 Days of Standing"
        case .day365: return "One Year of Standing"
        }
    }

    var subhead: String {
        switch self {
        case .day30:  return "A month of speaking God's Word over your life."
        case .day90:  return "A season of standing on the promises."
        case .day365: return "A year of declaring His Word. You have not grown weary."
        }
    }

    var verseText: String {
        switch self {
        case .day30:
            return "That person is like a tree planted by streams of water, which yields its fruit in season, and whose leaf does not wither."
        case .day90:
            return "Rooted and built up in Him, established in the faith, abounding in thanksgiving."
        case .day365:
            return "Let us not grow weary of doing good, for in due season we will reap, if we do not give up."
        }
    }

    var verseRef: String {
        switch self {
        case .day30:  return "Psalm 1:3"
        case .day90:  return "Colossians 2:7"
        case .day365: return "Galatians 6:9"
        }
    }

    /// UserDefaults key for "this milestone has been shown."
    var shownDefaultsKey: String { "premiumAnniversary_shown_\(rawValue)" }
}

struct PremiumAnniversaryView: View {
    let milestone: PremiumAnniversaryMilestone
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    @Environment(\.dismiss) private var dismiss

    @State private var crownScale: CGFloat = 0.6
    @State private var crownOpacity: Double = 0.0
    @State private var contentOpacity: Double = 0.0

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.ignoresSafeArea()
                Image(subscriptionStore.onboardingBGImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .opacity(0.55)
                    .ignoresSafeArea()
                Color.black.opacity(0.5).ignoresSafeArea()

                VStack(spacing: 28) {
                    Spacer(minLength: 40)

                    Image(systemName: "crown.fill")
                        .font(.system(size: 64, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(hex: "FDE68A"), Color(hex: "FBBF24"), Color(hex: "F59E0B")],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .shadow(color: Color(hex: "FBBF24").opacity(0.55), radius: 22)
                        .scaleEffect(crownScale)
                        .opacity(crownOpacity)

                    VStack(spacing: 10) {
                        Text("\(milestone.days)")
                            .font(Font.custom("AppleSDGothicNeo-Bold", size: 88, relativeTo: .largeTitle))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color(hex: "FDE68A"), Color(hex: "FBBF24")],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                        Text(milestone.headline)
                            .font(Font.custom("AppleSDGothicNeo-Bold", size: 22, relativeTo: .title2))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                        Text(milestone.subhead)
                            .font(Font.custom("AppleSDGothicNeo-Regular", size: 15, relativeTo: .body))
                            .foregroundColor(.white.opacity(0.75))
                            .italic()
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    .opacity(contentOpacity)

                    VStack(spacing: 10) {
                        Text("\u{201C}\(milestone.verseText)\u{201D}")
                            .font(Font.custom("AppleSDGothicNeo-Regular", size: 16, relativeTo: .body))
                            .foregroundColor(.white.opacity(0.92))
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 28)
                        Text(milestone.verseRef)
                            .font(Font.custom("AppleSDGothicNeo-Bold", size: 13, relativeTo: .caption))
                            .tracking(1.0)
                            .foregroundColor(Color(hex: "FBBF24"))
                    }
                    .padding(.vertical, 18)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(Color.white.opacity(0.06))
                            .overlay(
                                RoundedRectangle(cornerRadius: 18)
                                    .strokeBorder(
                                        LinearGradient(
                                            colors: [Color(hex: "FBBF24").opacity(0.55), Color(hex: "F59E0B").opacity(0.2)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1
                                    )
                            )
                    )
                    .padding(.horizontal, 24)
                    .opacity(contentOpacity)

                    Spacer()

                    Button {
                        dismiss()
                    } label: {
                        Text("Keep Standing")
                            .font(Font.custom("AppleSDGothicNeo-Bold", size: 16, relativeTo: .body))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(
                                LinearGradient(
                                    colors: [Color(hex: "F59E0B"), Color(hex: "B45309")],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 28)
                    .opacity(contentOpacity)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear { runEntranceAnimation() }
    }

    private func runEntranceAnimation() {
        withAnimation(.spring(response: 0.7, dampingFraction: 0.55).delay(0.05)) {
            crownScale = 1.0
            crownOpacity = 1.0
        }
        withAnimation(.easeOut(duration: 0.6).delay(0.4)) {
            contentOpacity = 1.0
        }
    }
}
