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
    static let placeholderText = "Loading..."

    enum Design {
        static let contentSpacing: CGFloat = 10
        static let horizontalPadding: CGFloat = 18
        static let cornerRadius: CGFloat = 20
        static let actionRowSpacing: CGFloat = 12
    }

    enum TimeRanges {
        static let morningStart = 5
        static let morningEnd = 11
        static let afternoonEnd = 17
        static let eveningEnd = 21
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

    /// Deterministic daily verse: same per device per day, drift one verse per rotation tap.
    func declaration(for date: Date, offset: Int = 0) -> WidgetDeclaration {
        guard !records.isEmpty else { return .fallback }
        let filtered = filteredBySelectedCategories(records)
        let pool = filtered.isEmpty ? records : filtered

        let calendar = Calendar.current
        let dayOfYear = calendar.ordinality(of: .day, in: .year, for: date) ?? 1
        let year = calendar.component(.year, from: date)
        // Stable hash: large prime mixes to avoid clustering.
        let seed = abs((dayOfYear &* 1_000_003) &+ (year &* 31) &+ offset)
        let index = seed % pool.count
        return pool[index]
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
        completion(currentEntry(at: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SimpleEntry>) -> ()) {
        let now = Date()
        var entries: [SimpleEntry] = []

        // Current entry
        entries.append(currentEntry(at: now))

        // Pre-roll a few hourly entries so the widget animates between rotations
        // even before the system asks for a fresh timeline.
        for hourOffset in 1...4 {
            if let future = Calendar.current.date(byAdding: .hour, value: hourOffset, to: now) {
                entries.append(currentEntry(at: future))
            }
        }

        // Refresh at the next day boundary so the daily verse rolls over.
        let startOfTomorrow = Calendar.current.nextDate(
            after: now,
            matching: DateComponents(hour: 0, minute: 1),
            matchingPolicy: .nextTime
        ) ?? now.addingTimeInterval(60 * 60)

        completion(Timeline(entries: entries, policy: .after(startOfTomorrow)))
    }

    private func currentEntry(at date: Date) -> SimpleEntry {
        let store = WidgetDeclarationStore.load()
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
                .containerBackground(for: .widget) { background }
        case .systemMedium:
            mediumView
                .containerBackground(for: .widget) { background }
        case .systemLarge:
            largeView
                .containerBackground(for: .widget) { background }
        default:
            smallView
                .containerBackground(for: .widget) { background }
        }
    }

    // MARK: Background

    private var background: some View {
        ZStack {
            BeautifulGradientBackground()
            WidgetGradientBackground().opacity(0.15)
        }
    }

    // MARK: Home Screen Views

    private var smallView: some View {
        VStack(spacing: 6) {
            promiseText(
                size: 15,
                lineLimit: 6,
                weight: .medium
            )
            if let book = entry.declaration.book, !book.isEmpty {
                bookReference(book, size: 10)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .widgetURL(deepLinkURL)
    }

    private var mediumView: some View {
        VStack(spacing: 8) {
            promiseText(
                size: 16,
                lineLimit: 5,
                weight: .medium
            )

            if let book = entry.declaration.book, !book.isEmpty {
                bookReference(book, size: 11)
            }

            actionRow
                .padding(.top, 2)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .widgetURL(deepLinkURL)
    }

    private var largeView: some View {
        VStack(spacing: 12) {
            promiseText(
                size: 20,
                lineLimit: 5,
                weight: .semibold
            )

            if let verse = entry.declaration.bibleVerseText, !verse.isEmpty {
                Rectangle()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 40, height: 0.5)
                    .padding(.vertical, 2)

                Text("\u{201C}\(verse)\u{201D}")
                    .font(.system(size: 13, weight: .regular, design: .serif))
                    .foregroundColor(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .lineLimit(5)
                    .minimumScaleFactor(0.8)
                    .shadow(color: .black.opacity(0.25), radius: 2, x: 0, y: 1)
            }

            if let book = entry.declaration.book, !book.isEmpty {
                bookReference(book, size: 13)
            }

            actionRow
                .padding(.top, 4)

            Text(TimeBasedGreeting.current.message)
                .font(.system(size: 11, weight: .light, design: .serif))
                .foregroundColor(.white.opacity(0.75))
                .padding(.top, 2)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
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

    /// Compact verse reference (e.g. "Rom 8:38") for the tiny circular slot.
    private var circularLabel: String {
        if let book = entry.declaration.book, !book.isEmpty {
            return shortBookReference(book)
        }
        let words = entry.declaration.text.split(separator: " ")
        return words.prefix(2).joined(separator: " ")
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
                    .opacity(0.7)
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

    private func promiseText(size: CGFloat, lineLimit: Int, weight: Font.Weight) -> some View {
        Text(entry.declaration.text)
            .foregroundColor(.white)
            .font(.system(size: size, weight: weight, design: .serif))
            .multilineTextAlignment(.center)
            .lineSpacing(3)
            .lineLimit(lineLimit)
            .minimumScaleFactor(0.7)
            .shadow(color: .black.opacity(0.35), radius: 2, x: 0, y: 1)
            .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
    }

    private func bookReference(_ book: String, size: CGFloat) -> some View {
        Text(book)
            .font(.system(size: size, weight: .semibold, design: .serif))
            .foregroundColor(.white.opacity(0.8))
            .tracking(0.5)
            .widgetAccentable()
            .shadow(color: .black.opacity(0.2), radius: 1, x: 0, y: 1)
    }

    private var actionRow: some View {
        HStack(spacing: WidgetConstants.Design.actionRowSpacing) {
            Button(intent: ToggleFavoriteIntent(promiseText: entry.declaration.text)) {
                Image(systemName: entry.isFavorite ? "heart.fill" : "heart")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(Color.white.opacity(0.15)))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(entry.isFavorite ? "Unfavorite promise" : "Favorite promise")

            Button(intent: NextDeclarationIntent()) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(Color.white.opacity(0.15)))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Next promise")
        }
    }

    // MARK: Computed Helpers

    private var deepLinkURL: URL? {
        URL(string: "speaklife://declaration?text=\(entry.declaration.text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")")
    }

    private var accessibilityText: String {
        var parts = [entry.declaration.text]
        if let book = entry.declaration.book, !book.isEmpty { parts.append(book) }
        if family == .systemLarge { parts.append(TimeBasedGreeting.current.message) }
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

    /// Abbreviate "Romans 8:38-39" → "Rom 8:38" for the circular slot.
    private func shortBookReference(_ book: String) -> String {
        let parts = book.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
        guard parts.count == 2 else { return book }
        let name = String(parts[0])
        let ref = String(parts[1]).split(separator: "-").first.map(String.init) ?? String(parts[1])
        let abbrev = name.count > 4 ? String(name.prefix(3)) : name
        return "\(abbrev) \(ref)"
    }
}

// MARK: - Time-Based Greeting System

enum TimeBasedGreeting {
    case morning, afternoon, evening, night

    var message: String {
        switch self {
        case .morning:   return "Good morning. Start the day in His word."
        case .afternoon: return "Good afternoon. Keep your spirit strong."
        case .evening:   return "Good evening. Reflect on His blessings."
        case .night:     return "Good night. Rest in His promises."
        }
    }

    static var current: TimeBasedGreeting {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case WidgetConstants.TimeRanges.morningStart...WidgetConstants.TimeRanges.morningEnd:
            return .morning
        case (WidgetConstants.TimeRanges.morningEnd + 1)...WidgetConstants.TimeRanges.afternoonEnd:
            return .afternoon
        case (WidgetConstants.TimeRanges.afternoonEnd + 1)...WidgetConstants.TimeRanges.eveningEnd:
            return .evening
        default:
            return .night
        }
    }
}

// MARK: - Beautiful Gradient Background

struct BeautifulGradientBackground: View {
    private var timeBasedGradient: LinearGradient {
        let hour = Calendar.current.component(.hour, from: Date())

        switch hour {
        case 5...8: // Sophisticated dawn
            return LinearGradient(
                colors: [
                    Color(red: 0.95, green: 0.85, blue: 0.75),
                    Color(red: 0.85, green: 0.75, blue: 0.7),
                    Color(red: 0.75, green: 0.65, blue: 0.65),
                    Color(red: 0.65, green: 0.55, blue: 0.6)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        case 9...16: // Elegant sky
            return LinearGradient(
                colors: [
                    Color(red: 0.85, green: 0.9, blue: 0.95),
                    Color(red: 0.75, green: 0.82, blue: 0.9),
                    Color(red: 0.65, green: 0.75, blue: 0.85),
                    Color(red: 0.55, green: 0.68, blue: 0.8)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        case 17...20: // Refined sunset
            return LinearGradient(
                colors: [
                    Color(red: 0.85, green: 0.7, blue: 0.65),
                    Color(red: 0.75, green: 0.6, blue: 0.6),
                    Color(red: 0.65, green: 0.5, blue: 0.55),
                    Color(red: 0.55, green: 0.4, blue: 0.5)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        default: // Deep night
            return LinearGradient(
                colors: [
                    Color(red: 0.15, green: 0.15, blue: 0.25),
                    Color(red: 0.12, green: 0.12, blue: 0.22),
                    Color(red: 0.1, green: 0.1, blue: 0.18),
                    Color(red: 0.08, green: 0.08, blue: 0.15)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    var body: some View {
        ZStack {
            timeBasedGradient
            RadialGradient(
                colors: [Color.white.opacity(0.08), Color.clear],
                center: .topLeading,
                startRadius: 20,
                endRadius: 200
            )
            RadialGradient(
                colors: [Color.clear, Color.black.opacity(0.18)],
                center: .center,
                startRadius: 100,
                endRadius: 300
            )
        }
    }
}

// MARK: - Time-of-Day Overlay

struct WidgetGradientBackground: View {
    var body: some View {
        let colors = timeBasedColors
        return LinearGradient(
            gradient: Gradient(colors: colors),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var timeBasedColors: [Color] {
        switch TimeBasedGreeting.current {
        case .morning:
            return [Color(red: 0.9, green: 0.85, blue: 0.8).opacity(0.2),
                    Color(red: 0.85, green: 0.8, blue: 0.75).opacity(0.15)]
        case .afternoon:
            return [Color(red: 0.8, green: 0.85, blue: 0.9).opacity(0.2),
                    Color(red: 0.75, green: 0.8, blue: 0.85).opacity(0.15)]
        case .evening:
            return [Color(red: 0.8, green: 0.7, blue: 0.75).opacity(0.2),
                    Color(red: 0.75, green: 0.65, blue: 0.7).opacity(0.15)]
        case .night:
            return [Color(red: 0.2, green: 0.2, blue: 0.3).opacity(0.3),
                    Color(red: 0.15, green: 0.15, blue: 0.25).opacity(0.25)]
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
        .description("Inspiring Bible promises that change throughout the day to encourage your faith journey.")
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
