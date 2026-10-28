//
//  YearInReviewShareCard.swift
//  SpeakLife
//
//  The images a Year in Review slide is shared as: 1080x1920 story cards in
//  the visual language of `DeclarationStoryCard`.
//
//  The old export rendered at the screen's scale (3240x5760) with point-sized
//  type inside a 1080-wide frame, so the words came out tiny. These cards are
//  rendered at scale 1 and every size below is in pixels on the 1080x1920
//  canvas.
//
//  Layout notes, all in pixels:
//   - Instagram draws its own UI over roughly the top 250 and bottom 300, so
//     everything that matters sits between y=250 and y=1600.
//   - A stats card has no photo, so the background is a graded gradient:
//     night navy at the top, violet through the middle, a warm gold glow
//     behind the lower half, and a dark floor under the footer pill.
//

import SwiftUI
import UIKit

enum YearInReviewShareCard {

    static let size = CGSize(width: 1080, height: 1920)

    /// Renders a card to a 1080x1920 image. Main actor because
    /// `ImageRenderer` is. Cards are static views, so nothing animates in
    /// the output.
    @MainActor
    static func render<Card: View>(_ card: Card) -> UIImage? {
        let renderer = ImageRenderer(
            content: card
                .frame(width: size.width, height: size.height)
                .environment(\.colorScheme, .dark)
        )
        renderer.scale = 1
        renderer.proposedSize = ProposedViewSize(size)
        renderer.isOpaque = true
        return renderer.uiImage
    }
}

// MARK: - Palette

/// Colours shared by the cards and the in-app slides, so what the user sees
/// is what they post.
enum YearInReviewPalette {
    /// The story-card label gold, #F1D29A.
    static let label = Color(red: 0.945, green: 0.824, blue: 0.604)

    /// Gold for hero numbers: bright at the top, deeper at the base.
    static let heroGold = LinearGradient(
        colors: [
            Color(red: 1.00, green: 0.93, blue: 0.74),
            Color(red: 0.98, green: 0.80, blue: 0.42),
            Color(red: 0.91, green: 0.62, blue: 0.22)
        ],
        startPoint: .top, endPoint: .bottom
    )

    static let glow = Color(red: 0.98, green: 0.75, blue: 0.36)
}

// MARK: - Background

/// The graded night-to-gold background. Takes its size so the glows scale
/// the same on a 1080x1920 card and on a phone screen.
struct YearInReviewBackground: View {
    let size: CGSize

    var body: some View {
        ZStack {
            LinearGradient(
                stops: [
                    .init(color: Color(red: 0.02, green: 0.03, blue: 0.10), location: 0.00),
                    .init(color: Color(red: 0.06, green: 0.06, blue: 0.20), location: 0.28),
                    .init(color: Color(red: 0.20, green: 0.11, blue: 0.34), location: 0.60),
                    .init(color: Color(red: 0.30, green: 0.16, blue: 0.24), location: 0.82),
                    .init(color: Color(red: 0.07, green: 0.04, blue: 0.08), location: 1.00)
                ],
                startPoint: .top, endPoint: .bottom
            )

            // Violet bloom high up, behind the eyebrow and hero.
            RadialGradient(
                colors: [Color(red: 0.45, green: 0.30, blue: 0.85).opacity(0.28), .clear],
                center: UnitPoint(x: 0.5, y: 0.30),
                startRadius: 0,
                endRadius: size.width * 0.75
            )

            // Warm gold glow in the lower half: the "light coming" note.
            RadialGradient(
                colors: [YearInReviewPalette.glow.opacity(0.36), YearInReviewPalette.glow.opacity(0.10), .clear],
                center: UnitPoint(x: 0.5, y: 0.78),
                startRadius: 0,
                endRadius: size.width * 0.85
            )

            // Dark floor so the footer pill stays readable.
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0.70),
                    .init(color: .black.opacity(0.55), location: 1.00)
                ],
                startPoint: .top, endPoint: .bottom
            )
        }
        .frame(width: size.width, height: size.height)
        .allowsHitTesting(false)
    }
}

// MARK: - Card content

/// What one card (and its matching in-app slide) says.
struct YearInReviewCardContent {
    enum HeroStyle {
        /// A big gold number, such as "212".
        case number
        /// A gold word, such as a month or a strength level.
        case word
        /// A full white line, such as the closing declaration.
        case declaration
    }

    var eyebrow: String
    var symbol: String? = nil
    var hero: String
    var heroStyle: HeroStyle = .number
    var caption: String? = nil
    var detail: String? = nil
    var verse: String? = nil
    var reference: String? = nil
}

// MARK: - Shared frame

/// Background, gold eyebrow at the top of the safe zone, centred content,
/// and the premium mark plus "Speak it with SpeakLife" pill at the bottom.
private struct YearInReviewCardFrame<Content: View>: View {
    let eyebrow: String
    let isPremium: Bool
    @ViewBuilder var content: Content

    private let size = YearInReviewShareCard.size

    var body: some View {
        ZStack {
            YearInReviewBackground(size: size)

            VStack(spacing: 0) {
                YearInReviewCardEyebrow(text: eyebrow)
                    .frame(height: 34)
                    .padding(.top, 250)

                Spacer(minLength: 0)
                content
                    .padding(.horizontal, 96)
                Spacer(minLength: 0)

                if isPremium {
                    premiumMark
                        .padding(.bottom, 36)
                }
                footer
                    .padding(.bottom, 330)
            }
        }
        .frame(width: size.width, height: size.height)
        .clipped()
    }

    /// A quiet thank-you for subscribers, not a badge that shouts.
    private var premiumMark: some View {
        HStack(spacing: 14) {
            Image(systemName: "crown.fill")
                .font(.system(size: 22, weight: .semibold))
            Text("PREMIUM WARRIOR")
                .font(.system(size: 22, weight: .semibold))
                .tracking(8)
        }
        .foregroundStyle(YearInReviewPalette.label.opacity(0.85))
    }

    private var footer: some View {
        HStack(spacing: 24) {
            Image(uiImage: UIImage(named: "appIconDisplay") ?? UIImage())
                .resizable()
                .scaledToFill()
                .frame(width: 76, height: 76)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .shadow(color: .black.opacity(0.35), radius: 10, y: 6)

            VStack(alignment: .leading, spacing: 4) {
                Text("Speak it with SpeakLife")
                    .font(.system(size: 31, weight: .bold))
                    .foregroundStyle(.white)
                Text("Download on iOS")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(.white.opacity(0.72))
            }
        }
        .padding(.leading, 20)
        .padding(.trailing, 40)
        .padding(.vertical, 20)
        .background(
            Capsule(style: .continuous)
                .fill(.white.opacity(0.13))
                .overlay(
                    Capsule(style: .continuous)
                        .strokeBorder(.white.opacity(0.22), lineWidth: 1.5)
                )
        )
    }
}

/// Gold tracked label with hairlines fading in from either side.
private struct YearInReviewCardEyebrow: View {
    let text: String

    var body: some View {
        HStack(spacing: 28) {
            LinearGradient(colors: [.clear, YearInReviewPalette.label], startPoint: .leading, endPoint: .trailing)
                .frame(width: 90, height: 2)
            Text(text.uppercased())
                .font(.system(size: 28, weight: .semibold))
                .tracking(10)
                .foregroundStyle(YearInReviewPalette.label)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            LinearGradient(colors: [YearInReviewPalette.label, .clear], startPoint: .leading, endPoint: .trailing)
                .frame(width: 90, height: 2)
        }
    }
}

// MARK: - Stat card

/// One stat: eyebrow, a hero in huge serif, a plain caption, and a short
/// verse with its reference.
struct YearInReviewStatCard: View {
    let content: YearInReviewCardContent
    let isPremium: Bool

    var body: some View {
        YearInReviewCardFrame(eyebrow: content.eyebrow, isPremium: isPremium) {
            VStack(spacing: 0) {
                if let symbol = content.symbol {
                    Image(systemName: symbol)
                        .font(.system(size: 150, weight: .semibold))
                        .foregroundStyle(YearInReviewPalette.heroGold)
                        .shadow(color: YearInReviewPalette.glow.opacity(0.45), radius: 40)
                        .padding(.bottom, 40)
                }

                hero

                if let caption = content.caption {
                    Text(caption)
                        .font(.system(size: 50, weight: .medium, design: .serif))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .minimumScaleFactor(0.8)
                        .shadow(color: .black.opacity(0.5), radius: 10, y: 2)
                        .padding(.top, 20)
                }

                if let detail = content.detail {
                    Text(detail)
                        .font(.system(size: 34, weight: .regular))
                        .foregroundStyle(.white.opacity(0.72))
                        .multilineTextAlignment(.center)
                        .padding(.top, 24)
                }

                if content.verse != nil || content.reference != nil {
                    Capsule()
                        .fill(YearInReviewPalette.label)
                        .frame(width: 72, height: 3)
                        .padding(.top, 70)
                        .padding(.bottom, 44)
                }

                if let verse = content.verse {
                    Text(verse)
                        .font(.system(size: 37, weight: .regular, design: .serif).italic())
                        .foregroundStyle(.white.opacity(0.82))
                        .multilineTextAlignment(.center)
                        .lineSpacing(10)
                        .lineLimit(3)
                        .shadow(color: .black.opacity(0.6), radius: 7, y: 1)
                        .frame(maxWidth: 820)
                }

                if let reference = content.reference {
                    Text(reference.uppercased())
                        .font(.system(size: 27, weight: .semibold))
                        .tracking(7)
                        .foregroundStyle(YearInReviewPalette.label)
                        .padding(.top, content.verse == nil ? 0 : 26)
                }
            }
        }
    }

    @ViewBuilder
    private var hero: some View {
        switch content.heroStyle {
        case .number:
            Text(content.hero)
                .font(.system(size: 280, weight: .semibold, design: .serif))
                .kerning(-4)
                .foregroundStyle(YearInReviewPalette.heroGold)
                .lineLimit(1)
                .minimumScaleFactor(0.4)
                .shadow(color: YearInReviewPalette.glow.opacity(0.40), radius: 50)
        case .word:
            Text(content.hero)
                .font(.system(size: 150, weight: .semibold, design: .serif))
                .foregroundStyle(YearInReviewPalette.heroGold)
                .lineLimit(1)
                .minimumScaleFactor(0.45)
                .shadow(color: YearInReviewPalette.glow.opacity(0.40), radius: 40)
        case .declaration:
            Text(content.hero)
                .font(.system(size: 84, weight: .medium, design: .serif))
                .kerning(-0.5)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .minimumScaleFactor(0.75)
                .shadow(color: .black.opacity(0.55), radius: 12, y: 2)
        }
    }
}

// MARK: - Summary card

/// The whole year on one card: days active as the hero, then up to four
/// quiet rows.
struct YearInReviewSummaryCard: View {
    let stats: YearInReviewStats
    let isPremium: Bool

    private struct Row: Identifiable {
        let label: String
        let value: String
        var id: String { label }
    }

    private var rows: [Row] {
        var rows: [Row] = []
        let longest = stats.longestStreakInYear
        if longest > 0 {
            rows.append(Row(label: "Longest run",
                            value: longest == 1 ? "1 day" : "\(YearInReviewStats.formattedCount(longest)) days"))
        }
        if stats.totalDeclarationsSpoken > 0 {
            rows.append(Row(label: "Daily Burst declarations",
                            value: YearInReviewStats.formattedCount(stats.totalDeclarationsSpoken)))
        }
        if let best = stats.bestMonth {
            rows.append(Row(label: "Strongest month", value: best.name))
        }
        if isPremium {
            rows.append(Row(label: "Strength reached", value: stats.peakStrengthLevel.rawValue))
        }
        return rows
    }

    private var eyebrow: String {
        stats.isInProgress ? "MY \(stats.year) SO FAR" : "MY \(stats.year) IN SPEAKLIFE"
    }

    var body: some View {
        YearInReviewCardFrame(eyebrow: eyebrow, isPremium: isPremium) {
            VStack(spacing: 0) {
                Text(YearInReviewStats.formattedCount(stats.daysActive))
                    .font(.system(size: 260, weight: .semibold, design: .serif))
                    .kerning(-4)
                    .foregroundStyle(YearInReviewPalette.heroGold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.4)
                    .shadow(color: YearInReviewPalette.glow.opacity(0.40), radius: 50)

                Text(stats.daysActive == 1
                     ? "day I spoke God's Word over my life"
                     : "days I spoke God's Word over my life")
                    .font(.system(size: 46, weight: .medium, design: .serif))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .padding(.top, 16)

                if !rows.isEmpty {
                    Capsule()
                        .fill(YearInReviewPalette.label)
                        .frame(width: 72, height: 3)
                        .padding(.top, 64)
                        .padding(.bottom, 28)

                    VStack(spacing: 0) {
                        ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                            if index > 0 {
                                Rectangle()
                                    .fill(.white.opacity(0.12))
                                    .frame(height: 1.5)
                            }
                            HStack(alignment: .firstTextBaseline, spacing: 24) {
                                Text(row.label)
                                    .font(.system(size: 34, weight: .regular))
                                    .foregroundStyle(.white.opacity(0.75))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                                Spacer(minLength: 16)
                                Text(row.value)
                                    .font(.system(size: 56, weight: .semibold, design: .serif))
                                    .foregroundStyle(YearInReviewPalette.heroGold)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.6)
                            }
                            .padding(.vertical, 26)
                        }
                    }
                    .frame(maxWidth: 840)
                }
            }
        }
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Stat card") {
    YearInReviewStatCard(
        content: YearInReviewCardContent(
            eyebrow: "MY 2026 SO FAR",
            hero: "212",
            caption: "days I spoke God's Word over my life",
            verse: "Like a tree planted by streams of water, which yields its fruit in season.",
            reference: "Psalm 1:3"
        ),
        isPremium: true
    )
    .frame(width: 1080, height: 1920)
    .scaleEffect(0.3)
    .frame(width: 324, height: 576)
}

#Preview("Summary card") {
    YearInReviewSummaryCard(stats: .sample(), isPremium: false)
        .frame(width: 1080, height: 1920)
        .scaleEffect(0.3)
        .frame(width: 324, height: 576)
}

#Preview("Declaration card") {
    YearInReviewStatCard(
        content: YearInReviewCardContent(
            eyebrow: "MY WORD FOR 2027",
            hero: "I step into 2027 rooted, unshakeable and full of His Word.",
            heroStyle: .declaration,
            verse: "See, I am doing a new thing! Now it springs up.",
            reference: "Isaiah 43:19"
        ),
        isPremium: false
    )
    .frame(width: 1080, height: 1920)
    .scaleEffect(0.3)
    .frame(width: 324, height: 576)
}
#endif
