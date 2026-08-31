//
//  BurstVictoryShareCard.swift
//  SpeakLife
//
//  The image someone posts after finishing a Daily Burst.
//
//  The burst used to share a block of plain text — "✅ 7 Declarations Spoken,
//  🔥 12 Day Streak" — which is a receipt, not a post. Nobody reposts a receipt,
//  and nothing about it says SpeakLife to a stranger scrolling past it.
//
//  The card is not a new look. It is the completion screen the user is standing
//  on, composed for a 9:16 canvas: their own theme photo behind it, the gold
//  medallion with the burst's seven segments radiating out of it, and the flame
//  streak badge. Someone who sees the post and then opens the app lands on the
//  same picture, which is the whole point of a recognisable one.
//
//  What the card adds is the declaration. The screen leads with a checkmark
//  because the user already knows what they said; a stranger does not, and a
//  gold tick means nothing to them. So the line the person just spoke over
//  their own life becomes the hero, and the streak drops to a stat.
//
//  Four marks carry the recognition, in this order of importance: the medallion
//  with its rail of segments, the theme photo, the gold plate around the edge,
//  and the serif line. Keep them stable across every card the app ever shares.
//

import SwiftUI
import UIKit

// MARK: - Card Content

/// Everything one shareable card renders. A value type on purpose: the preview
/// sheet holds several of them (one per line spoken) and swaps between them
/// without touching the burst's own state.
struct BurstShareCard: Identifiable {
    let id = UUID()
    /// The hero. First person, present tense, spoken out loud minutes ago.
    let declaration: String
    /// Reference only, e.g. "Isaiah 53:5". Empty when the line has no verse
    /// behind it, in which case the card drops the reference rather than
    /// printing an empty rule.
    let verseReference: String
    let streak: Int
    /// How many lines were spoken. Drives the rail around the medallion, so it
    /// is also the segment count, clamped to what a ring can legibly hold.
    let declarationsSpoken: Int
    /// The theme the user is actually looking at — their own photo when they set
    /// one, otherwise the selected theme's artwork.
    ///
    /// Passed in rather than read from `ThemeViewModel` so the card renders in
    /// isolation, including from a preview, and so a missing image degrades to
    /// the gradient ground instead of taking the renderer down with it.
    let themeImage: UIImage?

    /// The caption that travels beside the image. The image carries the design;
    /// this carries the link, because a beautiful post nobody can act on is
    /// still a dead end.
    var shareText: String {
        var lines = ["\u{201C}\(declaration)\u{201D}"]
        if !verseReference.isEmpty { lines.append(verseReference) }
        lines.append("")
        if streak > 1 {
            lines.append("Day \(streak) of speaking life over my life. \u{1F525}")
        } else {
            lines.append("Speaking life over my life today. \u{1F525}")
        }
        lines.append("")
        lines.append("SpeakLife: \(APP.Product.urlID)")
        lines.append("#SpeakLife")
        return lines.joined(separator: "\n")
    }
}

// MARK: - The Card

/// A fixed 1080x1920 story card. Declared in points at its final pixel size so
/// `ImageRenderer` at scale 1 produces exactly the resolution Instagram,
/// TikTok and Stories all want, with no resampling anywhere in the path.
///
/// Nothing in here uses `blur` or `Material`: `ImageRenderer` rasterises those
/// unreliably, and a card that looks right on screen and wrong in the share
/// sheet is worse than one that never used them. Every soft edge is a gradient.
struct BurstVictoryShareCard: View {

    let card: BurstShareCard

    /// Canvas size. Also the design grid every number below is measured against.
    static let size = CGSize(width: 1080, height: 1920)

    private var width: CGFloat { Self.size.width }
    private var height: CGFloat { Self.size.height }

    var body: some View {
        ZStack {
            ground
            plate
            content
        }
        .frame(width: width, height: height)
        .clipped()
        // The card is a brand artifact, not an app screen: it must render the
        // same way regardless of the phone's appearance or text-size setting,
        // because the file outlives both.
        .environment(\.colorScheme, .dark)
        .dynamicTypeSize(.large)
    }

    // MARK: Background

    /// The user's theme, seated for type.
    ///
    /// The app scrims its themes at 45–65% black. The card lands close to that
    /// on the whole and then shapes it: lighter across the top two thirds so the
    /// photo the user chose is still visibly theirs, heavier at the foot where
    /// the streak and the lockup sit, plus a soft vignette to hold the edges.
    /// Push it much further and every theme renders as the same black
    /// rectangle, which is a card nobody recognises as their own.
    private var ground: some View {
        ZStack {
            // Under everything, so a missing or slow-loading theme still gives
            // the card a ground rather than a hole.
            LinearGradient(
                colors: [Color(hex: "05040C"), Color(hex: "1A1030"), Color(hex: "0C0718")],
                startPoint: .top,
                endPoint: .bottom
            )

            if let themeImage = card.themeImage {
                Image(uiImage: themeImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: width, height: height)
                    .clipped()
            }

            LinearGradient(
                colors: [
                    Color.black.opacity(0.42),
                    Color.black.opacity(0.34),
                    Color.black.opacity(0.52),
                    Color.black.opacity(0.72)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            RadialGradient(
                colors: [Color.clear, Color.black.opacity(0.32)],
                center: .center,
                startRadius: width * 0.34,
                endRadius: width * 0.98
            )

            // The warmth the medallion sits in, borrowed from the glow behind it
            // on the completion screen.
            RadialGradient(
                colors: [Color(hex: "FFB33C").opacity(0.20), Color.clear],
                center: UnitPoint(x: 0.5, y: 0.29),
                startRadius: 0,
                endRadius: width * 0.62
            )
        }
    }

    // MARK: The plate

    /// The gold frame. This is the single most recognisable thing on the card:
    /// at thumbnail size the words are unreadable and the plate still says
    /// SpeakLife. Two strokes — a gold one and a white hairline inside it — so
    /// it reads as pressed metal rather than a border.
    private var plate: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 58, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color(hex: "FFE59A"),
                            Color(hex: "E8A93C"),
                            Color(hex: "FFD76A"),
                            Color(hex: "9A6A16")
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2.5
                )
                .padding(44)

            RoundedRectangle(cornerRadius: 48, style: .continuous)
                .strokeBorder(Color.white.opacity(0.07), lineWidth: 1)
                .padding(58)
        }
        .allowsHitTesting(false)
    }

    // MARK: Content

    private var content: some View {
        VStack(spacing: 0) {
            wordmark
                .padding(.top, 104)

            Spacer(minLength: 32)
                .frame(maxHeight: 160)

            medallion

            Spacer(minLength: 32)
                .frame(maxHeight: 150)

            hero

            if !card.verseReference.isEmpty {
                Text(card.verseReference.uppercased())
                    .font(.system(size: 30, weight: .bold))
                    .tracking(7)
                    .foregroundStyle(goldText)
                    .offset(x: trackingNudge(7))
                    .padding(.top, 46)
            }

            // Larger than the gap above the medallion on purpose: the streak and
            // the footer below read as one heavy block, and an even split leaves
            // the line floating with a dead field under it.
            Spacer(minLength: 32)
                .frame(maxHeight: 230)

            streakBadge

            footer
                .padding(.top, 54)
                .padding(.bottom, 96)
        }
        .padding(.horizontal, 112)
        .multilineTextAlignment(.center)
    }

    private var wordmark: some View {
        Text("SPEAKLIFE")
            .font(.system(size: 34, weight: .black))
            .tracking(16)
            .foregroundStyle(goldText)
            .offset(x: trackingNudge(16))
            .shadow(color: .black.opacity(0.6), radius: 10, x: 0, y: 3)
    }

    // MARK: The medallion

    /// The completion screen's mark, at card scale.
    ///
    /// Same construction as `DailyDeclarationBurstView.completionView`: a gold
    /// disc under a white tick, ringed by one capsule per line spoken, inside a
    /// hairline circle. The capsules are the burst's own progress rail brought
    /// up from the bottom of the screen and set around the mark, so the reward
    /// is made of the work rather than dropped on top of it.
    ///
    /// Deliberately smaller here than it is on screen. There it is the hero,
    /// because the user already knows what they said. On the card the
    /// declaration is the hero and this is the crest above it.
    private var medallion: some View {
        ZStack {
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [
                            Color(hex: "FFD76A").opacity(0.45),
                            Color(hex: "FF9A1A").opacity(0.22)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 3
                )
                .frame(width: 300, height: 300)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(hex: "FF9A1A").opacity(0.42), Color.clear],
                        center: .center,
                        startRadius: 10,
                        endRadius: 145
                    )
                )
                .frame(width: 290, height: 290)

            ForEach(0..<railCount, id: \.self) { index in
                let angle = (Double(index) / Double(railCount)) * 2 * .pi - .pi / 2

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "FFE59A"), Color(hex: "E8A93C")],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 9, height: 32)
                    .shadow(color: Color(hex: "FFD76A").opacity(0.7), radius: 9)
                    .offset(x: cos(angle) * 122, y: sin(angle) * 122)
                    // Each segment stands on end, pointing out from the mark
                    // like rays rather than lying flat.
                    .rotationEffect(.degrees(angle * 180 / .pi + 90))
            }

            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "FFCC33"), Color(hex: "FF9A1A")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 168, height: 168)
                .shadow(color: Color(hex: "FF8A00").opacity(0.75), radius: 34, x: 0, y: 8)

            Image(systemName: "checkmark")
                .font(.system(size: 84, weight: .bold))
                .foregroundColor(.white)
        }
        .frame(width: 300, height: 300)
    }

    /// One capsule per line spoken, clamped so the ring stays legible: below
    /// three it reads as decoration rather than a count, and above ten the
    /// capsules start to touch.
    private var railCount: Int { min(max(card.declarationsSpoken, 3), 10) }

    // MARK: The line

    /// The reason the card exists. Serif, because this is a promise being
    /// quoted and not a UI label, and because it is the one type choice that
    /// separates a SpeakLife card from every sans-serif quote graphic on the
    /// feed.
    private var hero: some View {
        Text(card.declaration)
            .font(.system(size: heroFontSize, weight: .heavy, design: .serif))
            .lineSpacing(heroFontSize * 0.17)
            .foregroundStyle(
                LinearGradient(
                    colors: [Color.white, Color(hex: "FFF3D6")],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            // Heavier than a normal text shadow: this sits on whatever photo the
            // user picked, and some themes are bright.
            .shadow(color: Color.black.opacity(0.75), radius: 22, x: 0, y: 8)
            // A bound, not a truncation: the size step below already fits the
            // realistic range, and the limit only exists so a pathologically
            // long scripture shrinks instead of running off the plate.
            .lineLimit(8)
            .minimumScaleFactor(0.5)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// Long lines get smaller type rather than a clipped word. The thresholds
    /// are set against the house rule that a declaration runs 10 to 18 words,
    /// so the common case lands on the largest size.
    private var heroFontSize: CGFloat {
        switch card.declaration.count {
        case ..<55:   return 88
        case ..<85:   return 76
        case ..<125:  return 64
        case ..<180:  return 54
        default:      return 44
        }
    }

    // MARK: The streak

    /// The completion screen's flame badge, unchanged in form: a warm disc, the
    /// number under it, the label under that. It is the one stat on the card,
    /// and it is the part a friend reads rather than a stranger.
    private var streakBadge: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "FF9A2E"), Color(hex: "F2542D")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 118, height: 118)
                    .shadow(color: Color(hex: "FF6A1F").opacity(0.65), radius: 26, x: 0, y: 6)

                Image(systemName: "flame.fill")
                    .font(.system(size: 54, weight: .bold))
                    .foregroundColor(.white)
            }

            Text("\(max(card.streak, 1))")
                .font(.system(size: 78, weight: .black, design: .rounded))
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.55), radius: 12, x: 0, y: 4)

            Text(card.streak == 1 ? "DAY ONE" : "DAY STREAK")
                .font(.system(size: 22, weight: .bold))
                .tracking(5)
                .foregroundColor(.white.opacity(0.72))
                .offset(x: trackingNudge(5))
        }
    }

    // MARK: The footer

    /// Icon plus tagline. The icon is the download cue — a stranger who likes
    /// the line needs one glance to know what to look for in the App Store.
    private var footer: some View {
        VStack(spacing: 24) {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [Color.clear, Color(hex: "FFD76A").opacity(0.40), Color.clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 1.5)

            HStack(spacing: 22) {
                appIcon

                VStack(alignment: .leading, spacing: 7) {
                    Text("SPEAKLIFE")
                        .font(.system(size: 30, weight: .black))
                        .tracking(6)
                        .foregroundColor(.white)

                    Text("SPEAK IT \u{00B7} BELIEVE IT \u{00B7} RECEIVE IT")
                        .font(.system(size: 19, weight: .semibold))
                        .tracking(2.4)
                        .foregroundColor(Color(hex: "FFD76A").opacity(0.88))
                }
            }
            .shadow(color: .black.opacity(0.5), radius: 10, x: 0, y: 3)
        }
    }

    /// Falls back to a lettered plate when the asset is missing, so a renamed
    /// image asset degrades to something still branded instead of a hole in the
    /// footer.
    @ViewBuilder
    private var appIcon: some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)

        Group {
            if let icon = UIImage(named: "appIconDisplay") ?? UIImage(named: "AppIcon") {
                Image(uiImage: icon).resizable()
            } else {
                ZStack {
                    shape.fill(
                        LinearGradient(
                            colors: [Color(hex: "FFD76A"), Color(hex: "E08A00")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    Text("SL")
                        .font(.system(size: 34, weight: .black))
                        .foregroundColor(Color(hex: "1A1030"))
                }
            }
        }
        .frame(width: 78, height: 78)
        .clipShape(shape)
        .overlay(shape.stroke(Color(hex: "FFD76A").opacity(0.55), lineWidth: 1.5))
    }

    /// `tracking` also appends space after the final glyph, which drags centred
    /// text left by half a letter-space. Invisible at UI sizes; at 16pt tracking
    /// on a 1080pt card it is 8pt of visible drift off the centre line, so every
    /// centred tracked line pays it back.
    private func trackingNudge(_ tracking: CGFloat) -> CGFloat { tracking / 2 }

    private var goldText: LinearGradient {
        LinearGradient(
            colors: [Color(hex: "FFE9B0"), Color(hex: "FFD76A"), Color(hex: "E0A32E")],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

// MARK: - Rendering

enum BurstShareCardRenderer {

    /// Rasterises a card at exactly 1080x1920.
    ///
    /// Scale is pinned to 1 rather than the screen's: the view is already laid
    /// out in points equal to the target pixels, so a 3x screen would otherwise
    /// produce a 3240x5760 image that every social app immediately downsamples.
    @MainActor
    static func image(for card: BurstShareCard) -> UIImage? {
        let renderer = ImageRenderer(content: BurstVictoryShareCard(card: card))
        renderer.scale = 1
        renderer.proposedSize = ProposedViewSize(BurstVictoryShareCard.size)
        renderer.isOpaque = true
        return renderer.uiImage
    }
}
