//
//  ReferralShareCardRenderer.swift
//  SpeakLife
//
//  The image that travels with a referral link. Spec §9.4.
//
//  Drawn the same way as `StandInviteCardRenderer` (UIKit and CoreGraphics, in
//  the app target, never in Core) and for the same reason it exists at all: a
//  card lands in a text thread far harder than a bare link does.
//
//  The code is printed on the card, large. Branch's deferred matching is
//  probabilistic, so a friend who installs and is not matched still has eight
//  characters to type into "Have an invite code?" (spec J5).
//
//  ⚠️ The card says nothing about a reward. The friend gets nothing for
//  joining (spec D6), and Apple rejects designs that tie a reward to the act of
//  sharing. The card is an invitation to the app, nothing more.
//

import UIKit

/// The live `ReferralShareCardRendering`.
@MainActor
struct LiveReferralShareCardRenderer: ReferralShareCardRendering {
    func render(formattedCode: String) -> UIImage? {
        ReferralShareCardRenderer.render(code: formattedCode)
    }
}

enum ReferralShareCardRenderer {

    /// 1080x1350, the portrait ratio that survives iMessage, Instagram and
    /// Threads without a re-crop. Same as the Stand card.
    private static let size = CGSize(width: 1080, height: 1350)

    private static let gold = UIColor(red: 0.85, green: 0.70, blue: 0.35, alpha: 1)

    static func render(code: String) -> UIImage? {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { ctx in
            let context = ctx.cgContext
            let rect = CGRect(origin: .zero, size: size)
            background(context, rect)

            let inset: CGFloat = 96
            let width = rect.width - inset * 2
            var y: CGFloat = 240

            y += text("JOIN ME ON SPEAKLIFE", at: CGPoint(x: inset, y: y), width: width,
                      font: .systemFont(ofSize: 34, weight: .heavy),
                      color: gold, kerning: 6)

            y += 44
            y += text("I speak God's promises out loud every morning.",
                      at: CGPoint(x: inset, y: y), width: width,
                      font: .systemFont(ofSize: 70, weight: .bold),
                      color: .white, lineHeight: 82)

            y += 48
            _ = text("Start your mornings with His Word.",
                     at: CGPoint(x: inset, y: y), width: width,
                     font: .systemFont(ofSize: 36, weight: .medium),
                     color: UIColor.white.withAlphaComponent(0.72), lineHeight: 46)

            codePlate(rect: rect, code: code, y: rect.height - 400)
            footer(rect)
        }
    }

    // MARK: - Pieces

    private static func background(_ context: CGContext, _ rect: CGRect) {
        let colors = [
            UIColor(red: 0.04, green: 0.02, blue: 0.16, alpha: 1).cgColor,
            UIColor(red: 0.16, green: 0.06, blue: 0.34, alpha: 1).cgColor,
            UIColor(red: 0.07, green: 0.04, blue: 0.20, alpha: 1).cgColor,
        ]
        guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                        colors: colors as CFArray,
                                        locations: [0, 0.55, 1]) else { return }
        context.drawLinearGradient(gradient,
                                   start: .zero,
                                   end: CGPoint(x: rect.width, y: rect.height),
                                   options: [])
    }

    private static func codePlate(rect: CGRect, code: String, y: CGFloat) {
        let inset: CGFloat = 96
        let plate = CGRect(x: inset, y: y, width: rect.width - inset * 2, height: 190)
        UIColor.white.withAlphaComponent(0.10).setFill()
        UIBezierPath(roundedRect: plate, cornerRadius: 32).fill()

        _ = text("MY INVITE CODE", at: CGPoint(x: inset, y: y + 36), width: plate.width,
                 font: .systemFont(ofSize: 22, weight: .bold),
                 color: UIColor.white.withAlphaComponent(0.55),
                 kerning: 4, centered: true)

        _ = text(code, at: CGPoint(x: inset, y: y + 78), width: plate.width,
                 font: .monospacedSystemFont(ofSize: 60, weight: .bold),
                 color: .white, kerning: 8, centered: true)
    }

    private static func footer(_ rect: CGRect) {
        _ = text("SPEAKLIFE", at: CGPoint(x: 0, y: rect.height - 140), width: rect.width,
                 font: .systemFont(ofSize: 26, weight: .bold),
                 color: UIColor.white.withAlphaComponent(0.45),
                 kerning: 5, centered: true)
    }

    /// Draws wrapped text and returns the height used, so blocks stack without
    /// hand-tuned offsets when the copy changes.
    @discardableResult
    private static func text(_ string: String, at point: CGPoint, width: CGFloat,
                             font: UIFont, color: UIColor,
                             kerning: CGFloat = 0, lineHeight: CGFloat? = nil,
                             centered: Bool = false) -> CGFloat {
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
        attributed.draw(with: CGRect(x: point.x, y: point.y, width: width, height: ceil(bounds.height)),
                        options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
        return ceil(bounds.height)
    }
}
