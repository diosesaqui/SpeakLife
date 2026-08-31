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
//  What is actually worth sharing out of a burst is the line the person just
//  spoke over their own life. So the card leads with the declaration, sets the
//  scripture under it, and lets the streak sit in the footer where a stat
//  belongs. The stranger reads a promise; the friend sees the streak.
//
//  Everything else here exists to make the card recognisable at thumbnail size,
//  before a single word is read: the gold plate around the edge, the dark
//  indigo ground with light rising through it, the serif line, and the rail of
//  gold capsules — the same seven segments the burst's own progress bar is made
//  of. Those four marks are the signature. Keep them stable across every card
//  the app ever shares.
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
    /// What the burst was about, e.g. "Peace & Rest". Empty is handled.
    let themeLabel: String
    let streak: Int
    /// How many lines were spoken. Drives the rail, so it is also the segment
    /// count, clamped to something a 1080pt-wide card can actually hold.
    let declarationsSpoken: Int

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
            lightRays
            starfield
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

    /// Night, opening into warmth. Dark enough that white type sings, warm
    /// enough at the bottom that the flame in the footer belongs there.
    private var ground: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(hex: "05040C"),
                    Color(hex: "120C26"),
                    Color(hex: "20123F"),
                    Color(hex: "0C0718")
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            // The light the words stand in.
            RadialGradient(
                colors: [
                    Color(hex: "FFC857").opacity(0.22),
                    Color(hex: "B25CFF").opacity(0.10),
                    Color.clear
                ],
                center: UnitPoint(x: 0.5, y: 0.40),
                startRadius: 0,
                endRadius: width * 0.92
            )

            // Ember under the footer, so the streak sits in heat.
            RadialGradient(
                colors: [Color(hex: "FF6A1F").opacity(0.16), Color.clear],
                center: UnitPoint(x: 0.5, y: 1.02),
                startRadius: 0,
                endRadius: width * 0.85
            )
        }
    }

    /// Five soft wedges falling from above the frame. Restrained on purpose:
    /// enough to read as light breaking in, not enough to compete with the line.
    private var lightRays: some View {
        Canvas { context, size in
            let origin = CGPoint(x: size.width * 0.5, y: -size.height * 0.20)
            for i in 0..<5 {
                let center = (Double(i) - 2) * 0.22
                let spread = 0.055
                var path = Path()
                path.move(to: origin)
                path.addLine(to: rayPoint(from: origin, angle: center - spread, length: size.height * 1.6))
                path.addLine(to: rayPoint(from: origin, angle: center + spread, length: size.height * 1.6))
                path.closeSubpath()

                context.fill(
                    path,
                    with: .linearGradient(
                        SwiftUI.Gradient(colors: [
                            Color.white.opacity(0.038),
                            Color(hex: "FFD76A").opacity(0.016),
                            Color.clear
                        ]),
                        startPoint: origin,
                        endPoint: CGPoint(x: origin.x, y: size.height * 1.05)
                    )
                )
            }
        }
        .allowsHitTesting(false)
    }

    private func rayPoint(from origin: CGPoint, angle: Double, length: CGFloat) -> CGPoint {
        // Angle measured off straight-down, so 0 is a vertical shaft.
        CGPoint(x: origin.x + sin(angle) * length, y: origin.y + cos(angle) * length)
    }

    /// Dust in the light. Seeded rather than `random`, so the same burst renders
    /// the same card twice — a preview that reshuffles every redraw reads as a
    /// glitch, and a saved image should match the preview it was chosen from.
    private var starfield: some View {
        Canvas { context, size in
            for speck in Self.specks {
                let rect = CGRect(
                    x: speck.x * size.width - speck.radius,
                    y: speck.y * size.height - speck.radius,
                    width: speck.radius * 2,
                    height: speck.radius * 2
                )
                context.fill(
                    Path(ellipseIn: rect),
                    with: .color(Color.white.opacity(speck.opacity))
                )
            }
        }
        .allowsHitTesting(false)
    }

    private struct Speck {
        let x: CGFloat, y: CGFloat, radius: CGFloat, opacity: Double
    }

    private static let specks: [Speck] = {
        var seed: UInt64 = 0x5EED_C0DE_1F1E_2D2C
        func next() -> Double {
            seed = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            return Double((seed >> 33) % 1_000_000) / 1_000_000
        }
        return (0..<110).map { _ in
            Speck(
                x: CGFloat(next()),
                y: CGFloat(next()),
                radius: CGFloat(1.0 + next() * 2.4),
                opacity: 0.06 + next() * 0.30
            )
        }
    }()

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
                .padding(.top, 132)

            Spacer(minLength: 40)
                .frame(maxHeight: 300)

            if !card.themeLabel.isEmpty {
                themeChip
                    .padding(.bottom, 56)
            }

            hero

            rail
                .padding(.top, 56)

            if !card.verseReference.isEmpty {
                Text(card.verseReference.uppercased())
                    .font(.system(size: 30, weight: .bold))
                    .tracking(7)
                    .foregroundStyle(goldText)
                    .offset(x: trackingNudge(7))
                    .padding(.top, 46)
            }

            // Both gaps are capped, and not to the same number. Uncapped, the
            // slack on a short line opens two ~400pt holes and the card reads as
            // a small poster floating in a big empty one. Capped, the leftover
            // becomes margin above and below the whole block instead, and the
            // lower gap stays the larger of the two because the footer below it
            // carries far more weight than the wordmark up top.
            Spacer(minLength: 40)
                .frame(maxHeight: 340)

            statRow

            footer
                .padding(.top, 58)
                .padding(.bottom, 104)
        }
        .padding(.horizontal, 118)
        .multilineTextAlignment(.center)
    }

    private var wordmark: some View {
        Text("SPEAKLIFE")
            .font(.system(size: 34, weight: .black))
            .tracking(16)
            .foregroundStyle(goldText)
            .offset(x: trackingNudge(16))
    }

    private var themeChip: some View {
        Text(card.themeLabel.uppercased())
            .font(.system(size: 24, weight: .bold))
            .tracking(5)
            .foregroundColor(Color(hex: "FFE0A3"))
            .offset(x: trackingNudge(5))
            .padding(.horizontal, 34)
            .padding(.vertical, 15)
            .background(
                Capsule().fill(Color.white.opacity(0.06))
            )
            .overlay(
                Capsule().stroke(Color(hex: "FFD76A").opacity(0.45), lineWidth: 1.5)
            )
    }

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
            .shadow(color: Color.black.opacity(0.45), radius: 18, x: 0, y: 8)
            // A bound, not a truncation: the size step below already fits the
            // realistic range, and the limit only exists so a pathologically
            // long scripture shrinks instead of running off the plate.
            .lineLimit(10)
            .minimumScaleFactor(0.5)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// Long lines get smaller type rather than a scrollbar or a clipped word.
    /// The thresholds are set against the house rule that a declaration runs 10
    /// to 18 words, so the common case lands on the largest size.
    private var heroFontSize: CGFloat {
        switch card.declaration.count {
        case ..<55:   return 104
        case ..<85:   return 88
        case ..<125:  return 74
        case ..<180:  return 60
        default:      return 48
        }
    }

    /// The burst's own progress rail, one capsule per line spoken, lifted out
    /// of the app and set into the card. It is the mark that ties the artifact
    /// back to the thing that produced it.
    private var rail: some View {
        HStack(spacing: 14) {
            ForEach(0..<railCount, id: \.self) { _ in
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "FFE59A"), Color(hex: "E8A93C")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: 44, height: 6)
            }
        }
    }

    /// Clamped so an unusually long burst does not push the rail past the
    /// plate, and so a zero never renders an empty gap where a mark should be.
    private var railCount: Int { min(max(card.declarationsSpoken, 1), 10) }

    private var statRow: some View {
        HStack(spacing: 0) {
            stat(
                icon: "flame.fill",
                value: "\(max(card.streak, 1))",
                label: card.streak == 1 ? "DAY STRONG" : "DAY STREAK"
            )

            Rectangle()
                .fill(Color(hex: "FFD76A").opacity(0.28))
                .frame(width: 1.5, height: 74)
                .padding(.horizontal, 42)

            stat(
                icon: "bolt.fill",
                value: "\(max(card.declarationsSpoken, 1))",
                label: "SPOKEN TODAY"
            )
        }
    }

    private func stat(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 38, weight: .bold))
                    .foregroundStyle(goldText)

                Text(value)
                    .font(.system(size: 62, weight: .black, design: .rounded))
                    .foregroundColor(.white)
            }
            Text(label)
                .font(.system(size: 21, weight: .bold))
                .tracking(4)
                .foregroundColor(.white.opacity(0.62))
                .offset(x: trackingNudge(4))
        }
        .frame(maxWidth: .infinity)
    }

    /// Icon plus tagline. The icon is the download cue — a stranger who likes
    /// the line needs one glance to know what to look for in the App Store.
    private var footer: some View {
        VStack(spacing: 26) {
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
                        .foregroundColor(Color(hex: "FFD76A").opacity(0.85))
                }
            }
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
