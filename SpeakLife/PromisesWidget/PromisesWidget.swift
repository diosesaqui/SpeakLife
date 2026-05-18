//
//  PromisesWidget.swift
//  PromisesWidget
//
//  Created by Riccardo Washington on 11/2/22.
//

import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Constants

private enum WidgetConstants {
    static let placeholderText = "Loading…"

    enum Layout {
        static let smallPadding: CGFloat = 14
        static let mediumPadding: CGFloat = 16
        static let largePadding: CGFloat = 20
        static let actionRowSpacing: CGFloat = 8
        static let buttonHitTarget: CGFloat = 44   // Apple HIG minimum
        static let buttonIconSize: CGFloat = 17
    }
}

// MARK: - Declaration Store

/// Single source of truth for what the widget displays.
/// Reads the JSON-encoded record set written by the app; falls back to the legacy string array.
struct WidgetDeclarationStore {
    let records: [WidgetDeclaration]

    static func load() -> WidgetDeclarationStore {
        let defaults = UserDefaults.widgetGroup

        if let data = defaults.data(forKey: WidgetSharedConstants.Keys.syncedRecords),
           let decoded = try? JSONDecoder().decode([WidgetDeclaration].self, from: data),
           !decoded.isEmpty {
            return WidgetDeclarationStore(records: decoded)
        }

        // Legacy fallback: array of text-only declarations
        if let texts = defaults.stringArray(forKey: WidgetSharedConstants.Keys.syncedPromises),
           !texts.isEmpty {
            let legacy = texts.map { WidgetDeclaration(text: $0, category: "faith") }
            return WidgetDeclarationStore(records: legacy)
        }

        return WidgetDeclarationStore(records: [.fallback])
    }

    /// Deterministic daily verse: same per device per day. The user advances with the
    /// rotate button (offset), and the daily seed picks the next verse from the (stably-sorted)
    /// pool — guaranteeing the same verse all day even if the app re-syncs in between.
    func declaration(for date: Date, offset: Int = 0) -> WidgetDeclaration {
        guard !records.isEmpty else { return .fallback }
        let filtered = filteredBySelectedCategories(records)
        let pool = filtered.isEmpty ? records : filtered

        let calendar = Calendar.current
        let dayOfYear = calendar.ordinality(of: .day, in: .year, for: date) ?? 1
        let year = calendar.component(.year, from: date)
        let seed = abs((dayOfYear &* 1_000_003) &+ (year &* 31) &+ offset)
        return pool[seed % pool.count]
    }

    private func filteredBySelectedCategories(_ all: [WidgetDeclaration]) -> [WidgetDeclaration] {
        let selected = UserDefaults.widgetGroup.stringArray(forKey: WidgetSharedConstants.Keys.selectedCategories) ?? []
        guard !selected.isEmpty else { return [] }
        let normalized = Set(selected.map { $0.lowercased() })
        return all.filter { normalized.contains($0.category.lowercased()) }
    }
}

// MARK: - Timeline Provider

struct Provider: TimelineProvider {

    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(
            date: Date(),
            declaration: WidgetDeclaration(text: WidgetConstants.placeholderText, category: "faith"),
            isFavorite: false
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        completion(currentEntry(at: Date(), store: WidgetDeclarationStore.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SimpleEntry>) -> ()) {
        // Decode the record blob exactly once per timeline build.
        let store = WidgetDeclarationStore.load()
        let entry = currentEntry(at: Date(), store: store)

        // Single entry; the verse is stable for the day. System reloads at midnight.
        let startOfTomorrow = Calendar.current.nextDate(
            after: Date(),
            matching: DateComponents(hour: 0, minute: 1),
            matchingPolicy: .nextTime
        ) ?? Date().addingTimeInterval(60 * 60)

        completion(Timeline(entries: [entry], policy: .after(startOfTomorrow)))
    }

    private func currentEntry(at date: Date, store: WidgetDeclarationStore) -> SimpleEntry {
        let offset = UserDefaults.widgetGroup.integer(forKey: WidgetSharedConstants.Keys.rotationOffset)
        let declaration = store.declaration(for: date, offset: offset)
        let favorites = Set(UserDefaults.widgetGroup.stringArray(forKey: WidgetSharedConstants.Keys.widgetFavorites) ?? [])
        return SimpleEntry(
            date: date,
            declaration: declaration,
            isFavorite: favorites.contains(declaration.text)
        )
    }
}

// MARK: - Timeline Entry

struct SimpleEntry: TimelineEntry {
    let date: Date
    let declaration: WidgetDeclaration
    let isFavorite: Bool
}

// MARK: - Widget Entry View

struct PromisesWidgetEntryView: View {
    @Environment(\.widgetFamily) var family: WidgetFamily
    let entry: Provider.Entry

    var body: some View {
        widgetContent
            .accessibilityElement(children: .combine)
            .accessibilityLabel(accessibilityText)
    }

    @ViewBuilder
    private var widgetContent: some View {
        switch family {
        case .accessoryCircular:
            circularLockScreenView
        case .accessoryRectangular:
            rectangularLockScreenView
        case .accessoryInline:
            inlineLockScreenView
        case .systemSmall:
            smallView
                .containerBackground(for: .widget) { ReverentBackground() }
        case .systemMedium:
            mediumView
                .containerBackground(for: .widget) { ReverentBackground() }
        case .systemLarge:
            largeView
                .containerBackground(for: .widget) { ReverentBackground() }
        default:
            smallView
                .containerBackground(for: .widget) { ReverentBackground() }
        }
    }

    // MARK: Home Screen Views

    private var smallView: some View {
        VStack(spacing: 6) {
            Spacer(minLength: 0)
            verseText(size: 14, weight: .medium, lineLimit: 7)
            if let book = entry.declaration.book, !book.isEmpty {
                bookReference(book, size: 10)
            }
            Spacer(minLength: 0)
        }
        .padding(WidgetConstants.Layout.smallPadding)
        .widgetURL(deepLinkURL)
    }

    private var mediumView: some View {
        VStack(spacing: 8) {
            Spacer(minLength: 0)
            verseText(size: 16, weight: .medium, lineLimit: 5)
            if let book = entry.declaration.book, !book.isEmpty {
                bookReference(book, size: 11)
            }
            Spacer(minLength: 0)
            actionRow
        }
        .padding(WidgetConstants.Layout.mediumPadding)
        .widgetURL(deepLinkURL)
    }

    private var largeView: some View {
        VStack(spacing: 14) {
            Spacer(minLength: 0)
            verseText(size: 21, weight: .semibold, lineLimit: 6)

            if let verse = entry.declaration.bibleVerseText, !verse.isEmpty {
                Text(verse)
                    .font(.system(size: 13, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(.white.opacity(0.78))
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .lineLimit(5)
                    .minimumScaleFactor(0.8)
                    .shadow(color: .black.opacity(0.25), radius: 2, x: 0, y: 1)
            }

            if let book = entry.declaration.book, !book.isEmpty {
                bookReference(book, size: 13)
            }

            Spacer(minLength: 0)
            actionRow
        }
        .padding(WidgetConstants.Layout.largePadding)
        .widgetURL(deepLinkURL)
    }

    // MARK: Lock Screen Views

    private var circularLockScreenView: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 1) {
                Image(systemName: timeBasedIcon)
                    .font(.system(size: 16, weight: .semibold))
                    .widgetAccentable()
                Text(circularLabel)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
    }

    /// Compact reference (e.g. "Rom 8:38", "1 Cor 13:4") for the tiny circular slot.
    private var circularLabel: String {
        if let book = entry.declaration.book, !book.isEmpty {
            return BookReferenceFormatter.short(book)
        }
        return entry.declaration.text.split(separator: " ").prefix(2).joined(separator: " ")
    }

    private var rectangularLockScreenView: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(entry.declaration.text)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .lineLimit(2)
                .minimumScaleFactor(0.85)
            if let book = entry.declaration.book, !book.isEmpty {
                Text(book)
                    .font(.system(size: 10, weight: .regular, design: .rounded))
                    .widgetAccentable()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var inlineLockScreenView: some View {
        HStack(spacing: 4) {
            Image(systemName: timeBasedIcon)
            Text(entry.declaration.text)
                .lineLimit(1)
        }
    }

    // MARK: Components

    private func verseText(size: CGFloat, weight: Font.Weight, lineLimit: Int) -> some View {
        Text(entry.declaration.text)
            .foregroundStyle(.white)
            .font(.system(size: size, weight: weight, design: .serif))
            .multilineTextAlignment(.center)
            .lineSpacing(3)
            .lineLimit(lineLimit)
            .minimumScaleFactor(0.75)
            .shadow(color: .black.opacity(0.3), radius: 3, x: 0, y: 1)
    }

    private func bookReference(_ book: String, size: CGFloat) -> some View {
        Text(book.uppercased())
            .font(.system(size: size, weight: .semibold, design: .serif))
            .tracking(1.2)
            .foregroundStyle(.white.opacity(0.85))
            .widgetAccentable()
            .shadow(color: .black.opacity(0.2), radius: 1, x: 0, y: 1)
    }

    private var actionRow: some View {
        HStack(spacing: WidgetConstants.Layout.actionRowSpacing) {
            Spacer()

            Button(intent: ToggleFavoriteIntent(promiseText: entry.declaration.text)) {
                Image(systemName: entry.isFavorite ? "heart.fill" : "heart")
                    .font(.system(size: WidgetConstants.Layout.buttonIconSize, weight: .semibold))
                    .foregroundStyle(entry.isFavorite ? Color(red: 0.95, green: 0.45, blue: 0.5) : .white)
                    .symbolEffect(.bounce, value: entry.isFavorite)
                    .frame(width: WidgetConstants.Layout.buttonHitTarget,
                           height: WidgetConstants.Layout.buttonHitTarget)
                    .background(Circle().fill(.ultraThinMaterial))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(entry.isFavorite ? "Unfavorite promise" : "Favorite promise")

            Button(intent: NextDeclarationIntent()) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: WidgetConstants.Layout.buttonIconSize, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: WidgetConstants.Layout.buttonHitTarget,
                           height: WidgetConstants.Layout.buttonHitTarget)
                    .background(Circle().fill(.ultraThinMaterial))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Next promise")
        }
    }

    // MARK: Computed Helpers

    private var deepLinkURL: URL? {
        var components = URLComponents()
        components.scheme = "speaklife"
        components.host = "declaration"
        components.queryItems = [URLQueryItem(name: "text", value: entry.declaration.text)]
        return components.url
    }

    private var accessibilityText: String {
        var parts = [entry.declaration.text]
        if let book = entry.declaration.book, !book.isEmpty { parts.append(book) }
        return parts.joined(separator: ". ")
    }

    private var timeBasedIcon: String {
        let hour = Calendar.current.component(.hour, from: entry.date)
        switch hour {
        case 5...11: return "sunrise.fill"
        case 12...17: return "sun.max.fill"
        case 18...20: return "sunset.fill"
        default: return "moon.stars.fill"
        }
    }
}

// MARK: - Book Reference Formatter

enum BookReferenceFormatter {
    /// Abbreviate "Romans 8:38-39" → "Rom 8:38", "1 Corinthians 13:4" → "1 Cor 13:4".
    static func short(_ book: String) -> String {
        let tokens = book.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
        guard !tokens.isEmpty else { return book }

        var prefix = ""
        var nameIndex = 0
        // Handle leading digit ("1", "2", "3") used by numbered books.
        if tokens.count >= 2, tokens[0].count == 1, tokens[0].first?.isNumber == true {
            prefix = tokens[0] + " "
            nameIndex = 1
        }

        guard nameIndex < tokens.count else { return book }
        let rawName = tokens[nameIndex]
        let abbrev = rawName.count > 4 ? String(rawName.prefix(3)) : rawName

        let refTokens = tokens.dropFirst(nameIndex + 1)
        let rawRef = refTokens.joined(separator: " ")
        let trimmedRef = rawRef.split(separator: "-").first.map(String.init) ?? rawRef

        let ref = trimmedRef.isEmpty ? "" : " \(trimmedRef)"
        return "\(prefix)\(abbrev)\(ref)"
    }
}

// MARK: - Reverent Background

/// Single restrained background that fits SpeakLife's calm, scripture-rooted brand.
/// Two-stop gradient per time of day + one soft vignette. Cheaper to render than
/// the previous 7-layer composition; reads cleanly in both standard and tinted appearance.
struct ReverentBackground: View {
    var body: some View {
        ZStack {
            timeBasedGradient
            RadialGradient(
                colors: [.clear, .black.opacity(0.22)],
                center: .center,
                startRadius: 80,
                endRadius: 260
            )
        }
    }

    private var timeBasedGradient: LinearGradient {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5...10:   // Morning — warm dawn
            return LinearGradient(
                colors: [
                    Color(red: 0.45, green: 0.32, blue: 0.40),
                    Color(red: 0.28, green: 0.20, blue: 0.32)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        case 11...16:  // Day — deep ocean
            return LinearGradient(
                colors: [
                    Color(red: 0.20, green: 0.32, blue: 0.48),
                    Color(red: 0.12, green: 0.20, blue: 0.36)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        case 17...20:  // Evening — sunset glow
            return LinearGradient(
                colors: [
                    Color(red: 0.42, green: 0.24, blue: 0.32),
                    Color(red: 0.22, green: 0.14, blue: 0.26)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        default:       // Night — sanctuary indigo
            return LinearGradient(
                colors: [
                    Color(red: 0.08, green: 0.10, blue: 0.20),
                    Color(red: 0.04, green: 0.05, blue: 0.12)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
}

// MARK: - Widget Configuration

@main
struct PromisesWidget: Widget {
    private static let widgetKind = "PromisesWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: Self.widgetKind,
            provider: Provider()
        ) { entry in
            PromisesWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Daily Promises")
        .description("A new Bible promise each day to anchor your faith.")
        .supportedFamilies([
            .systemSmall, .systemMedium, .systemLarge,
            .accessoryCircular, .accessoryRectangular, .accessoryInline
        ])
        .contentMarginsDisabled()
    }
}

// MARK: - Widget Preview

#if DEBUG
struct PromisesWidget_Previews: PreviewProvider {
    static var sample = WidgetDeclaration(
        text: "I am loved by God, and nothing can separate me from His love.",
        book: "Romans 8:38-39",
        bibleVerseText: "For I am convinced that neither death nor life will be able to separate us from the love of God that is in Christ Jesus our Lord.",
        category: "love"
    )

    static var previews: some View {
        Group {
            PromisesWidgetEntryView(entry: SimpleEntry(date: Date(), declaration: sample, isFavorite: false))
                .previewContext(WidgetPreviewContext(family: .systemSmall))
                .previewDisplayName("Small")

            PromisesWidgetEntryView(entry: SimpleEntry(date: Date(), declaration: sample, isFavorite: true))
                .previewContext(WidgetPreviewContext(family: .systemMedium))
                .previewDisplayName("Medium")

            PromisesWidgetEntryView(entry: SimpleEntry(date: Date(), declaration: sample, isFavorite: false))
                .previewContext(WidgetPreviewContext(family: .systemLarge))
                .previewDisplayName("Large")

            PromisesWidgetEntryView(entry: SimpleEntry(date: Date(), declaration: sample, isFavorite: false))
                .previewContext(WidgetPreviewContext(family: .accessoryCircular))
                .previewDisplayName("Circular")

            PromisesWidgetEntryView(entry: SimpleEntry(date: Date(), declaration: sample, isFavorite: false))
                .previewContext(WidgetPreviewContext(family: .accessoryRectangular))
                .previewDisplayName("Rectangular")
        }
    }
}
#endif
