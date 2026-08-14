//
//  StreakShareCardRenderer.swift
//  SpeakLife
//
//  All the UIKit/CoreGraphics drawing that used to live inside
//  `EnhancedStreakViewModel.generateShareImage()` and its 12 private
//  helpers (`:1131-1817`).
//
//  Extracted so `EnhancedStreakViewModel` is Foundation + Combine only,
//  which is the seam that lets it move into the SpeakLifeServices
//  package. The view model installs `EnhancedStreakViewModel.shareImageRenderer`
//  at app startup (AppDelegate) with `StreakShareCardRenderer.render`;
//  tests leave it nil and the celebration's `shareImage` field is nil,
//  which the share sheet already handles.
//

import UIKit
import SpeakLifeServices

/// UIKit-only renderer for the streak celebration share card.
///
/// Returns `Any?` (a `UIImage?` under the hood) so the same seam matches
/// `EnhancedStreakViewModel.ShareImageRenderer`, which is `Any?` for the
/// same reason `CompletionCelebration.shareImage` is: Core cannot depend
/// on UIKit.
enum StreakShareCardRenderer {

    /// Renders the 1080x1920 Instagram-story share image for a given streak.
    ///
    /// - Parameter args: the streak's current count plus the milestone/message
    ///   strings the view model already computes.
    /// - Returns: a `UIImage` wrapped as `Any` so it survives the Core seam.
    static func render(_ args: StreakShareRenderArgs) -> Any? {
        let size = CGSize(width: 1080, height: 1920)

        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        defer { UIGraphicsEndImageContext() }

        guard let context = UIGraphicsGetCurrentContext() else { return nil }

        // Cinematic gradient background
        let colors = [
            UIColor(red: 0.02, green: 0.0, blue: 0.15, alpha: 1),
            UIColor(red: 0.15, green: 0.02, blue: 0.35, alpha: 1),
            UIColor(red: 0.35, green: 0.05, blue: 0.55, alpha: 1),
            UIColor(red: 0.55, green: 0.15, blue: 0.75, alpha: 1),
            UIColor(red: 0.45, green: 0.25, blue: 0.85, alpha: 1),
            UIColor(red: 0.25, green: 0.08, blue: 0.65, alpha: 1),
            UIColor(red: 0.08, green: 0.02, blue: 0.35, alpha: 1),
            UIColor(red: 0.02, green: 0.0, blue: 0.15, alpha: 1)
        ]

        let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                colors: colors.map { $0.cgColor } as CFArray,
                                locations: [0.0, 0.15, 0.3, 0.45, 0.6, 0.75, 0.9, 1.0])!

        context.drawLinearGradient(gradient,
                                 start: CGPoint(x: 0, y: 0),
                                 end: CGPoint(x: size.width, y: size.height),
                                 options: [])

        let radialGradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                       colors: [
                                           UIColor.clear.cgColor,
                                           UIColor(red: 0.1, green: 0.02, blue: 0.3, alpha: 0.4).cgColor,
                                           UIColor(red: 0.0, green: 0.0, blue: 0.1, alpha: 0.7).cgColor
                                       ] as CFArray,
                                       locations: [0.0, 0.6, 1.0])!

        context.drawRadialGradient(radialGradient,
                                 startCenter: CGPoint(x: size.width * 0.5, y: size.height * 0.3),
                                 startRadius: 0,
                                 endCenter: CGPoint(x: size.width * 0.5, y: size.height * 0.3),
                                 endRadius: size.width * 0.8,
                                 options: [])

        addPremiumTextureOverlay(to: context, in: size)
        addFloatingOrbs(to: context, in: size)
        addLightRays(to: context, in: size)
        addStellarParticles(to: context, in: size)

        let textColor = UIColor.white
        drawTopBranding(in: context, size: size, textColor: textColor)
        drawCenterHero(in: context, size: size, textColor: textColor, streakNumber: args.currentStreak)
        drawAchievementSection(in: context, size: size, textColor: textColor,
                               milestone: args.milestone, message: args.motivationalMessage)
        drawBottomBranding(in: context, size: size, textColor: textColor)

        return UIGraphicsGetImageFromCurrentImageContext()
    }

    // MARK: - Share Image Drawing Methods

    private static func addFloatingOrbs(to context: CGContext, in size: CGSize) {
        let orbPositions = [
            CGPoint(x: size.width * 0.15, y: size.height * 0.2),
            CGPoint(x: size.width * 0.85, y: size.height * 0.3),
            CGPoint(x: size.width * 0.25, y: size.height * 0.7),
            CGPoint(x: size.width * 0.75, y: size.height * 0.8),
            CGPoint(x: size.width * 0.1, y: size.height * 0.5),
            CGPoint(x: size.width * 0.9, y: size.height * 0.6)
        ]

        for (index, position) in orbPositions.enumerated() {
            let radius = CGFloat(20 + index * 5)
            let alpha = 0.1 - Double(index) * 0.015

            context.setFillColor(UIColor.white.withAlphaComponent(alpha).cgColor)
            context.fillEllipse(in: CGRect(
                x: position.x - radius,
                y: position.y - radius,
                width: radius * 2,
                height: radius * 2
            ))
        }
    }

    private static func drawTopBranding(in context: CGContext, size: CGSize, textColor: UIColor) {
        let appName = "SPEAKLIFE"
        let appNameAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 48, weight: .black),
            .foregroundColor: textColor,
            .kern: 3.0
        ]

        let appNameSize = appName.size(withAttributes: appNameAttributes)
        let appNameRect = CGRect(
            x: (size.width - appNameSize.width) / 2,
            y: size.height * 0.06,
            width: appNameSize.width,
            height: appNameSize.height
        )

        context.setShadow(offset: CGSize.zero, blur: 12, color: UIColor.systemYellow.withAlphaComponent(0.4).cgColor)
        appName.draw(in: appNameRect, withAttributes: appNameAttributes)
        context.setShadow(offset: CGSize.zero, blur: 0, color: nil)

        let tagline = "SPEAK IT • BELIEVE IT • RECEIVE IT"
        let taglineAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 18, weight: .semibold),
            .foregroundColor: UIColor.systemYellow.withAlphaComponent(0.95),
            .kern: 1.5
        ]

        let taglineSize = tagline.size(withAttributes: taglineAttributes)
        let taglineRect = CGRect(
            x: (size.width - taglineSize.width) / 2,
            y: appNameRect.maxY + 20,
            width: taglineSize.width,
            height: taglineSize.height
        )

        context.setShadow(offset: CGSize.zero, blur: 6, color: UIColor.systemYellow.withAlphaComponent(0.5).cgColor)
        tagline.draw(in: taglineRect, withAttributes: taglineAttributes)
        context.setShadow(offset: CGSize.zero, blur: 0, color: nil)
    }

    private static func drawCenterHero(in context: CGContext, size: CGSize, textColor: UIColor, streakNumber: Int) {
        let centerY = size.height * 0.42

        drawPremiumFlameShapes(in: context, centerX: size.width / 2, centerY: centerY)

        let streakText = "\(streakNumber)"
        let streakAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 200, weight: .black),
            .foregroundColor: textColor,
            .kern: 5.0
        ]

        let streakSize = streakText.size(withAttributes: streakAttributes)
        let streakRect = CGRect(
            x: (size.width - streakSize.width) / 2,
            y: centerY - streakSize.height / 2,
            width: streakSize.width,
            height: streakSize.height
        )

        context.setShadow(offset: CGSize.zero, blur: 40, color: UIColor.systemYellow.withAlphaComponent(0.9).cgColor)
        streakText.draw(in: streakRect, withAttributes: streakAttributes)

        context.setShadow(offset: CGSize.zero, blur: 30, color: UIColor.systemOrange.withAlphaComponent(0.8).cgColor)
        streakText.draw(in: streakRect, withAttributes: streakAttributes)

        context.setShadow(offset: CGSize.zero, blur: 20, color: UIColor.systemRed.withAlphaComponent(0.7).cgColor)
        streakText.draw(in: streakRect, withAttributes: streakAttributes)

        context.setShadow(offset: CGSize.zero, blur: 12, color: UIColor.white.withAlphaComponent(0.9).cgColor)
        streakText.draw(in: streakRect, withAttributes: streakAttributes)

        context.setShadow(offset: CGSize.zero, blur: 6, color: UIColor.systemPink.withAlphaComponent(0.5).cgColor)
        streakText.draw(in: streakRect, withAttributes: streakAttributes)

        context.setShadow(offset: CGSize.zero, blur: 2, color: UIColor.systemPurple.withAlphaComponent(0.4).cgColor)
        streakText.draw(in: streakRect, withAttributes: streakAttributes)

        context.setShadow(offset: CGSize.zero, blur: 0, color: nil)

        let daysText = "DAYS OF SPEAKING LIFE!"
        let daysAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 40, weight: .black),
            .foregroundColor: UIColor.white,
            .kern: 2.5
        ]

        let daysSize = daysText.size(withAttributes: daysAttributes)
        let daysRect = CGRect(
            x: (size.width - daysSize.width) / 2,
            y: streakRect.maxY + 32,
            width: daysSize.width,
            height: daysSize.height
        )

        context.setShadow(offset: CGSize.zero, blur: 15, color: UIColor.systemYellow.withAlphaComponent(0.8).cgColor)
        daysText.draw(in: daysRect, withAttributes: daysAttributes)

        context.setShadow(offset: CGSize.zero, blur: 8, color: UIColor.systemOrange.withAlphaComponent(0.6).cgColor)
        daysText.draw(in: daysRect, withAttributes: daysAttributes)

        context.setShadow(offset: CGSize.zero, blur: 0, color: nil)
    }

    private static func drawAchievementSection(in context: CGContext, size: CGSize, textColor: UIColor, milestone: String, message: String) {
        let achievementY = size.height * 0.68

        if !milestone.isEmpty {
            let badgeText = "🏆 \(milestone.uppercased()) UNLOCKED!"
            let badgeAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 32, weight: .black),
                .foregroundColor: UIColor.white,
                .kern: 2.0
            ]

            let badgeSize = badgeText.size(withAttributes: badgeAttributes)
            let badgeRect = CGRect(
                x: (size.width - badgeSize.width) / 2,
                y: achievementY,
                width: badgeSize.width,
                height: badgeSize.height
            )

            context.setShadow(offset: CGSize.zero, blur: 18, color: UIColor.systemYellow.withAlphaComponent(0.9).cgColor)
            badgeText.draw(in: badgeRect, withAttributes: badgeAttributes)

            context.setShadow(offset: CGSize.zero, blur: 10, color: UIColor.systemOrange.withAlphaComponent(0.7).cgColor)
            badgeText.draw(in: badgeRect, withAttributes: badgeAttributes)

            context.setShadow(offset: CGSize.zero, blur: 4, color: UIColor.white.withAlphaComponent(0.8).cgColor)
            badgeText.draw(in: badgeRect, withAttributes: badgeAttributes)

            context.setShadow(offset: CGSize.zero, blur: 0, color: nil)
        }

        let maxWidth = size.width * 0.88
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        paragraphStyle.lineSpacing = 12

        let messageAttributesWithStyle: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 26, weight: .semibold),
            .foregroundColor: textColor,
            .paragraphStyle: paragraphStyle,
            .kern: 0.8
        ]

        let messageRect = CGRect(
            x: (size.width - maxWidth) / 2,
            y: achievementY + 60,
            width: maxWidth,
            height: 120
        )

        context.setShadow(offset: CGSize.zero, blur: 8, color: UIColor.white.withAlphaComponent(0.4).cgColor)
        message.draw(in: messageRect, withAttributes: messageAttributesWithStyle)

        context.setShadow(offset: CGSize.zero, blur: 3, color: UIColor.systemYellow.withAlphaComponent(0.2).cgColor)
        message.draw(in: messageRect, withAttributes: messageAttributesWithStyle)

        context.setShadow(offset: CGSize.zero, blur: 0, color: nil)
    }

    private static func drawBottomBranding(in context: CGContext, size: CGSize, textColor: UIColor) {
        let logoImageNames = ["appIconDisplay", "speaklifeicon", "AppIcon"]
        var foundImage: UIImage?

        for imageName in logoImageNames {
            if let image = UIImage(named: imageName) {
                foundImage = image
                break
            }
        }

        let logoY = size.height * 0.78

        if let appIcon = foundImage {
            let logoSize: CGFloat = 250
            let logoRect = CGRect(
                x: (size.width - logoSize) / 2,
                y: logoY,
                width: logoSize,
                height: logoSize
            )

            drawPremiumLogoBackground(in: context, rect: logoRect)

            context.saveGState()

            let iconRect = logoRect.insetBy(dx: 8, dy: 8)
            context.addEllipse(in: iconRect)
            context.clip()

            appIcon.draw(in: iconRect)

            context.restoreGState()

        } else {
            let logoSize: CGFloat = 140
            let logoRect = CGRect(
                x: (size.width - logoSize) / 2,
                y: logoY,
                width: logoSize,
                height: logoSize
            )

            drawPremiumLogoBackground(in: context, rect: logoRect)

            let logoText = "SL"
            let logoAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 56, weight: .black),
                .foregroundColor: textColor
            ]

            let textSize = logoText.size(withAttributes: logoAttributes)
            let textRect = CGRect(
                x: logoRect.midX - textSize.width / 2,
                y: logoRect.midY - textSize.height / 2,
                width: textSize.width,
                height: textSize.height
            )
            logoText.draw(in: textRect, withAttributes: logoAttributes)
        }

        let bottomText = "SHARE YOUR VICTORY!"
        let bottomAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 26, weight: .black),
            .foregroundColor: UIColor.white,
            .kern: 2.0
        ]

        let bottomSize = bottomText.size(withAttributes: bottomAttributes)
        let bottomRect = CGRect(
            x: (size.width - bottomSize.width) / 2,
            y: logoY + 160,
            width: bottomSize.width,
            height: bottomSize.height
        )

        context.setShadow(offset: CGSize.zero, blur: 20, color: UIColor.systemYellow.withAlphaComponent(0.8).cgColor)
        bottomText.draw(in: bottomRect, withAttributes: bottomAttributes)

        context.setShadow(offset: CGSize.zero, blur: 12, color: UIColor.systemOrange.withAlphaComponent(0.6).cgColor)
        bottomText.draw(in: bottomRect, withAttributes: bottomAttributes)

        context.setShadow(offset: CGSize.zero, blur: 6, color: UIColor.white.withAlphaComponent(0.9).cgColor)
        bottomText.draw(in: bottomRect, withAttributes: bottomAttributes)

        context.setShadow(offset: CGSize.zero, blur: 0, color: nil)
    }

    private static func drawPremiumLogoBackground(in context: CGContext, rect: CGRect) {
        context.setShadow(offset: CGSize.zero, blur: 50, color: UIColor.white.withAlphaComponent(0.6).cgColor)

        let logoGradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                    colors: [
                                        UIColor.white.withAlphaComponent(0.98).cgColor,
                                        UIColor.white.withAlphaComponent(0.85).cgColor,
                                        UIColor.white.withAlphaComponent(0.95).cgColor
                                    ] as CFArray,
                                    locations: [0.0, 0.7, 1.0])!

        context.saveGState()
        context.addEllipse(in: rect)
        context.clip()
        context.drawRadialGradient(logoGradient,
                                 startCenter: CGPoint(x: rect.midX, y: rect.midY),
                                 startRadius: 0,
                                 endCenter: CGPoint(x: rect.midX, y: rect.midY),
                                 endRadius: rect.width / 2,
                                 options: [])
        context.restoreGState()

        context.setShadow(offset: CGSize.zero, blur: 0, color: nil)

        context.setStrokeColor(UIColor.white.withAlphaComponent(0.8).cgColor)
        context.setLineWidth(3)
        context.strokeEllipse(in: rect.insetBy(dx: 2, dy: 2))

        context.setStrokeColor(UIColor.systemYellow.withAlphaComponent(0.4).cgColor)
        context.setLineWidth(1)
        context.strokeEllipse(in: rect.insetBy(dx: 5, dy: 5))
    }

    // MARK: - Premium Helper Methods

    private static func addPremiumTextureOverlay(to context: CGContext, in size: CGSize) {
        for _ in 0..<200 {
            let x = CGFloat.random(in: 0...size.width)
            let y = CGFloat.random(in: 0...size.height)
            let alpha = Double.random(in: 0.02...0.08)
            let particleSize = CGFloat.random(in: 1...4)

            context.setFillColor(UIColor.white.withAlphaComponent(alpha).cgColor)
            context.fillEllipse(in: CGRect(x: x, y: y, width: particleSize, height: particleSize))
        }

        for _ in 0..<15 {
            let startX = CGFloat.random(in: 0...size.width)
            let startY = CGFloat.random(in: 0...size.height)
            let endX = startX + CGFloat.random(in: -100...100)
            let endY = startY + CGFloat.random(in: -100...100)

            context.setStrokeColor(UIColor.white.withAlphaComponent(0.03).cgColor)
            context.setLineWidth(1)
            context.move(to: CGPoint(x: startX, y: startY))
            context.addLine(to: CGPoint(x: endX, y: endY))
            context.strokePath()
        }
    }

    private static func addStellarParticles(to context: CGContext, in size: CGSize) {
        for _ in 0..<50 {
            let x = CGFloat.random(in: 0...size.width)
            let y = CGFloat.random(in: 0...size.height)
            let starSize = CGFloat.random(in: 2...6)
            let alpha = Double.random(in: 0.3...0.9)

            context.setStrokeColor(UIColor.white.withAlphaComponent(alpha).cgColor)
            context.setLineWidth(1)

            context.move(to: CGPoint(x: x - starSize, y: y))
            context.addLine(to: CGPoint(x: x + starSize, y: y))
            context.strokePath()

            context.move(to: CGPoint(x: x, y: y - starSize))
            context.addLine(to: CGPoint(x: x, y: y + starSize))
            context.strokePath()

            context.setFillColor(UIColor.white.withAlphaComponent(alpha).cgColor)
            context.fillEllipse(in: CGRect(x: x - 1, y: y - 1, width: 2, height: 2))
        }

        for _ in 0..<25 {
            let x = CGFloat.random(in: 0...size.width)
            let y = CGFloat.random(in: 0...size.height)
            let starSize = CGFloat.random(in: 3...8)
            let alpha = Double.random(in: 0.4...0.8)

            context.setStrokeColor(UIColor.systemYellow.withAlphaComponent(alpha).cgColor)
            context.setLineWidth(1.5)

            context.move(to: CGPoint(x: x - starSize, y: y))
            context.addLine(to: CGPoint(x: x + starSize, y: y))
            context.strokePath()

            context.move(to: CGPoint(x: x, y: y - starSize))
            context.addLine(to: CGPoint(x: x, y: y + starSize))
            context.strokePath()

            context.move(to: CGPoint(x: x - starSize * 0.7, y: y - starSize * 0.7))
            context.addLine(to: CGPoint(x: x + starSize * 0.7, y: y + starSize * 0.7))
            context.strokePath()

            context.move(to: CGPoint(x: x - starSize * 0.7, y: y + starSize * 0.7))
            context.addLine(to: CGPoint(x: x + starSize * 0.7, y: y - starSize * 0.7))
            context.strokePath()
        }
    }

    private static func addLightRays(to context: CGContext, in size: CGSize) {
        let centerX = size.width / 2
        let centerY = size.height * 0.42

        for i in 0..<12 {
            let angle = Double(i) * .pi / 6
            let rayLength = size.width * 0.8

            let endX = centerX + cos(angle) * rayLength
            let endY = centerY + sin(angle) * rayLength

            let rayGradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                       colors: [
                                           UIColor.white.withAlphaComponent(0.15).cgColor,
                                           UIColor.systemYellow.withAlphaComponent(0.08).cgColor,
                                           UIColor.clear.cgColor
                                       ] as CFArray,
                                       locations: [0.0, 0.3, 1.0])!

            context.saveGState()

            let rayPath = UIBezierPath()
            rayPath.move(to: CGPoint(x: centerX, y: centerY))
            rayPath.addLine(to: CGPoint(x: centerX + cos(angle + 0.05) * rayLength, y: centerY + sin(angle + 0.05) * rayLength))
            rayPath.addLine(to: CGPoint(x: endX, y: endY))
            rayPath.addLine(to: CGPoint(x: centerX + cos(angle - 0.05) * rayLength, y: centerY + sin(angle - 0.05) * rayLength))
            rayPath.close()

            context.addPath(rayPath.cgPath)
            context.clip()

            context.drawLinearGradient(rayGradient,
                                     start: CGPoint(x: centerX, y: centerY),
                                     end: CGPoint(x: endX, y: endY),
                                     options: [])

            context.restoreGState()
        }
    }

    private static func drawPremiumFlameShapes(in context: CGContext, centerX: CGFloat, centerY: CGFloat) {
        let flameConfigs = [
            (width: 180, height: 240, colors: [UIColor.systemRed, UIColor.systemOrange, UIColor.systemYellow], alpha: 0.5),
            (width: 220, height: 280, colors: [UIColor.systemOrange, UIColor.systemYellow, UIColor.white], alpha: 0.4),
            (width: 260, height: 320, colors: [UIColor.systemYellow, UIColor.white, UIColor.systemYellow], alpha: 0.35),
            (width: 300, height: 360, colors: [UIColor.white, UIColor.systemYellow, UIColor.systemOrange], alpha: 0.3),
            (width: 340, height: 400, colors: [UIColor.systemYellow, UIColor.white, UIColor.systemPink], alpha: 0.25),
            (width: 380, height: 440, colors: [UIColor.white, UIColor.systemPink, UIColor.systemPurple], alpha: 0.2)
        ]

        for (_, config) in flameConfigs.enumerated() {
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                    colors: config.colors.map { $0.withAlphaComponent(config.alpha).cgColor } as CFArray,
                                    locations: [0.0, 0.5, 1.0])!

            let flamePath = createFlameShape(centerX: centerX, centerY: centerY, width: config.width, height: config.height)

            context.saveGState()
            context.addPath(flamePath)
            context.clip()
            context.drawLinearGradient(gradient,
                                     start: CGPoint(x: centerX, y: centerY + CGFloat(config.height)/2),
                                     end: CGPoint(x: centerX, y: centerY - CGFloat(config.height)/2),
                                     options: [])
            context.restoreGState()
        }
    }

    private static func createFlameShape(centerX: CGFloat, centerY: CGFloat, width: Int, height: Int) -> CGPath {
        let path = UIBezierPath()
        let w = CGFloat(width)
        let h = CGFloat(height)

        path.move(to: CGPoint(x: centerX, y: centerY + h/2))

        path.addCurve(
            to: CGPoint(x: centerX - w/2, y: centerY),
            controlPoint1: CGPoint(x: centerX - w/3, y: centerY + h/3),
            controlPoint2: CGPoint(x: centerX - w/2, y: centerY + h/6)
        )

        path.addCurve(
            to: CGPoint(x: centerX, y: centerY - h/2),
            controlPoint1: CGPoint(x: centerX - w/3, y: centerY - h/3),
            controlPoint2: CGPoint(x: centerX - w/6, y: centerY - h/2)
        )

        path.addCurve(
            to: CGPoint(x: centerX + w/2, y: centerY),
            controlPoint1: CGPoint(x: centerX + w/6, y: centerY - h/2),
            controlPoint2: CGPoint(x: centerX + w/3, y: centerY - h/3)
        )

        path.addCurve(
            to: CGPoint(x: centerX, y: centerY + h/2),
            controlPoint1: CGPoint(x: centerX + w/2, y: centerY + h/6),
            controlPoint2: CGPoint(x: centerX + w/3, y: centerY + h/3)
        )

        path.close()
        return path.cgPath
    }
}
