//
//  ShareMoments.swift
//  SpeakLife
//
//  The story card offered where the feeling is, instead of behind a share icon:
//
//   - The Daily Burst ends with "Send this burst to a friend in need": all of
//     its declarations as story cards, in order, in one share. The finish
//     screen then shows the same cards in a carousel, to send again or to
//     share one at a time. The cards are rendered once per burst.
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

// MARK: - Burst cards

/// One rendered burst card.
///
/// The full 1080x1920 image lives only on disk as a JPEG, which is what gets
/// shared. In memory there is just a thumbnail at the size the carousel draws
/// it, so seven cards cost a few megabytes instead of fifty.
struct BurstCard: Identifiable, Equatable {
    /// 1-based position in the burst, also the carousel id.
    let number: Int
    /// The declaration on the card, for VoiceOver.
    let text: String
    let thumbnail: UIImage
    let file: URL

    var id: Int { number }

    /// The full card, read back from disk for a share that needs an image
    /// rather than a file (Instagram Stories).
    func fullImage() -> UIImage? {
        UIImage(contentsOfFile: file.path)
    }
}

// MARK: - Burst share controller

/// Renders a burst's cards once and shares them.
///
/// Owned by `DailyDeclarationBurstView` and started shortly after the eighth
/// slat appears, so the cards are usually ready by the time anyone taps. The
/// eighth slat's send, the finish screen's carousel and its share buttons all
/// read the same cards and go through one in-flight guard.
@MainActor
final class BurstShareController: ObservableObject {

    /// Cards rendered so far, in order. Grows one at a time so the carousel
    /// can show the first card while the rest are still drawing.
    @Published private(set) var cards: [BurstCard] = []
    /// How many cards this burst will have once rendering is done.
    @Published private(set) var expectedCount = 0
    @Published private(set) var isRenderingDone = false
    /// True from a share tap until the share sheet is on screen. Drives the
    /// buttons' progress state and blocks a second tap.
    @Published private(set) var isPreparing = false
    /// True while a share sheet this controller presented is on screen.
    @Published private(set) var isSheetPresented = false

    /// Preparing or showing a share sheet. Anything else that wants to present
    /// over the burst (the badge unlock) waits until this is false.
    var isBusy: Bool { isPreparing || isSheetPresented }

    private var renderTask: Task<Void, Never>?
    private var theme: DeclarationCategory = .faith

    /// Starts rendering this burst's cards. Safe to call more than once: only
    /// the first call renders.
    ///
    /// - Parameters:
    ///   - thumbnailWidth: the carousel's card width in pixels, so the
    ///     thumbnail is never upscaled on screen.
    ///   - startDelay: lets an entrance animation finish before the first
    ///     full-size render takes the main thread.
    func prepare(lines: [BurstDeclaration], theme: DeclarationCategory, background: UIImage?,
                 thumbnailWidth: CGFloat, startDelay: TimeInterval = 0) {
        guard renderTask == nil else { return }
        self.theme = theme
        let declarations = BurstShareContent.declarations(from: lines)
        expectedCount = declarations.count

        let width = min(max(thumbnailWidth.rounded(.up), 1), DeclarationStoryCard.size.width)
        let thumbnailSize = CGSize(width: width, height: (width * 16 / 9).rounded(.up))

        renderTask = Task { @MainActor [weak self] in
            if startDelay > 0 {
                try? await Task.sleep(nanoseconds: UInt64(startDelay * 1_000_000_000))
            }
            let directory = FileManager.default.temporaryDirectory
                .appendingPathComponent("BurstCards", isDirectory: true)
            // The last burst's cards go first, so an old card can never ride along.
            try? FileManager.default.removeItem(at: directory)
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

            let total = declarations.count
            for (offset, declaration) in declarations.enumerated() {
                guard !Task.isCancelled else { return }

                // Only the render itself needs the main actor (`ImageRenderer`).
                let position = DeclarationStoryCard.Position(number: offset + 1, total: total)
                guard let image = DeclarationStoryCard.render(declaration: declaration,
                                                              background: background,
                                                              position: position) else { continue }
                // Numbered so the order survives any app that sorts by name.
                let file = directory.appendingPathComponent("SpeakLife-\(offset + 1)-of-\(total).jpg")

                // Encoding, writing and downscaling run off the main thread.
                let thumbnail = await Task.detached(priority: .userInitiated) { () -> UIImage? in
                    // JPEG at 0.9 keeps seven full cards light enough for
                    // Messages; PNG would be several times larger.
                    guard let data = image.jpegData(compressionQuality: 0.9),
                          (try? data.write(to: file, options: .atomic)) != nil else { return nil }
                    return BurstShareController.downscale(image, to: thumbnailSize)
                }.value

                guard let self else { return }
                if let thumbnail {
                    self.cards.append(BurstCard(number: offset + 1, text: declaration.text,
                                                thumbnail: thumbnail, file: file))
                }
            }
            self?.isRenderingDone = true
        }
    }

    /// Shares every card, in order, with the invitation and tracked link.
    ///
    /// - Parameter completion: true when the share sheet reports a completed share.
    func shareAll(surface: String, completion: @escaping (Bool) -> Void) {
        guard !isBusy else { return }
        isPreparing = true
        let theme = self.theme
        AnalyticsService.shared.track("burst_share_tapped", parameters: [
            "theme": theme.rawValue,
            "card_count": expectedCount,
            "surface": surface
        ])
        // Kept so the "burst shares before and after" comparison stays continuous.
        AnalyticsService.shared.track("daily_burst_shared", parameters: [
            "method": "all_cards",
            "card_count": expectedCount,
            "surface": surface
        ])

        Task { @MainActor in
            // Let the button's progress state draw, then wait for any cards
            // still rendering.
            try? await Task.sleep(nanoseconds: 50_000_000)
            await self.renderTask?.value

            let files = self.cards.map(\.file)
            let link = ReferralLink.url(.dailyBurst, campaign: theme.rawValue)
            let message = ReferralShareText(BurstShareContent.message(cardCount: files.count), link: link)

            // Array order is the order the recipient sees them in.
            var items: [Any] = files
            items.append(message)
            let presented = self.present(items: items) { activityType, completed in
                AnalyticsService.shared.track("burst_shared", parameters: [
                    "completed": completed,
                    "activity_type": activityType?.rawValue ?? "none",
                    "card_count": files.count,
                    "theme": theme.rawValue,
                    "surface": surface
                ])
                if completed {
                    Self.recordCompletedShare(contentId: theme.rawValue,
                                              method: activityType?.rawValue ?? "share_sheet",
                                              metadata: ["card_count": files.count, "surface": surface])
                }
                completion(completed)
            }
            self.isPreparing = false
            if !presented { completion(false) }
        }
    }

    /// How one card leaves the finish screen.
    enum SingleShareMethod: String {
        case shareSheet = "share_sheet"
        case instagramStories = "instagram_stories"
    }

    /// Shares the one card the user is looking at.
    func shareCard(_ card: BurstCard, method: SingleShareMethod) {
        guard !isBusy else { return }
        let theme = self.theme
        AnalyticsService.shared.track("burst_card_shared", parameters: [
            "index": card.number,
            "method": method.rawValue,
            "theme": theme.rawValue
        ])
        AnalyticsService.shared.track("daily_burst_shared", parameters: [
            "method": "one_card_\(method.rawValue)",
            "card_count": 1,
            "surface": "burst_completion_screen"
        ])

        switch method {
        case .instagramStories:
            // The Stories pasteboard carries only the image, so no text. Only
            // a real handoff to Instagram counts; the Photos fallback does not.
            guard let image = card.fullImage(), shareToInstagramStories(image: image) else { return }
            Self.recordCompletedShare(contentId: theme.rawValue, method: method.rawValue,
                                      metadata: ["card_index": card.number])
        case .shareSheet:
            let link = ReferralLink.url(.dailyBurst, campaign: theme.rawValue)
            let message = ReferralShareText("Speak this one out loud with me 🙏", link: link)
            _ = present(items: [card.file, message]) { activityType, completed in
                guard completed else { return }
                Self.recordCompletedShare(contentId: theme.rawValue,
                                          method: activityType?.rawValue ?? "share_sheet",
                                          metadata: ["card_index": card.number])
            }
        }
    }

    // MARK: Helpers

    /// Same bookkeeping as the feed's share, so badges and the share measure
    /// count a burst share like any other.
    private static func recordCompletedShare(contentId: String, method: String,
                                             metadata: [String: Any]) {
        AnalyticsService.shared.trackShare(
            contentType: "daily_burst",
            contentId: contentId,
            shareMethod: method,
            metadata: metadata
        )
        UserDefaults.standard.set(
            UserDefaults.standard.integer(forKey: "totalSocialShares") + 1,
            forKey: "totalSocialShares"
        )
        StreakIntegrationManager.notifyAffirmationShared()
    }

    /// Off the main actor: called from a detached task.
    nonisolated static func downscale(_ image: UIImage, to size: CGSize) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }

    /// Presents the system share sheet over whatever is on top. False when
    /// there is nowhere to present it, so the caller is never left waiting.
    private func present(
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
        controller.completionWithItemsHandler = { [weak self] activityType, completed, _, _ in
            Task { @MainActor in
                self?.isSheetPresented = false
                onFinish(activityType, completed)
            }
        }
        if let popover = controller.popoverPresentationController {
            popover.sourceView = top.view
            popover.sourceRect = CGRect(x: top.view.bounds.midX, y: top.view.bounds.midY,
                                        width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        isSheetPresented = true
        top.present(controller, animated: true)
        return true
    }
}

// MARK: - Finish screen cards

/// The burst's cards on the finish screen: a paged carousel with the
/// neighbours peeking in, page dots and "Share this one". The screen's primary
/// action, "Send these to a friend" (`BurstSendAllButton`), is pinned in the
/// footer so it is never below the fold.
///
/// Cards arrive one by one, so every slot not yet rendered is a shimmering
/// placeholder of the same size: the carousel never jumps and is never blank.
struct BurstCardsSection: View {

    @ObservedObject var controller: BurstShareController
    /// Width of the space the carousel spans, usually the screen.
    let width: CGFloat
    /// Card height, already capped to the room the screen has.
    let cardHeight: CGFloat

    @State private var centered: Int? = 1
    /// Every card that has been centred, for `burst_cards_viewed`.
    @State private var seen: Set<Int> = [1]
    @State private var didReportShown = false
    @State private var didReportViewed = false

    private var cardWidth: CGFloat { cardHeight * 9 / 16 }

    /// One slot per card to come while rendering. Once rendering is done, only
    /// the cards that actually rendered, so a failed card never leaves a
    /// placeholder shimmering forever.
    private var slotNumbers: [Int] {
        if controller.isRenderingDone {
            return controller.cards.map(\.number)
        }
        return Array(1...max(controller.expectedCount, 1))
    }
    private var slotCount: Int { slotNumbers.count }

    private var centeredCard: BurstCard? {
        controller.cards.first { $0.number == (centered ?? 1) }
    }

    var body: some View {
        VStack(spacing: DS.Spacing.sm) {
            carousel
            pageDots
            shareThisOne
        }
        .onChange(of: centered) { _, newValue in
            guard let newValue else { return }
            Juice.play(.tapLight)
            seen.insert(newValue)
        }
        .onAppear {
            guard !didReportShown else { return }
            didReportShown = true
            AnalyticsService.shared.track("share_prompt_shown", parameters: [
                "surface": "burst_completion_screen",
                "card_count": slotCount
            ])
        }
        .onDisappear {
            guard !didReportViewed else { return }
            didReportViewed = true
            AnalyticsService.shared.track("burst_cards_viewed", parameters: [
                "cards_seen": seen.count,
                "card_count": slotCount
            ])
        }
    }

    private var carousel: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: DS.Spacing.md) {
                ForEach(slotNumbers, id: \.self) { number in
                    slot(number)
                        .frame(width: cardWidth, height: cardHeight)
                        .scrollTransition(axis: .horizontal) { content, phase in
                            content
                                .scaleEffect(phase.isIdentity ? 1 : 0.9)
                                .opacity(phase.isIdentity ? 1 : 0.65)
                        }
                        .id(number)
                }
            }
            .scrollTargetLayout()
        }
        .contentMargins(.horizontal, max((width - cardWidth) / 2, 0), for: .scrollContent)
        .scrollTargetBehavior(.viewAligned)
        .scrollPosition(id: $centered)
        // The cards' shadows reach past the scroll view's bounds.
        .scrollClipDisabled()
        .frame(height: cardHeight)
    }

    @ViewBuilder
    private func slot(_ number: Int) -> some View {
        let shape = RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
        if let card = controller.cards.first(where: { $0.number == number }) {
            Image(uiImage: card.thumbnail)
                .resizable()
                .scaledToFill()
                .clipShape(shape)
                .overlay(shape.stroke(Color.white.opacity(0.18), lineWidth: 1))
                .shadow(color: .black.opacity(0.45), radius: 14, y: 8)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Card \(number) of \(slotCount). \(card.text)")
                .transition(.opacity)
        } else {
            ShimmerPlaceholder(shape: shape)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Preparing card \(number)")
        }
    }

    private var pageDots: some View {
        HStack(spacing: 6) {
            ForEach(slotNumbers, id: \.self) { number in
                Capsule()
                    .fill(number == (centered ?? 1) ? DS.Palette.gold : Color.white.opacity(0.3))
                    .frame(width: number == (centered ?? 1) ? 16 : 6, height: 6)
            }
        }
        .padding(.top, DS.Spacing.xs)
        .animation(DS.Motion.quick, value: centered)
        .accessibilityHidden(true)
    }

    private var shareThisOne: some View {
        Menu {
            Button {
                if let card = centeredCard { controller.shareCard(card, method: .instagramStories) }
            } label: {
                Label("Instagram Stories", systemImage: "camera.circle")
            }
            Button {
                if let card = centeredCard { controller.shareCard(card, method: .shareSheet) }
            } label: {
                Label("Other apps", systemImage: "square.and.arrow.up")
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "square.and.arrow.up")
                Text("Share this one")
            }
            .font(.system(size: 15, weight: .semibold))
            .foregroundColor(DS.Palette.gold)
            .frame(height: 44)
            .padding(.horizontal, DS.Spacing.lg)
            .contentShape(Rectangle())
        }
        // Only once the card in the middle is actually drawn.
        .disabled(centeredCard == nil || controller.isBusy)
        .opacity(centeredCard == nil ? 0.5 : 1)
    }
}

/// The finish screen's primary action: every card, to a friend.
struct BurstSendAllButton: View {

    @ObservedObject var controller: BurstShareController
    /// "Send these to a friend", or "Send to someone else" once one has gone.
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DS.Spacing.xs) {
                if controller.isPreparing {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .controlSize(.small)
                    Text("Preparing your cards…")
                } else {
                    Image(systemName: "paperplane.fill")
                    Text(title)
                }
            }
            .font(.system(size: 17, weight: .semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .foregroundColor(.white)
            .frame(maxWidth: 360)
            .frame(height: 52)
            .background(RoundedRectangle(cornerRadius: 26).fill(DS.Gradient.ember))
            .shadow(color: Color(red: 1.0, green: 0.34, blue: 0.13).opacity(0.35), radius: 10, y: 5)
        }
        .buttonStyle(.dsPressable(feel: .tapSolid))
        .disabled(controller.isBusy || controller.expectedCount == 0)
        .padding(.horizontal, DS.Spacing.lg)
    }
}

/// A card-shaped placeholder with a slow light sweep, shown while a card renders.
private struct ShimmerPlaceholder: View {

    let shape: RoundedRectangle
    @State private var sweep = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        shape
            .fill(Color.white.opacity(0.08))
            .overlay(
                GeometryReader { proxy in
                    LinearGradient(colors: [.clear, Color.white.opacity(0.14), .clear],
                                   startPoint: .leading, endPoint: .trailing)
                        .frame(width: proxy.size.width * 0.6)
                        .offset(x: sweep ? proxy.size.width : -proxy.size.width * 0.6)
                }
                .clipShape(shape)
            )
            .overlay(shape.stroke(Color.white.opacity(0.12), lineWidth: 1))
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) {
                    sweep = true
                }
            }
    }
}

/// The finish screen's card area as the burst shows it: real cards rendering
/// into the carousel, with the send button pinned underneath.
private struct BurstFinishPreview: View {

    @StateObject private var controller = BurstShareController()

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                LinearGradient(colors: [Color(red: 0.08, green: 0.05, blue: 0.20), .black],
                               startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
                VStack(spacing: DS.Spacing.md) {
                    ScrollView {
                        VStack(spacing: DS.Spacing.lg) {
                            Text("Truth Spoken!")
                                .font(.system(size: 30, weight: .black))
                                .foregroundColor(.white)
                            BurstCardsSection(controller: controller, width: proxy.size.width,
                                              cardHeight: proxy.size.height * 0.5)
                        }
                        .padding(.top, DS.Spacing.lg)
                    }
                    BurstSendAllButton(controller: controller, title: "Send these to a friend") {}
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            controller.prepare(lines: BurstSessionBuilder.fallback, theme: .faith,
                               background: nil, thumbnailWidth: 700)
        }
    }
}

#Preview("Burst finish cards") {
    BurstFinishPreview()
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
