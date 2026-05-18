//
//  YearInReviewView.swift
//  SpeakLife
//
//  Year-end recap. Everyone with meaningful activity gets the core slides;
//  premium subscribers get an additional Strength Level bonus slide and a
//  Premium Warrior mark on the share card. Surfaced once per year between
//  Dec 15 and Jan 15.
//

import SwiftUI
import UIKit

struct YearInReviewView: View {
    let stats: YearInReviewStats
    /// Snapshotted at construction time. The slide list and summary-card
    /// chrome must not mutate while the recap is on screen — if we read
    /// `subscriptionStore.isPremium` reactively, a late StoreKit hydration
    /// can grow/shrink the slide array under a stale `pageIndex` and warp
    /// the user to a different slide mid-recap.
    let includesPremiumExtras: Bool

    @EnvironmentObject var subscriptionStore: SubscriptionStore
    @Environment(\.dismiss) private var dismiss

    @State private var pageIndex: Int = 0
    @State private var shareItem: ShareItem?

    /// Slide layout is dynamic so the premium-only Strength Level slide can
    /// slot in between "Total Declarations" and "Summary" without breaking
    /// share-button indexing.
    private enum Slide: Hashable {
        case cover, days, longestStreak, bestMonth, totals, strength, summary
    }

    private var slides: [Slide] {
        var s: [Slide] = [.cover, .days, .longestStreak, .bestMonth, .totals]
        if includesPremiumExtras { s.append(.strength) }
        s.append(.summary)
        return s
    }

    private var currentSlide: Slide { slides[safe: pageIndex] ?? .cover }
    private var isFirstSlide: Bool { pageIndex == 0 }
    private var isLastSlide: Bool { pageIndex == slides.count - 1 }

    var body: some View {
        ZStack {
            backgroundLayer

            TabView(selection: $pageIndex) {
                ForEach(Array(slides.enumerated()), id: \.offset) { index, slide in
                    slideView(for: slide).tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .indexViewStyle(.page(backgroundDisplayMode: .never))

            VStack {
                topBar
                Spacer()
                if !isLastSlide {
                    pageDots
                        .padding(.bottom, 28)
                }
            }
        }
        .preferredColorScheme(.dark)
        .sheet(item: $shareItem) { item in
            ShareSheet(activityItems: [item.image, item.text])
        }
    }

    @ViewBuilder
    private func slideView(for slide: Slide) -> some View {
        switch slide {
        case .cover:         coverSlide
        case .days:          daysActiveSlide
        case .longestStreak: longestStreakSlide
        case .bestMonth:     bestMonthSlide
        case .totals:        totalDeclarationsSlide
        case .strength:      strengthLevelSlide
        case .summary:       summarySlide
        }
    }

    // MARK: - Layers

    private var backgroundLayer: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            Image(subscriptionStore.onboardingBGImage)
                .resizable()
                .scaledToFill()
                .opacity(0.45)
                .ignoresSafeArea()
            LinearGradient(
                colors: [Color.black.opacity(0.7), Color.black.opacity(0.4), Color.black.opacity(0.85)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
    }

    private var topBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(Color.white.opacity(0.12)))
            }
            Spacer()
            if !isFirstSlide && !isLastSlide {
                Button {
                    presentShare(of: currentShareableSlide(), text: shareText(for: currentSlide))
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white.opacity(0.8))
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(Color.white.opacity(0.12)))
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }

    private var pageDots: some View {
        HStack(spacing: 6) {
            ForEach(0..<slides.count, id: \.self) { i in
                Capsule()
                    .fill(i == pageIndex ? Color(hex: "FBBF24") : Color.white.opacity(0.25))
                    .frame(width: i == pageIndex ? 18 : 6, height: 6)
                    .animation(.easeInOut(duration: 0.2), value: pageIndex)
            }
        }
    }

    // MARK: - Slides

    private var coverSlide: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "crown.fill")
                .font(.system(size: 56, weight: .semibold))
                .foregroundStyle(goldGradient)
                .shadow(color: Color(hex: "FBBF24").opacity(0.4), radius: 20)
            Text("YOUR YEAR OF STANDING")
                .font(Font.custom("AppleSDGothicNeo-Bold", size: 16, relativeTo: .caption))
                .tracking(3.5)
                .foregroundColor(.white.opacity(0.75))
            Text(String(stats.year))
                .font(Font.custom("AppleSDGothicNeo-Bold", size: 110, relativeTo: .largeTitle))
                .foregroundStyle(goldGradient)
            Text("A look at how you stood this year.")
                .font(Font.custom("AppleSDGothicNeo-Regular", size: 16, relativeTo: .body))
                .foregroundColor(.white.opacity(0.7))
                .italic()
                .multilineTextAlignment(.center)
            Spacer()
            advanceHint("Swipe to begin")
        }
        .padding(.horizontal, 28)
    }

    private var daysActiveSlide: some View {
        slideShell {
            slideStat(
                eyebrow: "You showed up",
                number: "\(stats.daysActive)",
                unit: stats.daysActive == 1 ? "day" : "days",
                accent: "\(stats.percentOfYear)% of \(stats.year)",
                verse: "She is like a tree planted by streams of water, which yields its fruit in season.",
                verseRef: "Psalm 1:3"
            )
        }
    }

    private var longestStreakSlide: some View {
        slideShell {
            slideStat(
                eyebrow: "Your longest unbroken stand",
                number: "\(stats.longestStreakInYear)",
                unit: stats.longestStreakInYear == 1 ? "day in a row" : "days in a row",
                accent: stats.longestStreakInYear >= 7
                    ? "You did not grow weary."
                    : "Every stand counts.",
                verse: "Stand firm. And after you have done everything, stand.",
                verseRef: "Ephesians 6:13"
            )
        }
    }

    private var bestMonthSlide: some View {
        slideShell {
            if let best = stats.bestMonth {
                VStack(spacing: 20) {
                    eyebrow("Your strongest month")
                    Text(best.name)
                        .font(Font.custom("AppleSDGothicNeo-Bold", size: 64, relativeTo: .largeTitle))
                        .foregroundStyle(goldGradient)
                        .multilineTextAlignment(.center)
                    Text("\(best.count) day\(best.count == 1 ? "" : "s") on the wall")
                        .font(Font.custom("AppleSDGothicNeo-Regular", size: 17, relativeTo: .body))
                        .foregroundColor(.white.opacity(0.85))
                    Text("You stood when it mattered.")
                        .font(Font.custom("AppleSDGothicNeo-Regular", size: 14, relativeTo: .caption))
                        .foregroundColor(.white.opacity(0.6))
                        .italic()
                }
            } else {
                slideStat(
                    eyebrow: "Your strongest month",
                    number: "—",
                    unit: "",
                    accent: "The year is just beginning.",
                    verse: nil,
                    verseRef: nil
                )
            }
        }
    }

    private var totalDeclarationsSlide: some View {
        slideShell {
            slideStat(
                eyebrow: "You spoke God's Word",
                number: "\(stats.totalDeclarationsSpoken)",
                unit: stats.totalDeclarationsSpoken == 1 ? "time" : "times",
                accent: "Every word a stone of remembrance.",
                verse: "The word of God is alive and active.",
                verseRef: "Hebrews 4:12"
            )
        }
    }

    /// Premium-only bonus slide. Surfaces the highest spiritual-strength tier
    /// the user reached during the year, using the level system that already
    /// powers the BurstCompletionTracker UI.
    private var strengthLevelSlide: some View {
        slideShell {
            VStack(spacing: 18) {
                HStack(spacing: 6) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 11, weight: .semibold))
                    Text("FOR YOU \u{2022} PREMIUM")
                        .font(Font.custom("AppleSDGothicNeo-Bold", size: 11, relativeTo: .caption2))
                        .tracking(2.0)
                }
                .foregroundColor(Color(hex: "FBBF24"))

                eyebrow("Strength reached this year")

                Image(systemName: stats.peakStrengthLevel.icon)
                    .font(.system(size: 76, weight: .semibold))
                    .foregroundStyle(goldGradient)
                    .shadow(color: Color(hex: "FBBF24").opacity(0.4), radius: 18)
                    .padding(.vertical, 4)

                Text(stats.peakStrengthLevel.rawValue.uppercased())
                    .font(Font.custom("AppleSDGothicNeo-Bold", size: 38, relativeTo: .largeTitle))
                    .foregroundStyle(goldGradient)
                    .tracking(2.0)

                Text("Peak score \(stats.peakStrengthScore) of 100")
                    .font(Font.custom("AppleSDGothicNeo-Regular", size: 14, relativeTo: .caption))
                    .foregroundColor(.white.opacity(0.6))

                Text(strengthLevelBlessing(stats.peakStrengthLevel))
                    .font(Font.custom("AppleSDGothicNeo-Regular", size: 14, relativeTo: .caption))
                    .foregroundColor(.white.opacity(0.75))
                    .italic()
                    .multilineTextAlignment(.center)
                    .padding(.top, 6)
                    .padding(.horizontal, 12)
            }
        }
    }

    private func strengthLevelBlessing(_ level: BurstCompletionTracker.StrengthLevel) -> String {
        switch level {
        case .warrior:     return "You took up the shield. The fight has only begun."
        case .champion:    return "You did not retreat. The medal is earned."
        case .conqueror:   return "Crown set, ground taken. The land is yours."
        case .victorious:  return "You walked through fire and came out shining."
        case .unstoppable: return "What can stand against you? Nothing in His name."
        }
    }

    private var summarySlide: some View {
        // Width-propagation from parent containers wasn't working — the
        // card's .frame(maxWidth: .infinity) kept escaping. Apply an
        // explicit width to the card and button column based on the page
        // bounds, then center both in a ZStack pinned to the page.
        GeometryReader { geo in
            let contentWidth = max(0, geo.size.width - 48)
            ZStack {
                Color.clear
                VStack(spacing: 0) {
                    Spacer(minLength: 20)
                    summaryCard
                        .frame(width: contentWidth)
                    Spacer()
                    VStack(spacing: 10) {
                        Button {
                            presentShare(of: summaryCardForExport(), text: shareSummaryText)
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "square.and.arrow.up")
                                Text("Share Your Year")
                            }
                            .font(Font.custom("AppleSDGothicNeo-Bold", size: 16, relativeTo: .body))
                            .foregroundColor(.white)
                            .frame(width: contentWidth, height: 52)
                            .background(
                                LinearGradient(colors: [Color(hex: "F59E0B"), Color(hex: "B45309")],
                                               startPoint: .leading, endPoint: .trailing)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        Button {
                            dismiss()
                        } label: {
                            Text("Done")
                                .font(Font.custom("AppleSDGothicNeo-Regular", size: 15, relativeTo: .body))
                                .foregroundColor(.white.opacity(0.55))
                                .frame(width: contentWidth, height: 44)
                        }
                    }
                    .padding(.bottom, 28)
                }
                .padding(.top, 60) // clear the topBar's close button
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }

    // MARK: - Reusable bits

    @ViewBuilder
    private func slideShell<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack {
            Spacer()
            content()
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
        }
    }

    private func eyebrow(_ text: String) -> some View {
        Text(text.uppercased())
            .font(Font.custom("AppleSDGothicNeo-Bold", size: 13, relativeTo: .caption))
            .tracking(2.5)
            .foregroundColor(.white.opacity(0.65))
    }

    @ViewBuilder
    private func slideStat(eyebrow eyebrowText: String,
                           number: String,
                           unit: String,
                           accent: String,
                           verse: String?,
                           verseRef: String?) -> some View {
        VStack(spacing: 14) {
            eyebrow(eyebrowText)
            Text(number)
                .font(Font.custom("AppleSDGothicNeo-Bold", size: 120, relativeTo: .largeTitle))
                .foregroundStyle(goldGradient)
                .minimumScaleFactor(0.4)
                .lineLimit(1)
            if !unit.isEmpty {
                Text(unit)
                    .font(Font.custom("AppleSDGothicNeo-Regular", size: 19, relativeTo: .title3))
                    .foregroundColor(.white.opacity(0.85))
            }
            Text(accent)
                .font(Font.custom("AppleSDGothicNeo-Regular", size: 14, relativeTo: .caption))
                .foregroundColor(.white.opacity(0.65))
                .italic()
                .padding(.top, 4)

            if let verse, let verseRef {
                VStack(spacing: 6) {
                    Text("\u{201C}\(verse)\u{201D}")
                        .font(Font.custom("AppleSDGothicNeo-Regular", size: 14, relativeTo: .caption))
                        .foregroundColor(.white.opacity(0.78))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(verseRef)
                        .font(Font.custom("AppleSDGothicNeo-Bold", size: 11, relativeTo: .caption2))
                        .tracking(1.0)
                        .foregroundColor(Color(hex: "FBBF24"))
                }
                .padding(.top, 26)
                .padding(.horizontal, 12)
            }
        }
    }

    private func advanceHint(_ text: String) -> some View {
        HStack(spacing: 6) {
            Text(text)
                .font(Font.custom("AppleSDGothicNeo-Regular", size: 13, relativeTo: .caption))
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
        }
        .foregroundColor(.white.opacity(0.55))
        .padding(.bottom, 36)
    }

    private var goldGradient: LinearGradient {
        LinearGradient(
            colors: [Color(hex: "FDE68A"), Color(hex: "FBBF24"), Color(hex: "F59E0B")],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // MARK: - Summary card (also the shareable composite)

    private var summaryCard: some View {
        VStack(spacing: 18) {
            VStack(spacing: 6) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(goldGradient)
                Text("YOUR YEAR OF STANDING")
                    .font(Font.custom("AppleSDGothicNeo-Bold", size: 12, relativeTo: .caption))
                    .tracking(3.0)
                    .foregroundColor(.white.opacity(0.7))
                Text(String(stats.year))
                    .font(Font.custom("AppleSDGothicNeo-Bold", size: 56, relativeTo: .largeTitle))
                    .foregroundStyle(goldGradient)
            }
            .padding(.top, 8)

            Divider().background(Color.white.opacity(0.15)).padding(.horizontal, 24)

            VStack(spacing: 14) {
                summaryRow(label: "Days you stood",        value: "\(stats.daysActive)")
                summaryRow(label: "Longest unbroken run",  value: "\(stats.longestStreakInYear) days")
                if let best = stats.bestMonth {
                    summaryRow(label: "Strongest month",   value: best.name)
                }
                summaryRow(label: "Words declared",        value: "\(stats.totalDeclarationsSpoken)")
                if includesPremiumExtras {
                    summaryRow(label: "Strength reached",  value: stats.peakStrengthLevel.rawValue)
                }
            }
            .padding(.horizontal, 22)

            if includesPremiumExtras {
                HStack(spacing: 5) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 10, weight: .semibold))
                    Text("PREMIUM WARRIOR")
                        .font(Font.custom("AppleSDGothicNeo-Bold", size: 10, relativeTo: .caption2))
                        .tracking(2.0)
                }
                .foregroundColor(Color(hex: "FBBF24"))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(Color(hex: "FBBF24").opacity(0.14))
                        .overlay(Capsule().stroke(Color(hex: "FBBF24").opacity(0.45), lineWidth: 0.5))
                )
                .padding(.top, 8)
            }

            Text("SpeakLife")
                .font(Font.custom("AppleSDGothicNeo-Bold", size: 11, relativeTo: .caption2))
                .tracking(2.5)
                .foregroundColor(.white.opacity(0.45))
                .padding(.top, 6)
                .padding(.bottom, 10)
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
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
    }

    private func summaryRow(label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(Font.custom("AppleSDGothicNeo-Regular", size: 14, relativeTo: .body))
                .foregroundColor(.white.opacity(0.7))
            Spacer()
            Text(value)
                .font(Font.custom("AppleSDGothicNeo-Bold", size: 17, relativeTo: .body))
                .foregroundColor(.white)
        }
    }

    // MARK: - Sharing

    /// The per-slide visual we render for share. Same content as the slide,
    /// inside a fixed-width card with a solid background so it looks good
    /// pasted into Stories / iMessage where the wall background isn't there.
    @ViewBuilder
    private func currentShareableSlide() -> some View {
        ShareCardWrapper {
            switch currentSlide {
            case .days: slideStat(
                eyebrow: "Days I stood in \(stats.year)",
                number: "\(stats.daysActive)",
                unit: stats.daysActive == 1 ? "day" : "days",
                accent: "\(stats.percentOfYear)% of the year",
                verse: nil, verseRef: nil
            )
            case .longestStreak: slideStat(
                eyebrow: "My longest stand in \(stats.year)",
                number: "\(stats.longestStreakInYear)",
                unit: stats.longestStreakInYear == 1 ? "day in a row" : "days in a row",
                accent: "I did not grow weary.",
                verse: nil, verseRef: nil
            )
            case .bestMonth:
                if let best = stats.bestMonth {
                    VStack(spacing: 12) {
                        eyebrow("My strongest month in \(stats.year)")
                        Text(best.name)
                            .font(Font.custom("AppleSDGothicNeo-Bold", size: 54, relativeTo: .largeTitle))
                            .foregroundStyle(goldGradient)
                        Text("\(best.count) day\(best.count == 1 ? "" : "s") on the wall")
                            .font(Font.custom("AppleSDGothicNeo-Regular", size: 16, relativeTo: .body))
                            .foregroundColor(.white.opacity(0.85))
                    }
                } else {
                    EmptyView()
                }
            case .totals: slideStat(
                eyebrow: "Words I declared in \(stats.year)",
                number: "\(stats.totalDeclarationsSpoken)",
                unit: stats.totalDeclarationsSpoken == 1 ? "time" : "times",
                accent: "Every word a stone of remembrance.",
                verse: nil, verseRef: nil
            )
            case .strength:
                VStack(spacing: 14) {
                    eyebrow("My strength reached in \(stats.year)")
                    Image(systemName: stats.peakStrengthLevel.icon)
                        .font(.system(size: 70, weight: .semibold))
                        .foregroundStyle(goldGradient)
                    Text(stats.peakStrengthLevel.rawValue.uppercased())
                        .font(Font.custom("AppleSDGothicNeo-Bold", size: 40, relativeTo: .largeTitle))
                        .foregroundStyle(goldGradient)
                        .tracking(2.0)
                }
            case .cover, .summary: EmptyView()
            }
        }
    }

    @ViewBuilder
    private func summaryCardForExport() -> some View {
        ShareCardWrapper {
            summaryCard
                .padding(.horizontal, 0)
        }
    }

    private func shareText(for slide: Slide) -> String {
        switch slide {
        case .days:          return "I stood in God's Word \(stats.daysActive) days this year. #SpeakLife"
        case .longestStreak: return "My longest unbroken stand in \(stats.year): \(stats.longestStreakInYear) days. #SpeakLife"
        case .bestMonth:
            if let best = stats.bestMonth { return "\(best.name) was my strongest month in \(stats.year). #SpeakLife" }
            return "My year of standing. #SpeakLife"
        case .totals:        return "I spoke God's Word \(stats.totalDeclarationsSpoken) times this year. #SpeakLife"
        case .strength:      return "I reached \(stats.peakStrengthLevel.rawValue) in \(stats.year). #SpeakLife"
        case .cover, .summary: return "My year of standing. #SpeakLife"
        }
    }

    private var shareSummaryText: String {
        let base = "My Year of Standing — \(stats.year). \(stats.daysActive) days, longest run \(stats.longestStreakInYear), \(stats.totalDeclarationsSpoken) declarations."
        if includesPremiumExtras {
            return "\(base) Strength reached: \(stats.peakStrengthLevel.rawValue). #SpeakLife"
        }
        return "\(base) #SpeakLife"
    }

    @MainActor
    private func presentShare<V: View>(of view: V, text: String) {
        let renderer = ImageRenderer(content: view)
        renderer.scale = UIScreen.main.scale
        renderer.proposedSize = ProposedViewSize(width: 1080, height: 1920)
        guard let image = renderer.uiImage else { return }
        shareItem = ShareItem(image: image, text: text)
    }
}

// MARK: - Share helpers

private struct ShareItem: Identifiable {
    let id = UUID()
    let image: UIImage
    let text: String
}

/// Fixed-frame, dark-background wrapper used when rendering a slide to image.
/// Forces a portrait 9:16 aspect so the result looks right pasted into Stories.
private struct ShareCardWrapper<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "0B0B14"), Color(hex: "1A1330"), Color(hex: "0B0B14")],
                startPoint: .top,
                endPoint: .bottom
            )
            VStack {
                Spacer()
                content
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                Spacer()
                HStack(spacing: 6) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 10, weight: .semibold))
                    Text("SPEAKLIFE")
                        .font(Font.custom("AppleSDGothicNeo-Bold", size: 11, relativeTo: .caption2))
                        .tracking(2.5)
                }
                .foregroundColor(Color(hex: "FBBF24"))
                .padding(.bottom, 56)
            }
        }
        .frame(width: 1080, height: 1920)
    }
}

