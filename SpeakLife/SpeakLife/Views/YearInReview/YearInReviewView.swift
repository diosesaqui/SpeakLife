//
//  YearInReviewView.swift
//  SpeakLife
//
//  Year-end recap. Everyone with activity gets the core slides; premium
//  subscribers also get a Strength Level bonus slide and a Premium Warrior
//  mark on their share cards. Open from Dec 1 to Jan 15 (see
//  `YearInReviewStats.recapYear`), reached from the launch takeover, the
//  Today card, Profile, or the December push (`YearInReviewCoordinator`).
//
//  Every slide after the cover can be posted. The card that leaves is a
//  1080x1920 story image (`YearInReviewShareCard`), and the in-app slides use
//  the same background and gold so what people see is what they share.
//

import SwiftUI
import UIKit

struct YearInReviewView: View {
    let stats: YearInReviewStats
    /// Snapshotted at construction time. The slide list and card chrome must
    /// not change while the recap is on screen: if we read
    /// `subscriptionStore.isPremium` reactively, a late StoreKit hydration
    /// could grow or shrink the slide array under a stale `pageIndex`.
    let includesPremiumExtras: Bool
    var source: YearInReviewSource = .auto

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var pageIndex = 0
    @State private var shareItem: ShareItem?
    /// Slides whose hero has already counted up in this showing.
    @State private var revealed: Set<YearInReviewSlide> = []
    /// Slides already reported to analytics, so swiping back and forth does
    /// not inflate `year_in_review_slide_viewed`.
    @State private var viewedSlides: Set<YearInReviewSlide> = []
    @State private var didAppear = false

    private var slides: [YearInReviewSlide] {
        stats.slides(includesPremiumExtras: includesPremiumExtras)
    }

    private var currentSlide: YearInReviewSlide { slides[safe: pageIndex] ?? .cover }

    var body: some View {
        ZStack {
            GeometryReader { geo in
                YearInReviewBackground(size: geo.size)
            }
            .ignoresSafeArea()

            TabView(selection: $pageIndex) {
                ForEach(Array(slides.enumerated()), id: \.offset) { index, slide in
                    page(for: slide)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            VStack(spacing: 0) {
                topBar
                Spacer(minLength: 0)
                bottomBar
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.bottom, DS.Spacing.md)
            }
        }
        .preferredColorScheme(.dark)
        .sheet(item: $shareItem) { item in
            ShareSheet(activityItems: [item.image, item.text])
        }
        .onAppear {
            guard !didAppear else { return }
            didAppear = true
            // Marked here, once it is really on screen, so a presentation
            // that was blocked never burns the year's auto-launch.
            YearInReviewCoordinator.markSeen(year: stats.year)
            AnalyticsService.shared.track("year_in_review_opened", parameters: [
                "source": source.rawValue,
                "year": stats.year,
                "in_progress": stats.isInProgress,
                "days_active": stats.daysActive,
                "is_premium": includesPremiumExtras,
                "slide_count": slides.count
            ])
            slideDidAppear(at: pageIndex)
        }
        .onChange(of: pageIndex) { _, newIndex in
            slideDidAppear(at: newIndex)
        }
    }

    // MARK: - Slide lifecycle

    private func slideDidAppear(at index: Int) {
        guard let slide = slides[safe: index] else { return }

        if viewedSlides.insert(slide).inserted {
            AnalyticsService.shared.track("year_in_review_slide_viewed", parameters: [
                "slide": slide.rawValue,
                "index": index,
                "year": stats.year
            ])
        }

        guard !revealed.contains(slide) else {
            Juice.play(.tapLight)
            return
        }
        if reduceMotion {
            revealed.insert(slide)
        } else {
            withAnimation(.easeOut(duration: 1.3)) {
                _ = revealed.insert(slide)
            }
        }
        // A soft success as the number lands, the first time each slide shows.
        if slide != .cover {
            DispatchQueue.main.asyncAfter(deadline: .now() + (reduceMotion ? 0.05 : 1.0)) {
                Juice.play(.success)
            }
        }
    }

    private func advance() {
        guard pageIndex < slides.count - 1 else { return }
        withAnimation(DS.Motion.smooth) { pageIndex += 1 }
    }

    // MARK: - Chrome

    private var topBar: some View {
        VStack(spacing: DS.Spacing.sm) {
            HStack(spacing: 4) {
                ForEach(slides.indices, id: \.self) { i in
                    Capsule()
                        .fill(i <= pageIndex ? YearInReviewPalette.label : Color.white.opacity(0.22))
                        .frame(height: 3)
                }
            }
            .animation(DS.Motion.smooth, value: pageIndex)
            .accessibilityHidden(true)

            HStack {
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white.opacity(0.8))
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(Color.white.opacity(0.12)))
                }
                .buttonStyle(.dsPressable(feel: .tapLight))
                .accessibilityLabel("Close")
            }
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.top, DS.Spacing.xs)
    }

    @ViewBuilder
    private var bottomBar: some View {
        switch currentSlide {
        case .cover:
            Button(action: advance) {
                HStack(spacing: DS.Spacing.xs) {
                    Text(stats.isInProgress ? "See my year so far" : "See my year")
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .bold))
                }
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(Color(red: 0.14, green: 0.09, blue: 0.02))
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(Capsule().fill(YearInReviewPalette.heroGold))
                .shadow(color: YearInReviewPalette.glow.opacity(0.35), radius: 16, y: 6)
            }
            .buttonStyle(.dsPressable(feel: .tapSolid))
        case .nextYear:
            VStack(spacing: DS.Spacing.xs) {
                shareRow(for: .nextYear)
                Button {
                    dismiss()
                } label: {
                    Text("Done")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.65))
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                }
                .buttonStyle(.dsPressable(feel: .tapLight))
            }
        default:
            shareRow(for: currentSlide)
        }
    }

    /// Instagram Stories first (the post people make in December), then the
    /// system share sheet for everything else.
    private func shareRow(for slide: YearInReviewSlide) -> some View {
        HStack(spacing: DS.Spacing.sm) {
            Button {
                share(slide, method: .instagramStories)
            } label: {
                HStack(spacing: DS.Spacing.xs) {
                    Image(systemName: "camera.fill")
                    Text("Share to Stories")
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Color(red: 0.14, green: 0.09, blue: 0.02))
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(Capsule().fill(YearInReviewPalette.heroGold))
                .shadow(color: YearInReviewPalette.glow.opacity(0.35), radius: 16, y: 6)
            }
            .buttonStyle(.dsPressable(feel: .tapSolid))
            .accessibilityLabel("Share to Instagram Stories")

            Button {
                share(slide, method: .shareSheet)
            } label: {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 54, height: 54)
                    .background(Circle().fill(Color.white.opacity(0.14)))
                    .overlay(Circle().strokeBorder(Color.white.opacity(0.22), lineWidth: 1))
            }
            .buttonStyle(.dsPressable(feel: .tapSolid))
            .accessibilityLabel("More ways to share")
        }
    }

    // MARK: - Pages

    @ViewBuilder
    private func page(for slide: YearInReviewSlide) -> some View {
        switch slide {
        case .cover:   coverPage
        case .summary: summaryPage
        default:       statPage(slide)
        }
    }

    private var coverPage: some View {
        ZStack {
            GoldDust(animate: !reduceMotion)

            VStack(spacing: DS.Spacing.md) {
                Spacer()
                Image(systemName: "crown.fill")
                    .font(.system(size: 50, weight: .semibold))
                    .foregroundStyle(YearInReviewPalette.heroGold)
                    .shadow(color: YearInReviewPalette.glow.opacity(0.5), radius: 22)

                SlideEyebrow(text: "Your year of standing")

                VStack(spacing: 0) {
                    Text(String(stats.year))
                        .font(.system(size: 112, weight: .semibold, design: .serif))
                        .foregroundStyle(YearInReviewPalette.heroGold)
                        .shadow(color: YearInReviewPalette.glow.opacity(0.4), radius: 24)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    if stats.isInProgress {
                        Text("so far")
                            .font(.system(size: 26, weight: .regular, design: .serif).italic())
                            .foregroundStyle(YearInReviewPalette.label)
                    }
                }

                Text(coverLine)
                    .font(.system(size: 19, weight: .regular, design: .serif))
                    .foregroundColor(.white.opacity(0.82))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, DS.Spacing.xs)
                Spacer()
                Spacer().frame(height: 110)
            }
            .padding(.horizontal, DS.Spacing.xl)
        }
    }

    private var coverLine: String {
        if stats.daysActive < YearInReviewEligibility.autoLaunchMinimumDays {
            return "Every day you showed up counts. Here it is."
        }
        return stats.isInProgress
            ? "Every day you showed up mattered. Here is your year so far."
            : "Every day you showed up mattered. Here is your \(String(stats.year))."
    }

    private func statPage(_ slide: YearInReviewSlide) -> some View {
        let content = inAppContent(for: slide)
        let isRevealed = revealed.contains(slide) || reduceMotion

        return VStack(spacing: 0) {
            Spacer(minLength: 0)

            if slide == .strength {
                premiumBadge
                    .padding(.bottom, DS.Spacing.md)
            }

            SlideEyebrow(text: content.eyebrow)

            if let symbol = content.symbol {
                Image(systemName: symbol)
                    .font(.system(size: 64, weight: .semibold))
                    .foregroundStyle(YearInReviewPalette.heroGold)
                    .shadow(color: YearInReviewPalette.glow.opacity(0.45), radius: 20)
                    .padding(.top, DS.Spacing.lg)
                    .scaleEffect(isRevealed ? 1 : 0.85)
            }

            hero(for: slide, content: content, isRevealed: isRevealed)
                .padding(.top, content.heroStyle == .declaration ? DS.Spacing.lg : DS.Spacing.sm)

            Group {
                if let caption = content.caption {
                    Text(caption)
                        .font(.system(size: 21, weight: .medium, design: .serif))
                        .foregroundColor(.white)
                        .padding(.top, 6)
                }
                if let detail = content.detail {
                    Text(detail)
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(.white.opacity(0.68))
                        .padding(.top, DS.Spacing.sm)
                }
                if let verse = content.verse {
                    Capsule()
                        .fill(YearInReviewPalette.label)
                        .frame(width: 40, height: 2)
                        .padding(.top, DS.Spacing.xl)
                        .padding(.bottom, DS.Spacing.md)
                    Text(verse)
                        .font(.system(size: 16, weight: .regular, design: .serif).italic())
                        .foregroundColor(.white.opacity(0.8))
                        .lineSpacing(3)
                    if let reference = content.reference {
                        Text(reference.uppercased())
                            .font(.system(size: 11, weight: .semibold))
                            .tracking(3)
                            .foregroundColor(YearInReviewPalette.label)
                            .padding(.top, DS.Spacing.xs)
                    }
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            .opacity(isRevealed ? 1 : 0)
            .offset(y: isRevealed ? 0 : 12)

            Spacer(minLength: 0)
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, DS.Spacing.xl)
        .padding(.top, 70)
        .padding(.bottom, 120)
    }

    @ViewBuilder
    private func hero(for slide: YearInReviewSlide, content: YearInReviewCardContent,
                      isRevealed: Bool) -> some View {
        switch content.heroStyle {
        case .number:
            // Counts up from zero the first time the slide lands. The share
            // card is rendered from `cardContent`, never from this, so the
            // posted image always carries the final number.
            Text(verbatim: "")
                .modifier(CountUp(value: isRevealed ? Double(heroNumber(for: slide)) : 0))
                .font(.system(size: 116, weight: .semibold, design: .serif).monospacedDigit())
                .foregroundStyle(YearInReviewPalette.heroGold)
                .shadow(color: YearInReviewPalette.glow.opacity(0.4), radius: 24)
                .lineLimit(1)
                .minimumScaleFactor(0.35)
        case .word:
            Text(content.hero)
                .font(.system(size: 58, weight: .semibold, design: .serif))
                .foregroundStyle(YearInReviewPalette.heroGold)
                .shadow(color: YearInReviewPalette.glow.opacity(0.4), radius: 20)
                .lineLimit(1)
                .minimumScaleFactor(0.45)
                .opacity(isRevealed ? 1 : 0)
                .scaleEffect(isRevealed ? 1 : 0.92)
        case .declaration:
            Text(content.hero)
                .font(.system(size: 31, weight: .medium, design: .serif))
                .foregroundColor(.white)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
                .opacity(isRevealed ? 1 : 0)
                .scaleEffect(isRevealed ? 1 : 0.96)
        }
    }

    private var premiumBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: "crown.fill")
                .font(.system(size: 10, weight: .semibold))
            Text("PREMIUM BONUS")
                .font(.system(size: 10, weight: .semibold))
                .tracking(2)
        }
        .foregroundColor(YearInReviewPalette.label)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(YearInReviewPalette.glow.opacity(0.14))
                .overlay(Capsule().strokeBorder(YearInReviewPalette.label.opacity(0.45), lineWidth: 0.5))
        )
    }

    /// The summary shows the exact card that will be posted, scaled to fit.
    private var summaryPage: some View {
        GeometryReader { geo in
            let cardSize = YearInReviewShareCard.size
            let availableWidth = max(1, geo.size.width - 2 * DS.Spacing.xl)
            let availableHeight = max(1, geo.size.height - 80 - 150)
            let scale = min(availableWidth / cardSize.width, availableHeight / cardSize.height)

            VStack(spacing: DS.Spacing.sm) {
                Spacer(minLength: 80)
                SlideEyebrow(text: "Your year on one card")
                YearInReviewSummaryCard(stats: stats, isPremium: includesPremiumExtras)
                    .frame(width: cardSize.width, height: cardSize.height)
                    .scaleEffect(scale)
                    .frame(width: cardSize.width * scale, height: cardSize.height * scale)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                            .strokeBorder(YearInReviewPalette.label.opacity(0.35), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.5), radius: 24, y: 12)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(stats.shareWords(for: .summary))
                Spacer(minLength: 130)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }

    // MARK: - Content

    private func heroNumber(for slide: YearInReviewSlide) -> Int {
        switch slide {
        case .days:          return stats.daysActive
        case .longestStreak: return stats.longestStreakInYear
        case .totals:        return stats.totalDeclarationsSpoken
        default:             return 0
        }
    }

    private func count(_ value: Int) -> String {
        YearInReviewStats.formattedCount(value)
    }

    /// The in-app slide, spoken to the user.
    private func inAppContent(for slide: YearInReviewSlide) -> YearInReviewCardContent {
        let year = String(stats.year)
        switch slide {
        case .longestStreak:
            let run = stats.longestStreakInYear
            return YearInReviewCardContent(
                eyebrow: "Your longest run",
                hero: count(run),
                caption: run == 1 ? "day standing strong" : "days in a row",
                detail: run >= 7 ? "You did not give up." : "Every day you stood mattered.",
                verse: "Let us not become weary in doing good, for at the proper time we will reap a harvest if we do not give up.",
                reference: "Galatians 6:9"
            )
        case .bestMonth:
            guard let best = stats.bestMonth else { return inAppContent(for: .days) }
            return YearInReviewCardContent(
                eyebrow: "Your strongest month",
                hero: best.name,
                heroStyle: .word,
                caption: best.count == 1 ? "1 day in God's Word" : "\(count(best.count)) days in God's Word",
                verse: "His compassions never fail. They are new every morning; great is your faithfulness.",
                reference: "Lamentations 3:22-23"
            )
        case .totals:
            let total = stats.totalDeclarationsSpoken
            return YearInReviewCardContent(
                eyebrow: "Spoken in your Daily Burst",
                hero: count(total),
                caption: total == 1 ? "declaration" : "declarations",
                detail: "Not one of them came back empty.",
                verse: "So is my word that goes out from my mouth: It will not return to me empty.",
                reference: "Isaiah 55:11"
            )
        case .strength:
            return YearInReviewCardContent(
                eyebrow: "Strength you reached",
                symbol: stats.peakStrengthLevel.icon,
                hero: stats.peakStrengthLevel.rawValue.uppercased(),
                heroStyle: .word,
                caption: "Peak score \(stats.peakStrengthScore) of 100",
                detail: strengthBlessing(stats.peakStrengthLevel)
            )
        case .nextYear:
            return YearInReviewCardContent(
                eyebrow: "Speak it over \(String(stats.nextYear))",
                hero: stats.nextYearDeclaration,
                heroStyle: .declaration,
                detail: "Say it out loud.",
                verse: "See, I am doing a new thing! Now it springs up.",
                reference: "Isaiah 43:19"
            )
        case .days, .cover, .summary:
            let days = stats.daysActive
            let percent = stats.percentOfYear
            let detail: String
            if percent >= 1 {
                detail = stats.isInProgress
                    ? "That is \(percent)% of the year so far."
                    : "That is \(percent)% of \(year)."
            } else {
                detail = "Every one of them mattered."
            }
            return YearInReviewCardContent(
                eyebrow: "You showed up",
                hero: count(days),
                caption: days == 1 ? "day in God's Word" : "days in God's Word",
                detail: detail,
                verse: "That person is like a tree planted by streams of water, which yields its fruit in season.",
                reference: "Psalm 1:3"
            )
        }
    }

    /// The posted card, in the sharer's own voice.
    private func cardContent(for slide: YearInReviewSlide) -> YearInReviewCardContent {
        let eyebrow = stats.isInProgress
            ? "MY \(String(stats.year)) SO FAR"
            : "MY \(String(stats.year)) IN SPEAKLIFE"
        switch slide {
        case .longestStreak:
            let run = stats.longestStreakInYear
            return YearInReviewCardContent(
                eyebrow: eyebrow,
                hero: count(run),
                caption: run == 1 ? "day standing on God's Word" : "days in a row standing on God's Word",
                verse: "At the proper time we will reap a harvest if we do not give up.",
                reference: "Galatians 6:9"
            )
        case .bestMonth:
            guard let best = stats.bestMonth else { return cardContent(for: .days) }
            return YearInReviewCardContent(
                eyebrow: eyebrow,
                hero: best.name,
                heroStyle: .word,
                caption: "was my strongest month in God's Word",
                verse: "His compassions never fail. They are new every morning.",
                reference: "Lamentations 3:22-23"
            )
        case .totals:
            let total = stats.totalDeclarationsSpoken
            return YearInReviewCardContent(
                eyebrow: eyebrow,
                hero: count(total),
                caption: total == 1 ? "declaration I spoke in my Daily Burst" : "declarations I spoke in my Daily Burst",
                verse: "So is my word that goes out from my mouth: It will not return to me empty.",
                reference: "Isaiah 55:11"
            )
        case .strength:
            return YearInReviewCardContent(
                eyebrow: eyebrow,
                symbol: stats.peakStrengthLevel.icon,
                hero: stats.peakStrengthLevel.rawValue.uppercased(),
                heroStyle: .word,
                caption: "the strength I grew to in God's Word",
                verse: "I can do all this through him who gives me strength.",
                reference: "Philippians 4:13"
            )
        case .nextYear:
            return YearInReviewCardContent(
                eyebrow: "MY WORD FOR \(String(stats.nextYear))",
                hero: stats.nextYearDeclaration,
                heroStyle: .declaration,
                verse: "See, I am doing a new thing! Now it springs up.",
                reference: "Isaiah 43:19"
            )
        case .days, .cover, .summary:
            let days = stats.daysActive
            return YearInReviewCardContent(
                eyebrow: eyebrow,
                hero: count(days),
                caption: days == 1 ? "day I spoke God's Word over my life" : "days I spoke God's Word over my life",
                verse: "Like a tree planted by streams of water, which yields its fruit in season.",
                reference: "Psalm 1:3"
            )
        }
    }

    private func strengthBlessing(_ level: BurstCompletionTracker.StrengthLevel) -> String {
        switch level {
        case .warrior:     return "You picked up the shield. Keep standing."
        case .champion:    return "You held your ground, and it shows."
        case .conqueror:   return "You took new ground this year."
        case .victorious:  return "You came through the fire shining."
        case .unstoppable: return "Nothing can stand against you in His name."
        }
    }

    // MARK: - Sharing

    private enum ShareMethod: String {
        case shareSheet = "share_sheet"
        case instagramStories = "instagram_stories"
        /// Instagram is not installed, so the card is saved to Photos instead.
        case instagramFallbackSave = "instagram_fallback_save"
    }

    private static let instagramStoriesURL = URL(string: "instagram-stories://share")

    private var canOpenInstagramStories: Bool {
        guard let url = Self.instagramStoriesURL else { return false }
        return UIApplication.shared.canOpenURL(url)
    }

    @ViewBuilder
    private func shareCard(for slide: YearInReviewSlide) -> some View {
        switch slide {
        case .cover, .summary:
            YearInReviewSummaryCard(stats: stats, isPremium: includesPremiumExtras)
        default:
            YearInReviewStatCard(content: cardContent(for: slide), isPremium: includesPremiumExtras)
        }
    }

    @MainActor
    private func share(_ slide: YearInReviewSlide, method: ShareMethod) {
        guard let image = YearInReviewShareCard.render(shareCard(for: slide)) else { return }

        // Logged as what actually happens: with Instagram missing, the shared
        // helper saves the card to Photos rather than opening a story.
        let loggedMethod: ShareMethod = (method == .instagramStories && !canOpenInstagramStories)
            ? .instagramFallbackSave
            : method

        AnalyticsService.shared.track("year_in_review_shared", parameters: [
            "slide": slide.rawValue,
            "method": loggedMethod.rawValue,
            "year": stats.year,
            "in_progress": stats.isInProgress
        ])

        switch method {
        case .shareSheet:
            // The tracked link rides only when the share goes to a chat;
            // ReferralShareText leaves it off posts and saved images.
            let link = ReferralLink.url(.yearInReview, campaign: String(stats.year))
            shareItem = ShareItem(image: image,
                                  text: ReferralShareText(stats.shareWords(for: slide), link: link))
        case .instagramStories, .instagramFallbackSave:
            // `_ =` keeps this compiling whether the shared helper returns
            // Void (today) or a Bool (PR #501).
            _ = shareToInstagramStories(image: image)
        }
    }
}

// MARK: - Pieces

private struct ShareItem: Identifiable {
    let id = UUID()
    let image: UIImage
    let text: ReferralShareText
}

/// Gold tracked label with fading hairlines, the in-app twin of the card's.
private struct SlideEyebrow: View {
    let text: String

    var body: some View {
        HStack(spacing: DS.Spacing.sm) {
            LinearGradient(colors: [.clear, YearInReviewPalette.label], startPoint: .leading, endPoint: .trailing)
                .frame(width: 28, height: 1)
            Text(text.uppercased())
                .font(.system(size: 12, weight: .semibold))
                .tracking(3.5)
                .foregroundColor(YearInReviewPalette.label)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            LinearGradient(colors: [YearInReviewPalette.label, .clear], startPoint: .leading, endPoint: .trailing)
                .frame(width: 28, height: 1)
        }
    }
}

/// Draws a whole number that SwiftUI can animate between values, which is
/// what makes the hero count up. It ignores the view it modifies.
private struct CountUp: ViewModifier, Animatable {
    var value: Double

    var animatableData: Double {
        get { value }
        set { value = newValue }
    }

    func body(content: Content) -> some View {
        Text(verbatim: YearInReviewStats.formattedCount(Int(value.rounded())))
    }
}

/// A few motes of gold drifting on the cover. Plain circles on a repeating
/// animation: no timers, no Canvas loop. Still when Reduce Motion is on.
private struct GoldDust: View {
    let animate: Bool
    @State private var drifting = false

    private struct Mote {
        let x: Double
        let y: Double
        let size: Double
        let travel: Double
        let duration: Double
        let delay: Double
        let opacity: Double
    }

    /// Fixed, evenly scattered positions so the cover looks the same each time.
    private static let motes: [Mote] = (0..<14).map { i in
        let n = Double(i)
        return Mote(
            x: (n * 0.618 + 0.11).truncatingRemainder(dividingBy: 1),
            y: (n * 0.377 + 0.18).truncatingRemainder(dividingBy: 1),
            size: 3 + Double(i % 4) * 1.6,
            travel: 26 + Double(i % 5) * 10,
            duration: 4.5 + Double(i % 4) * 1.3,
            delay: Double(i % 7) * 0.35,
            opacity: 0.25 + Double(i % 3) * 0.15
        )
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(Self.motes.indices, id: \.self) { i in
                    let mote = Self.motes[i]
                    Circle()
                        .fill(YearInReviewPalette.glow)
                        .frame(width: mote.size, height: mote.size)
                        .blur(radius: mote.size * 0.3)
                        .opacity(drifting ? mote.opacity : mote.opacity * 0.4)
                        .position(x: geo.size.width * mote.x,
                                  y: geo.size.height * mote.y - (drifting ? mote.travel : 0))
                        .animation(
                            animate
                                ? .easeInOut(duration: mote.duration)
                                    .repeatForever(autoreverses: true)
                                    .delay(mote.delay)
                                : nil,
                            value: drifting
                        )
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear {
            if animate { drifting = true }
        }
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Recap, premium") {
    YearInReviewView(stats: .sample(), includesPremiumExtras: true, source: .todayCard)
}

#Preview("Recap, one day") {
    YearInReviewView(stats: .sample(daysActive: 1, totals: 0, bestMonth: (name: "March", count: 1)),
                     includesPremiumExtras: false)
}
#endif
