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

import UIKit

enum StandInviteCardRenderer {

    /// 1080x1350 — the portrait ratio that survives iMessage, Instagram and
    /// Threads without being re-cropped.
    private static let size = CGSize(width: 1080, height: 1350)

    // MARK: - Invite

    static func render(theme: String, title: String, code: String) -> UIImage? {
        draw { context, rect in
            background(context, rect)

            let inset: CGFloat = 96
            var y: CGFloat = 250

            y += text("STAND WITH ME", at: CGPoint(x: inset, y: y),
                      width: rect.width - inset * 2,
                      font: .systemFont(ofSize: 34, weight: .heavy),
                      color: UIColor(red: 0.85, green: 0.70, blue: 0.35, alpha: 1),
                      kerning: 6)

            y += 44
            y += text("I'm speaking God's word over \(theme.lowercased()) for 7 days.",
                      at: CGPoint(x: inset, y: y),
                      width: rect.width - inset * 2,
                      font: .systemFont(ofSize: 66, weight: .bold),
                      color: .white, lineHeight: 78)

            y += 72
            y += text(title.uppercased(), at: CGPoint(x: inset, y: y),
                      width: rect.width - inset * 2,
                      font: .systemFont(ofSize: 28, weight: .semibold),
                      color: UIColor.white.withAlphaComponent(0.62), kerning: 3)

            codePlate(context, rect: rect, code: code, y: rect.height - 400)
            footer(rect)
        }
    }

    // MARK: - Completion

    /// The day-7 card. Names everyone, because who you held the week with is
    /// the whole point of it.
    static func renderCompletion(title: String, names: [String]) -> UIImage? {
        draw { context, rect in
            background(context, rect)

            let inset: CGFloat = 96
            var y: CGFloat = 300

            y += text("SEVEN DAYS", at: CGPoint(x: inset, y: y),
                      width: rect.width - inset * 2,
                      font: .systemFont(ofSize: 34, weight: .heavy),
                      color: UIColor(red: 0.85, green: 0.70, blue: 0.35, alpha: 1),
                      kerning: 6)

            y += 44
            y += text(title, at: CGPoint(x: inset, y: y),
                      width: rect.width - inset * 2,
                      font: .systemFont(ofSize: 72, weight: .bold),
                      color: .white, lineHeight: 84)

            y += 56
            y += text(togetherLine(names), at: CGPoint(x: inset, y: y),
                      width: rect.width - inset * 2,
                      font: .systemFont(ofSize: 36, weight: .medium),
                      color: UIColor.white.withAlphaComponent(0.78), lineHeight: 46)

            y += 40
            _ = text("Ground Jesus already took.", at: CGPoint(x: inset, y: y),
                     width: rect.width - inset * 2,
                     font: .systemFont(ofSize: 30, weight: .regular),
                     color: UIColor.white.withAlphaComponent(0.55))

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

    private static func draw(_ body: (CGContext, CGRect) -> Void) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        defer { UIGraphicsEndImageContext() }
        guard let context = UIGraphicsGetCurrentContext() else { return nil }
        body(context, CGRect(origin: .zero, size: size))
        return UIGraphicsGetImageFromCurrentImageContext()
    }

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
                                   start: CGPoint(x: 0, y: 0),
                                   end: CGPoint(x: rect.width, y: rect.height),
                                   options: [])
    }

    private static func codePlate(_ context: CGContext, rect: CGRect,
                                  code: String, y: CGFloat) {
        let inset: CGFloat = 96
        let plate = CGRect(x: inset, y: y, width: rect.width - inset * 2, height: 190)
        let path = UIBezierPath(roundedRect: plate, cornerRadius: 32)
        UIColor.white.withAlphaComponent(0.10).setFill()
        path.fill()

        _ = text("INVITE CODE",
                 at: CGPoint(x: inset, y: y + 36),
                 width: plate.width, font: .systemFont(ofSize: 22, weight: .bold),
                 color: UIColor.white.withAlphaComponent(0.55),
                 kerning: 4, centered: true, containerX: inset)

        _ = text(code,
                 at: CGPoint(x: inset, y: y + 78),
                 width: plate.width,
                 font: .monospacedSystemFont(ofSize: 60, weight: .bold),
                 color: .white, kerning: 8, centered: true, containerX: inset)
    }

    private static func footer(_ rect: CGRect) {
        _ = text("SPEAKLIFE",
                 at: CGPoint(x: 0, y: rect.height - 140),
                 width: rect.width,
                 font: .systemFont(ofSize: 26, weight: .bold),
                 color: UIColor.white.withAlphaComponent(0.45),
                 kerning: 5, centered: true, containerX: 0)
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
