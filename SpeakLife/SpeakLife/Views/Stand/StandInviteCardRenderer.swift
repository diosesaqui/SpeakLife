//
//  StandInviteCardRenderer.swift
//  SpeakLife
//
//  Draws the invite and completion cards.
//
//  Built the same way as `StreakShareCardRenderer` — UIKit and CoreGraphics in
//  the app target, never in the package — and for the same reason: Core cannot
//  depend on UIKit.
//
//  Why an image at all: a rendered card lands in a text thread far harder than
//  a bare URL does. This is the difference between "my son sent me a link" and
//  "my son asked me to stand with him", and it is the cheapest conversion lever
//  in the whole feature because the drawing code already existed to copy.
//
//  The look follows `DeclarationStoryCard`, so a Stand invite and a shared
//  declaration read as the same app: a gold label between hairlines, a serif
//  headline, a gold rule, and the "Speak it with SpeakLife" badge.
//

import UIKit

enum StandInviteCardRenderer {

    /// 1080x1350 — the portrait ratio that survives iMessage, Instagram and
    /// Threads without being re-cropped.
    private static let size = CGSize(width: 1080, height: 1350)

    /// Same gold as `DeclarationStoryCardView.gold` (#F1D29A).
    private static let gold = UIColor(red: 0.945, green: 0.824, blue: 0.604, alpha: 1)

    private static let inset: CGFloat = 96

    // MARK: - Invite

    /// - Parameters:
    ///   - headline: the sender's line, already worded ("I'm standing on God's
    ///     word for peace this week.").
    ///   - title: the campaign's display title.
    ///   - code: the formatted invite code.
    static func render(headline: String, title: String, code: String) -> UIImage? {
        draw { context, rect in
            background(context, rect)

            let width = rect.width - inset * 2
            var y: CGFloat = 190

            y += eyebrow("STAND WITH ME", y: y, rect: rect)

            // Steps down with length rather than shrinking to fit, so a short
            // line hits hard and a long one stays readable.
            let size: CGFloat = headline.count <= 44 ? 78 : (headline.count <= 64 ? 68 : 58)
            y += 70
            y += text(headline, at: CGPoint(x: inset, y: y), width: width,
                      font: serif(size, weight: .medium),
                      color: .white, lineHeight: size * 1.18, centered: true,
                      containerX: inset)

            y += 56
            rule(context, centerX: rect.midX, y: y)

            y += 44
            _ = text("\(title.uppercased()) · 7 DAYS", at: CGPoint(x: inset, y: y),
                     width: width, font: .systemFont(ofSize: 26, weight: .semibold),
                     color: gold, kerning: 5, centered: true, containerX: inset)

            codePlate(context, rect: rect, code: code, y: rect.height - 430)
            footer(rect)
        }
    }

    // MARK: - Completion

    /// The day-7 card. Names everyone, because who you held the week with is
    /// the whole point of it.
    static func renderCompletion(title: String, names: [String]) -> UIImage? {
        draw { context, rect in
            background(context, rect)

            let width = rect.width - inset * 2
            var y: CGFloat = 260

            y += eyebrow("SEVEN DAYS", y: y, rect: rect)

            y += 70
            y += text(title, at: CGPoint(x: inset, y: y), width: width,
                      font: serif(76, weight: .medium),
                      color: .white, lineHeight: 88, centered: true, containerX: inset)

            y += 56
            rule(context, centerX: rect.midX, y: y)

            y += 44
            y += text(togetherLine(names), at: CGPoint(x: inset, y: y), width: width,
                      font: .systemFont(ofSize: 36, weight: .medium),
                      color: UIColor.white.withAlphaComponent(0.82), lineHeight: 46,
                      centered: true, containerX: inset)

            y += 28
            _ = text("Ground Jesus already took.", at: CGPoint(x: inset, y: y), width: width,
                     font: serif(32, weight: .regular).italicized,
                     color: UIColor.white.withAlphaComponent(0.6),
                     centered: true, containerX: inset)

            footer(rect)
        }
    }

    /// "Sarah and Mom" / "Sarah, Mom and 3 others". Kept short: a twelve-person
    /// roster listed in full is unreadable at thumbnail size.
    private static func togetherLine(_ names: [String]) -> String {
        let clean = names.filter { !$0.isEmpty }
        switch clean.count {
        case 0: return "Held together."
        case 1: return "Held with \(clean[0])."
        case 2: return "Held with \(clean[0]) and \(clean[1])."
        case 3: return "Held with \(clean[0]), \(clean[1]) and \(clean[2])."
        default:
            let rest = clean.count - 2
            return "Held with \(clean[0]), \(clean[1]) and \(rest) others."
        }
    }

    // MARK: - Pieces

    /// Scale 1, so the image is exactly 1080x1350 pixels. The fonts here are
    /// sized for that pixel canvas; at the device scale the old renderer used,
    /// the same card came out 3240x4050 and about 50 MB in memory for nothing.
    private static func draw(_ body: (CGContext, CGRect) -> Void) -> UIImage? {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { ctx in
            body(ctx.cgContext, CGRect(origin: .zero, size: size))
        }
    }

    private static func background(_ context: CGContext, _ rect: CGRect) {
        let space = CGColorSpaceCreateDeviceRGB()
        let colors = [
            UIColor(red: 0.04, green: 0.02, blue: 0.16, alpha: 1).cgColor,
            UIColor(red: 0.16, green: 0.06, blue: 0.34, alpha: 1).cgColor,
            UIColor(red: 0.07, green: 0.04, blue: 0.20, alpha: 1).cgColor,
        ]
        if let gradient = CGGradient(colorsSpace: space, colors: colors as CFArray,
                                     locations: [0, 0.55, 1]) {
            context.drawLinearGradient(gradient,
                                       start: CGPoint(x: 0, y: 0),
                                       end: CGPoint(x: rect.width, y: rect.height),
                                       options: [])
        }

        // A soft gold glow behind the headline, the card's one warm light.
        let glow = [gold.withAlphaComponent(0.16).cgColor, gold.withAlphaComponent(0).cgColor]
        if let radial = CGGradient(colorsSpace: space, colors: glow as CFArray, locations: [0, 1]) {
            let center = CGPoint(x: rect.midX, y: rect.height * 0.36)
            context.drawRadialGradient(radial, startCenter: center, startRadius: 0,
                                       endCenter: center, endRadius: rect.width * 0.62,
                                       options: [])
        }
    }

    /// The gold label between two fading hairlines. Returns its height.
    private static func eyebrow(_ label: String, y: CGFloat, rect: CGRect) -> CGFloat {
        let font = UIFont.systemFont(ofSize: 28, weight: .semibold)
        let attributed = NSAttributedString(string: label, attributes: [
            .font: font, .foregroundColor: gold, .kern: 10,
        ])
        let labelSize = attributed.size()
        let labelX = rect.midX - labelSize.width / 2
        attributed.draw(at: CGPoint(x: labelX, y: y))

        let lineY = y + labelSize.height / 2
        let lineWidth: CGFloat = 90
        let gap: CGFloat = 28
        hairline(from: CGPoint(x: labelX - gap - lineWidth, y: lineY), width: lineWidth, fadeIn: true)
        hairline(from: CGPoint(x: labelX + labelSize.width + gap, y: lineY), width: lineWidth, fadeIn: false)
        return ceil(labelSize.height)
    }

    private static func hairline(from origin: CGPoint, width: CGFloat, fadeIn: Bool) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        let colors = fadeIn
            ? [gold.withAlphaComponent(0).cgColor, gold.cgColor]
            : [gold.cgColor, gold.withAlphaComponent(0).cgColor]
        guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                        colors: colors as CFArray, locations: [0, 1]) else { return }
        context.saveGState()
        context.clip(to: CGRect(x: origin.x, y: origin.y - 1, width: width, height: 2))
        context.drawLinearGradient(gradient, start: origin,
                                   end: CGPoint(x: origin.x + width, y: origin.y), options: [])
        context.restoreGState()
    }

    private static func rule(_ context: CGContext, centerX: CGFloat, y: CGFloat) {
        let bar = CGRect(x: centerX - 36, y: y, width: 72, height: 3)
        gold.setFill()
        UIBezierPath(roundedRect: bar, cornerRadius: 1.5).fill()
    }

    private static func codePlate(_ context: CGContext, rect: CGRect,
                                  code: String, y: CGFloat) {
        let plate = CGRect(x: inset, y: y, width: rect.width - inset * 2, height: 190)
        let path = UIBezierPath(roundedRect: plate, cornerRadius: 32)
        UIColor.white.withAlphaComponent(0.09).setFill()
        path.fill()
        gold.withAlphaComponent(0.35).setStroke()
        path.lineWidth = 2
        path.stroke()

        _ = text("INVITE CODE",
                 at: CGPoint(x: inset, y: y + 36),
                 width: plate.width, font: .systemFont(ofSize: 22, weight: .bold),
                 color: gold.withAlphaComponent(0.85),
                 kerning: 5, centered: true, containerX: inset)

        _ = text(code,
                 at: CGPoint(x: inset, y: y + 78),
                 width: plate.width,
                 font: .monospacedSystemFont(ofSize: 60, weight: .bold),
                 color: .white, kerning: 8, centered: true, containerX: inset)
    }

    /// The app icon and "Speak it with SpeakLife", centered as one group.
    private static func footer(_ rect: CGRect) {
        let label = NSAttributedString(string: "Speak it with SpeakLife", attributes: [
            .font: UIFont.systemFont(ofSize: 31, weight: .bold),
            .foregroundColor: UIColor.white.withAlphaComponent(0.9),
        ])
        let labelSize = label.size()
        let icon = UIImage(named: "appIconDisplay")
        let iconSide: CGFloat = 60
        let gap: CGFloat = icon == nil ? 0 : 20
        let groupWidth = (icon == nil ? 0 : iconSide) + gap + labelSize.width
        let centerY = rect.height - 120
        var x = rect.midX - groupWidth / 2

        if let icon {
            let frame = CGRect(x: x, y: centerY - iconSide / 2, width: iconSide, height: iconSide)
            UIGraphicsGetCurrentContext()?.saveGState()
            UIBezierPath(roundedRect: frame, cornerRadius: 14).addClip()
            icon.draw(in: frame)
            UIGraphicsGetCurrentContext()?.restoreGState()
            x += iconSide + gap
        }
        label.draw(at: CGPoint(x: x, y: centerY - labelSize.height / 2))
    }

    private static func serif(_ size: CGFloat, weight: UIFont.Weight) -> UIFont {
        let base = UIFont.systemFont(ofSize: size, weight: weight)
        guard let descriptor = base.fontDescriptor.withDesign(.serif) else { return base }
        return UIFont(descriptor: descriptor, size: size)
    }

    /// Draws wrapped text and returns the height used, so callers can stack
    /// blocks without hand-tuning every offset when copy changes.
    @discardableResult
    private static func text(_ string: String, at point: CGPoint, width: CGFloat,
                             font: UIFont, color: UIColor,
                             kerning: CGFloat = 0, lineHeight: CGFloat? = nil,
                             centered: Bool = false,
                             containerX: CGFloat? = nil) -> CGFloat {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = centered ? .center : .left
        if let lineHeight {
            paragraph.minimumLineHeight = lineHeight
            paragraph.maximumLineHeight = lineHeight
        }

        var attributes: [NSAttributedString.Key: Any] = [
            .font: font, .foregroundColor: color, .paragraphStyle: paragraph,
        ]
        if kerning != 0 { attributes[.kern] = kerning }

        let attributed = NSAttributedString(string: string, attributes: attributes)
        let bounds = attributed.boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)

        attributed.draw(with: CGRect(x: containerX ?? point.x, y: point.y,
                                     width: width, height: ceil(bounds.height)),
                        options: [.usesLineFragmentOrigin, .usesFontLeading],
                        context: nil)
        return ceil(bounds.height)
    }
}

private extension UIFont {
    /// The same face, italic. Falls back to itself when the face has no italic.
    var italicized: UIFont {
        guard let descriptor = fontDescriptor.withSymbolicTraits(
            fontDescriptor.symbolicTraits.union(.traitItalic)) else { return self }
        return UIFont(descriptor: descriptor, size: pointSize)
    }
}
