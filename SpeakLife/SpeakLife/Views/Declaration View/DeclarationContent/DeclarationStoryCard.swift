//
//  DeclarationStoryCard.swift
//  SpeakLife
//
//  The image a declaration is shared as: 1080x1920, sized for Instagram and
//  TikTok stories, built on the speaker's own theme photo.
//
//  It replaces a screenshot of the device screen, which came out at the
//  phone's point size (blurry once a story stretched it), carried no verse,
//  and had the app's name as its only call to action.
//
//  Layout notes, all in pixels on the 1080x1920 canvas:
//   - Instagram draws its own UI over roughly the top 250 and bottom 300, so
//     nothing that matters sits there.
//   - The photo is graded, not just darkened: a dark band behind the top
//     label, a soft dark halo behind the text, and a deep fade at the bottom
//     for the footer. The rest of the photo keeps its light.
//   - The declaration steps down in size with its length instead of shrinking
//     to fit, so short lines hit hard and long ones stay readable.
//

import SwiftUI
import UIKit
import CoreText

enum DeclarationStoryCard {

    static let size = CGSize(width: 1080, height: 1920)

    /// Where a card sits in a set shared together, such as a whole Daily Burst,
    /// so the person receiving them reads them in order.
    struct Position: Equatable {
        /// 1-based.
        let number: Int
        let total: Int
    }

    /// The gold label above the declaration. Jesus-voice lines (`book ==
    /// "Jesus"`, CLAUDE.md rule 1) say so instead of "I declare". A position
    /// is added only when there is more than one card to read in order.
    static func eyebrow(isJesusVoice: Bool, position: Position?) -> String {
        let label = isJesusVoice ? "JESUS SAYS" : "I DECLARE"
        guard let position, position.total > 1, position.number >= 1 else { return label }
        return "\(label) · \(position.number) OF \(position.total)"
    }

    /// Renders the card. Main actor because `ImageRenderer` is.
    ///
    /// - Parameters:
    ///   - declaration: what is being shared.
    ///   - background: the speaker's theme photo, or nil for the fallback gradient.
    ///   - position: the card's place in a shared set, or nil for a single card.
    @MainActor
    static func render(declaration: Declaration, background: UIImage?,
                       position: Position? = nil) -> UIImage? {
        let renderer = ImageRenderer(
            content: DeclarationStoryCardView(declaration: declaration, background: background,
                                              position: position)
        )
        renderer.scale = 1
        renderer.proposedSize = ProposedViewSize(size)
        renderer.isOpaque = true
        return renderer.uiImage
    }

    /// The speaker's own theme photo, so the card looks like their app: their
    /// uploaded picture when they set one, otherwise the theme's artwork. Nil
    /// only when neither loads, and the card then draws its gradient.
    static func background(for theme: ThemeViewModel) -> UIImage? {
        if theme.showUserSelectedImage, let selected = theme.selectedImage {
            return selected
        }
        return UIImage(named: theme.selectedTheme.backgroundImageString)
    }
}

struct DeclarationStoryCardView: View {

    let declaration: Declaration
    let background: UIImage?
    /// Set only when the card is one of a set, such as a whole Daily Burst.
    var position: DeclarationStoryCard.Position? = nil

    private static let gold = Color(red: 0.945, green: 0.824, blue: 0.604)   // #F1D29A
    private let width = DeclarationStoryCard.size.width
    private let height = DeclarationStoryCard.size.height

    /// Declarations with `book == "Jesus"` are in Jesus' own voice (see
    /// CLAUDE.md, rule 1), so the card says so instead of "I declare".
    private var isJesusVoice: Bool {
        declaration.book?.caseInsensitiveCompare("Jesus") == .orderedSame
    }

    private var verse: String? {
        guard let text = declaration.bibleVerseText?
            .trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return nil }
        return text
    }

    private var reference: String? {
        guard let book = declaration.book?
            .trimmingCharacters(in: .whitespacesAndNewlines), !book.isEmpty else { return nil }
        return book.uppercased()
    }

    /// Size steps by length. The set's median is 68 characters and its
    /// longest is about 210.
    private var declarationFontSize: CGFloat {
        switch declaration.text.count {
        case ..<51:  return 92
        case ..<81:  return 80
        case ..<121: return 68
        case ..<171: return 58
        default:     return 50
        }
    }

    var body: some View {
        ZStack {
            backgroundLayer
            grade

            VStack(spacing: 0) {
                eyebrow
                    .frame(height: 24)
                    .padding(.top, 250)

                Spacer(minLength: 0)
                content
                    .padding(.horizontal, 96)
                Spacer(minLength: 0)

                footer
                    .padding(.bottom, 330)
            }
        }
        .frame(width: width, height: height)
        .clipped()
        .environment(\.colorScheme, .dark)
    }

    // MARK: - Background

    @ViewBuilder
    private var backgroundLayer: some View {
        if let background {
            Image(uiImage: background)
                .resizable()
                .scaledToFill()
                .frame(width: width, height: height)
                .clipped()
        } else {
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.04, blue: 0.16),
                    Color(red: 0.20, green: 0.10, blue: 0.36),
                    Color(red: 0.42, green: 0.22, blue: 0.40),
                    Color(red: 0.08, green: 0.05, blue: 0.14)
                ],
                startPoint: .top, endPoint: .bottom
            )
        }
    }

    /// The colour grade that keeps every line readable on any photo.
    private var grade: some View {
        ZStack {
            LinearGradient(
                stops: [
                    .init(color: .black.opacity(0.70), location: 0.00),
                    .init(color: .black.opacity(0.45), location: 0.12),
                    .init(color: .black.opacity(0.12), location: 0.24),
                    .init(color: .black.opacity(0.22), location: 0.45),
                    .init(color: .black.opacity(0.45), location: 0.70),
                    .init(color: .black.opacity(0.88), location: 1.00)
                ],
                startPoint: .top, endPoint: .bottom
            )

            // Oval halo behind the text: 80% of the width by 36% of the height
            // (radii), centred just above the middle.
            EllipticalGradient(
                stops: [
                    .init(color: .black.opacity(0.60), location: 0.00),
                    .init(color: .black.opacity(0.34), location: 0.62),
                    .init(color: .clear, location: 1.00)
                ],
                center: .center,
                startRadiusFraction: 0,
                endRadiusFraction: 0.5
            )
            .frame(width: width * 1.6, height: height * 0.72)
            .position(x: width / 2, y: height * 0.47)
        }
        .frame(width: width, height: height)
        .allowsHitTesting(false)
    }

    // MARK: - Top

    private var eyebrow: some View {
        HStack(spacing: 28) {
            LinearGradient(colors: [.clear, Self.gold], startPoint: .leading, endPoint: .trailing)
                .frame(width: 90, height: 2)
            Text(DeclarationStoryCard.eyebrow(isJesusVoice: isJesusVoice, position: position))
                .font(.system(size: 28, weight: .semibold))
                .tracking(10)
                .foregroundStyle(Self.gold)
                .shadow(color: .black.opacity(0.7), radius: 6, y: 1)
            LinearGradient(colors: [Self.gold, .clear], startPoint: .leading, endPoint: .trailing)
                .frame(width: 90, height: 2)
        }
    }

    // MARK: - Declaration and verse

    private var content: some View {
        VStack(spacing: 0) {
            // The opening quote mark: the glyph's own outline scaled into a
            // fixed 60px-tall box, so its ink is exactly 60px high and sits
            // exactly 30px above the declaration on every device and OS.
            // Drawn as a font glyph it floated inside a 286px line box and
            // had to be nudged into place by eye.
            OpeningQuoteMark()
                .fill(Self.gold.opacity(0.95))
                .frame(width: 160, height: 60)
                .shadow(color: Self.gold.opacity(0.35), radius: 20)
                .padding(.bottom, 30)

            Text(declaration.text)
                .font(.system(size: declarationFontSize, weight: .medium, design: .serif))
                .kerning(-0.5)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .minimumScaleFactor(0.75)
                .shadow(color: .black.opacity(0.55), radius: 12, y: 2)
                .frame(maxWidth: .infinity)

            if verse != nil || reference != nil {
                Capsule()
                    .fill(Self.gold)
                    .frame(width: 72, height: 3)
                    .padding(.top, 60)
                    .padding(.bottom, 44)
            }

            if let verse {
                Text(verse)
                    .font(.system(size: 37, weight: .regular, design: .serif).italic())
                    .foregroundStyle(.white.opacity(0.82))
                    .multilineTextAlignment(.center)
                    .lineSpacing(10)
                    .lineLimit(4)
                    .truncationMode(.tail)
                    .shadow(color: .black.opacity(0.6), radius: 7, y: 1)
                    .frame(maxWidth: 820)
            }

            if let reference {
                Text(reference)
                    .font(.system(size: 27, weight: .semibold))
                    .tracking(7)
                    .foregroundStyle(Self.gold)
                    .shadow(color: .black.opacity(0.6), radius: 6, y: 1)
                    .padding(.top, verse == nil ? 0 : 26)
            }
        }
    }

    // MARK: - Footer

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
                Text("Free on the App Store")
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

// MARK: - Quote mark

/// The opening quote mark as a filled outline, fitted to whatever frame it is
/// given.
///
/// The outline comes from the glyph itself (Georgia, which ships on every iOS
/// device) and is scaled by its own ink bounds, not by font metrics. A 60px
/// tall frame gives exactly 60px of ink, centred, with nothing above or below
/// it, so its position cannot drift with a font's line height.
struct OpeningQuoteMark: Shape {

    /// Built once. Nil only if the font or glyph is missing, and then the card
    /// simply has no quote mark.
    private static let glyph: CGPath? = {
        let font = CTFontCreateWithName("Georgia" as CFString, 240, nil)
        var characters: [UniChar] = [0x201C]
        var glyphs: [CGGlyph] = [0]
        guard CTFontGetGlyphsForCharacters(font, &characters, &glyphs, 1) else { return nil }
        return CTFontCreatePathForGlyph(font, glyphs[0], nil)
    }()

    func path(in rect: CGRect) -> Path {
        guard let glyph = Self.glyph else { return Path() }
        let bounds = glyph.boundingBoxOfPath
        guard bounds.width > 0, bounds.height > 0 else { return Path() }

        let scale = min(rect.width / bounds.width, rect.height / bounds.height)
        // Core Text draws y-up and SwiftUI y-down, hence the negative y scale.
        let transform = CGAffineTransform(translationX: rect.midX, y: rect.midY)
            .scaledBy(x: scale, y: -scale)
            .translatedBy(x: -bounds.midX, y: -bounds.midY)
        return Path(glyph).applying(transform)
    }
}

// MARK: - Previews

/// The card at a third of its size, about how it reads in a story.
private func storyCardPreview(_ declaration: Declaration,
                              position: DeclarationStoryCard.Position? = nil) -> some View {
    DeclarationStoryCardView(declaration: declaration, background: nil, position: position)
        .frame(width: 1080, height: 1920)
        .scaleEffect(1.0 / 3.0)
        .frame(width: 360, height: 640)
}

#Preview("Short") {
    storyCardPreview(Declaration(
        text: "I am made in the image of God.",
        book: "Genesis 1:27",
        bibleVerseText: "So God created mankind in his own image, in the image of God he created them; male and female he created them.",
        category: .identity
    ))
}

#Preview("Median, 68 characters") {
    storyCardPreview(Declaration(
        text: "The Lord's love never ceases, and His mercies are new every morning.",
        book: "Lamentations 3:22-23",
        bibleVerseText: "The steadfast love of the Lord never ceases; his mercies never come to an end; they are new every morning; great is your faithfulness.",
        category: .love
    ))
}

#Preview("Longest, 211 characters") {
    storyCardPreview(Declaration(
        text: "I am in the lineage of something eternal. Every faithful act I take today is a seed in a story that spans generations. My obedience is not small. It is part of an unfolding covenant that reaches beyond my sight.",
        book: "Ruth 4:13b",
        bibleVerseText: "Then Boaz took Ruth and she became his wife... and she gave birth to a son.",
        category: .ruth
    ))
}

#Preview("Jesus voice") {
    storyCardPreview(Declaration(
        text: "You speak to the mountain without doubt, and what you say comes to pass.",
        book: "Jesus",
        bibleVerseText: "Truly I tell you, if anyone says to this mountain, 'Go, throw yourself into the sea,' and does not doubt in their heart but believes that what they say will happen, it will be done for them.",
        category: .speaklife
    ))
}

#Preview("Own declaration, no verse") {
    storyCardPreview(Declaration(
        text: "My home is full of peace, and every room is covered in prayer.",
        category: .myOwn
    ))
}

#Preview("Burst card, 1 of 7") {
    storyCardPreview(Declaration(
        text: "I have the mind of Christ.",
        book: "1 Corinthians 2:16",
        bibleVerseText: "For who has known the mind of the Lord so as to instruct him? But we have the mind of Christ.",
        category: .wisdom
    ), position: .init(number: 1, total: 7))
}
