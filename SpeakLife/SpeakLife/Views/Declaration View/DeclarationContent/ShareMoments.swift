//
//  ShareMoments.swift
//  SpeakLife
//
//  The story card offered where the feeling is, instead of behind a share icon:
//
//   - The Daily Burst ends with "Send this burst to a friend in need": all of
//     its declarations as story cards, in order, in one share.
//   - The declaration feed shows a quiet "Share today's word" chip once a day,
//     after the fifth declaration.
//
//  The policy pieces here are pure so they can be tested without a view.
//

import SwiftUI
import UIKit

// MARK: - Burst share content

enum BurstShareContent {

    /// A burst slat as a `Declaration`, so it renders through the same story
    /// card as the feed. An empty reference becomes nil, so a line the user
    /// wrote themselves gets no empty gold reference line.
    static func declaration(from line: BurstDeclaration) -> Declaration {
        let reference = line.verse.trimmingCharacters(in: .whitespacesAndNewlines)
        return Declaration(
            text: line.text,
            book: reference.isEmpty ? nil : reference,
            bibleVerseText: line.scripture,
            category: line.category ?? .faith
        )
    }

    /// Every slat that has words on it, in the order it was spoken.
    static func declarations(from lines: [BurstDeclaration]) -> [Declaration] {
        lines
            .filter { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .map(declaration(from:))
    }

    /// The words that travel with the cards. An invitation to speak, not a
    /// score. The link is added by `ReferralShareText`, and only when the
    /// cards go to a messaging app.
    static func message(cardCount: Int) -> String {
        switch cardCount {
        case ..<1:  return "I'm standing with you today. Speak God's promises out loud over your life."
        case 1:     return "I'm standing with you today. Here is a promise to speak out loud over your life."
        default:    return "I'm standing with you today. Here are \(cardCount) promises to speak out loud over your life."
        }
    }
}

// MARK: - Burst share controller

/// Renders a burst as story cards and hands them to the share sheet.
///
/// Owned by `DailyDeclarationBurstView` so the eighth slat and the completion
/// screen share through one path and one in-flight guard.
@MainActor
final class BurstShareController: ObservableObject {

    /// True from the tap until the share sheet is on screen. Drives the
    /// button's progress state and blocks a second tap.
    @Published private(set) var isPreparing = false

    /// - Parameters:
    ///   - lines: the burst's slats, in the order spoken.
    ///   - theme: the burst's theme, the link's campaign.
    ///   - background: the speaker's theme photo, or nil for the gradient.
    ///   - surface: where the tap came from, for analytics.
    ///   - completion: true when the share sheet reports a completed share.
    func share(lines: [BurstDeclaration],
               theme: DeclarationCategory,
               background: UIImage?,
               surface: String,
               completion: @escaping (Bool) -> Void) {
        guard !isPreparing else { return }
        isPreparing = true

        let declarations = BurstShareContent.declarations(from: lines)
        AnalyticsService.shared.track("burst_share_tapped", parameters: [
            "theme": theme.rawValue,
            "card_count": declarations.count,
            "surface": surface
        ])

        Task { @MainActor in
            // A real pause, not just a yield: the main run loop has to turn
            // for the button's progress state to draw before the first render.
            try? await Task.sleep(nanoseconds: 50_000_000)

            let files = await Self.renderCards(declarations, background: background)
            let link = ReferralLink.url(.dailyBurst, campaign: theme.rawValue)
            let message = ReferralShareText(BurstShareContent.message(cardCount: files.count), link: link)

            // Array order is the order the recipient sees them in.
            var items: [Any] = files
            items.append(message)
            let presented = Self.present(items: items) { activityType, completed in
                AnalyticsService.shared.track("burst_shared", parameters: [
                    "completed": completed,
                    "activity_type": activityType?.rawValue ?? "none",
                    "card_count": files.count,
                    "theme": theme.rawValue,
                    "surface": surface
                ])
                if completed {
                    AnalyticsService.shared.trackShare(
                        contentType: "daily_burst",
                        contentId: theme.rawValue,
                        shareMethod: activityType?.rawValue ?? "share_sheet",
                        metadata: ["card_count": files.count, "surface": surface]
                    )
                    UserDefaults.standard.set(
                        UserDefaults.standard.integer(forKey: "totalSocialShares") + 1,
                        forKey: "totalSocialShares"
                    )
                    StreakIntegrationManager.notifyAffirmationShared()
                }
                completion(completed)
            }
            self.isPreparing = false
            if !presented { completion(false) }
        }
    }

    /// One JPEG file per card, numbered so their order survives any app that
    /// sorts attachments by name. JPEG at 0.9 keeps seven full-size cards
    /// light enough for Messages; PNG would be several times larger.
    private static func renderCards(_ declarations: [Declaration],
                                    background: UIImage?) async -> [URL] {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("BurstCards", isDirectory: true)
        // Last share's cards go first, so an old card can never ride along.
        try? FileManager.default.removeItem(at: directory)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        var files: [URL] = []
        let total = declarations.count
        for (offset, declaration) in declarations.enumerated() {
            let position = DeclarationStoryCard.Position(number: offset + 1, total: total)
            if let image = DeclarationStoryCard.render(declaration: declaration,
                                                       background: background,
                                                       position: position),
               let data = image.jpegData(compressionQuality: 0.9) {
                let file = directory.appendingPathComponent("SpeakLife-\(offset + 1)-of-\(total).jpg")
                if (try? data.write(to: file, options: .atomic)) != nil {
                    files.append(file)
                }
            }
            // Each card is a full 1080x1920 render. Pause between them so the
            // run loop turns: the spinner keeps moving and touches still land.
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        return files
    }

    /// Presents the system share sheet over whatever is on top. False when
    /// there is nowhere to present it, so the caller is never left waiting.
    private static func present(
        items: [Any],
        onFinish: @escaping (UIActivity.ActivityType?, Bool) -> Void
    ) -> Bool {
        guard let scene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive || $0.activationState == .foregroundInactive })
                as? UIWindowScene,
              let root = scene.windows.first(where: \.isKeyWindow)?.rootViewController
                ?? scene.windows.first?.rootViewController else {
            return false
        }
        var top = root
        while let presented = top.presentedViewController {
            top = presented
        }

        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        controller.completionWithItemsHandler = { activityType, completed, _, _ in
            DispatchQueue.main.async { onFinish(activityType, completed) }
        }
        if let popover = controller.popoverPresentationController {
            popover.sourceView = top.view
            popover.sourceRect = CGRect(x: top.view.bounds.midX, y: top.view.bounds.midY,
                                        width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        top.present(controller, animated: true)
        return true
    }
}

// MARK: - Feed nudge policy

/// When the feed shows "Share today's word".
///
/// After the fifth new declaration reached in a day, at most once a day, and
/// never on the day the app was installed: someone still finding their way
/// around should not be asked to promote it.
struct FeedShareNudgePolicy {

    static let threshold = 5

    static let countKey = "feedShareNudge.count"
    static let countDayKey = "feedShareNudge.countDay"
    static let shownDayKey = "feedShareNudge.shownDay"

    let defaults: UserDefaults
    var calendar: Calendar = .current

    /// Counts one new declaration reached in the feed. True when this is the
    /// moment to show the nudge. The day is recorded as shown before
    /// returning, so it answers true at most once a day.
    func recordDeclarationReached(now: Date = Date(), installDate: Date) -> Bool {
        let today = Self.dayStamp(now, calendar: calendar)
        let sameDay = defaults.string(forKey: Self.countDayKey) == today
        let count = (sameDay ? defaults.integer(forKey: Self.countKey) : 0) + 1
        defaults.set(count, forKey: Self.countKey)
        defaults.set(today, forKey: Self.countDayKey)

        guard count >= Self.threshold,
              defaults.string(forKey: Self.shownDayKey) != today,
              !calendar.isDate(installDate, inSameDayAs: now) else {
            return false
        }
        defaults.set(today, forKey: Self.shownDayKey)
        return true
    }

    /// A local calendar day, so "once a day" follows the user's own midnight.
    static func dayStamp(_ date: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return "\(parts.year ?? 0)-\(parts.month ?? 0)-\(parts.day ?? 0)"
    }
}

// MARK: - Feed nudge chip

/// A small gold-outlined capsule that sits above the feed's action buttons.
/// Quiet on purpose: it is an offer, not a banner.
struct ShareNudgeChip: View {

    let onShare: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: DS.Spacing.xs) {
            Button(action: onShare) {
                HStack(spacing: 6) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Share today's word")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                }
                .foregroundStyle(DS.Palette.gold)
                .padding(.vertical, 10)
                .contentShape(Rectangle())
            }
            // The share itself plays the solid tap, so no second buzz here.
            .buttonStyle(.dsPressable(feel: .tapLight, haptics: false))

            Rectangle()
                .fill(DS.Palette.gold.opacity(0.35))
                .frame(width: 1, height: 14)

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white.opacity(0.6))
                    .frame(width: 28, height: 34)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.dsPressable(feel: .tapLight))
            .accessibilityLabel("Dismiss")
        }
        .padding(.leading, DS.Spacing.md)
        .padding(.trailing, DS.Spacing.xxs)
        .background(Capsule().fill(.ultraThinMaterial))
        .overlay(Capsule().strokeBorder(DS.Palette.gold.opacity(0.7), lineWidth: 1))
        .shadow(color: .black.opacity(0.25), radius: 10, y: 4)
    }
}

#Preview("Share nudge chip") {
    ZStack {
        LinearGradient(colors: [.indigo, .black], startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
        ShareNudgeChip(onShare: {}, onDismiss: {})
    }
}
