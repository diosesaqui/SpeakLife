//
//  PromisesWidget.swift
//  PromisesWidget
//
//  Created by Riccardo Washington on 11/2/22.
//

import WidgetKit
import SwiftUI

// MARK: - Constants

private enum WidgetConstants {
    static let appGroupSuiteName = "group.com.speaklife.widget"
    static let syncedPromisesKey = "syncedPromises"
    static let fallbackPromise = "I am blessed!"
    static let placeholderText = "Loading..."
    static let customFontName = "Avenir Next"  // Clean, modern font
    
    enum Design {
        static let backgroundOpacity: Double = 0.4  // Lower opacity for image overlay
        static let textBackgroundOpacity: Double = 0.15  // Very subtle background for text
        static let greetingOpacity: Double = 0.95
        static let contentSpacing: CGFloat = 8
        static let horizontalPadding: CGFloat = 16
        static let bottomPadding: CGFloat = 8
        static let cornerRadius: CGFloat = 16
        
        enum FontSizes {
            static let small: CGFloat = 16
            static let medium: CGFloat = 18
            static let large: CGFloat = 20
            static let greeting: CGFloat = 13
        }
    }
    
    enum UserPreferences {
        static let selectedCategoriesKey = "selectedCategories"
        static let recentCategoriesKey = "recentCategories"
        static let categoryUsageKey = "categoryUsage"
        static let lastCategoryUpdateKey = "lastCategoryUpdate"
    }
    
    enum TimeRanges {
        static let morningStart = 5
        static let morningEnd = 11
        static let afternoonEnd = 17
        static let eveningEnd = 21
    }
}

// MARK: - Timeline Provider

struct Provider: TimelineProvider {
    
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), promise: WidgetConstants.placeholderText)
    }
    
    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let promise = getCurrentPromise()
        completion(SimpleEntry(date: Date(), promise: promise))
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let now = Date()
        let promise = getCurrentPromise()
        
        // Create entries for the current hour and next few hours
        var entries: [SimpleEntry] = []
        
        // Current entry
        entries.append(SimpleEntry(date: now, promise: promise))
        
        // Next hour entry (different promise if available)
        if let nextHour = Calendar.current.date(byAdding: .hour, value: 1, to: now) {
            let nextPromise = getPromiseForTime(nextHour)
            entries.append(SimpleEntry(date: nextHour, promise: nextPromise))
        }
        
        // Determine next refresh time (next hour boundary)
        let nextRefresh = Calendar.current.date(byAdding: .hour, value: 1, to: now) ?? 
                         Calendar.current.date(byAdding: .minute, value: 15, to: now) ?? now
        
        let timeline = Timeline(entries: entries, policy: .after(nextRefresh))
        completion(timeline)
    }
    
    // MARK: - Private Methods
    
    private func getCurrentPromise() -> String {
        return getPromiseForTime(Date())
    }
    
    private func getPromiseForTime(_ date: Date) -> String {
        guard let widgetDefaults = UserDefaults(suiteName: WidgetConstants.appGroupSuiteName) else {
            return WidgetConstants.fallbackPromise
        }
        
        // Try to get category-filtered promises first
        if let categoryPromise = getCategoryFilteredPromise(from: widgetDefaults, for: date) {
            return categoryPromise
        }
        
        // Fallback to all synced promises
        guard let syncedPromises = widgetDefaults.stringArray(forKey: WidgetConstants.syncedPromisesKey),
              !syncedPromises.isEmpty else {
            return WidgetConstants.fallbackPromise
        }
        
        // Use hour-based selection for consistent daily rotation
        let hour = Calendar.current.component(.hour, from: date)
        let safeIndex = hour % syncedPromises.count
        
        return syncedPromises[safeIndex]
    }
    
    private func getCategoryFilteredPromise(from defaults: UserDefaults, for date: Date) -> String? {
        // Strategy 1: Time-based category intelligence
        let contextualCategories = getContextualCategories(for: date)
        
        for category in contextualCategories {
            if let categoryPromises = defaults.stringArray(forKey: "category_\(category)"),
               !categoryPromises.isEmpty {
                let hour = Calendar.current.component(.hour, from: date)
                let index = hour % categoryPromises.count
                return categoryPromises[index]
            }
        }
        
        // Strategy 2: User's selected categories
        if let selectedCategories = defaults.stringArray(forKey: WidgetConstants.UserPreferences.selectedCategoriesKey) {
            for category in selectedCategories {
                if let categoryPromises = defaults.stringArray(forKey: "category_\(category)"),
                   !categoryPromises.isEmpty {
                    let hour = Calendar.current.component(.hour, from: date)
                    let index = hour % categoryPromises.count
                    return categoryPromises[index]
                }
            }
        }
        
        return nil
    }
    
    private func getContextualCategories(for date: Date) -> [String] {
        let hour = Calendar.current.component(.hour, from: date)
        let dayOfWeek = Calendar.current.component(.weekday, from: date)
        
        var categories: [String] = []
        
        // Time-based context
        switch hour {
        case 5...8:
            categories.append(contentsOf: ["Morning", "Strength", "New Beginnings", "Energy"])
        case 9...11:
            categories.append(contentsOf: ["Work", "Focus", "Productivity", "Wisdom"])
        case 12...13:
            categories.append(contentsOf: ["Rest", "Reflection", "Gratitude"])
        case 14...17:
            categories.append(contentsOf: ["Perseverance", "Strength", "Purpose"])
        case 18...20:
            categories.append(contentsOf: ["Family", "Love", "Gratitude", "Reflection"])
        case 21...23:
            categories.append(contentsOf: ["Peace", "Rest", "Forgiveness", "Comfort"])
        default:
            categories.append(contentsOf: ["Peace", "Comfort", "Protection"])
        }
        
        // Day-based context
        switch dayOfWeek {
        case 1: // Sunday
            categories.append(contentsOf: ["Worship", "Rest", "Family", "Reflection"])
        case 2: // Monday
            categories.append(contentsOf: ["New Beginnings", "Strength", "Purpose", "Energy"])
        case 6, 7: // Friday/Saturday
            categories.append(contentsOf: ["Gratitude", "Joy", "Celebration", "Rest"])
        default:
            categories.append(contentsOf: ["Work", "Perseverance", "Wisdom"])
        }
        
        return categories
    }
}

// MARK: - Timeline Entry

/// Represents a single timeline entry for the widget
struct SimpleEntry: TimelineEntry {
    let date: Date
    let promise: String
    
    init(date: Date, promise: String) {
        self.date = date
        self.promise = promise.trimmingCharacters(in: .whitespacesAndNewlines)
    }
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
    
    // MARK: - Private Views
    
    @ViewBuilder
    private var widgetContent: some View {
        if #available(iOS 17.0, *) {
            contentView
                .containerBackground(.clear, for: .widget)
        } else {
            contentView
        }
    }
    
    private var contentView: some View {
        ZStack {
            // Use beautiful gradient background (images may not load properly in widget)
            BeautifulGradientBackground()
            
            // Time-based gradient overlay for ambiance
            WidgetGradientBackground()
                .opacity(0.15)
            
            VStack(spacing: WidgetConstants.Design.contentSpacing) {
                Spacer()
                
                // Text with subtle background
                VStack(spacing: 8) {
                    promiseText
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: WidgetConstants.Design.cornerRadius)
                        .fill(Color.black.opacity(WidgetConstants.Design.textBackgroundOpacity))
                )
                .padding(.horizontal, 8)
                
                Spacer()
                
                if shouldShowGreeting {
                    greetingText
                }
            }
        }
    }
    
    private var promiseText: some View {
        Text(entry.promise)
            .foregroundColor(.white)
            .font(.system(size: fontSize, weight: .semibold, design: .rounded))  // Clean, modern system font
            .multilineTextAlignment(.center)
            .lineSpacing(3)
            .shadow(color: .black.opacity(0.5), radius: 3, x: 0, y: 2)
            .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1) // Double shadow for better readability
            .minimumScaleFactor(0.75) // Allow text scaling for better fit
    }
    
    private var greetingText: some View {
        Text(TimeBasedGreeting.current.message)
            .font(.system(size: WidgetConstants.Design.FontSizes.greeting, weight: .regular, design: .rounded))
            .foregroundColor(.white.opacity(WidgetConstants.Design.greetingOpacity))
            .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
            .padding(.bottom, WidgetConstants.Design.bottomPadding)
    }
    
    // MARK: - Computed Properties
    
    private var fontSize: CGFloat {
        switch family {
        case .systemSmall:
            return WidgetConstants.Design.FontSizes.small
        case .systemMedium:
            return WidgetConstants.Design.FontSizes.medium
        default:
            return WidgetConstants.Design.FontSizes.large
        }
    }
    
    private var shouldShowGreeting: Bool {
        family == .systemLarge
    }
    
    private var accessibilityText: String {
        if shouldShowGreeting {
            return "\(entry.promise). \(TimeBasedGreeting.current.message)"
        }
        return entry.promise
    }
}

// MARK: - Time-Based Greeting System

enum TimeBasedGreeting {
    case morning, afternoon, evening, night
    
    var message: String {
        switch self {
        case .morning:
            return "Good morning! Start your day with faith."
        case .afternoon:
            return "Good afternoon! Keep your spirit strong."
        case .evening:
            return "Good evening! Reflect on God's blessings."
        case .night:
            return "Good night! Rest in His promises."
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

// MARK: - Calendar Extension

extension Calendar {
    func ordinateOfDay(for date: Date) -> Int? {
        return self.ordinality(of: .day, in: .year, for: date)
    }
}

// MARK: - Background Helpers

struct WidgetBackgroundImage {
    static var current: String {
        // Beautiful images available in the app
        let images = [
            "boatLakeMountain",
            "wheatFieldRedRose",
            "redTreeLake",
            "redRosesGreySkies"
        ]
        
        // Use time-based selection for variety
        let hour = Calendar.current.component(.hour, from: Date())
        let dayOfYear = Calendar.current.ordinateOfDay(for: Date()) ?? 1
        
        // Combine hour and day for image rotation
        let index = (hour + dayOfYear) % images.count
        return images[index]
    }
}

// MARK: - Beautiful Gradient Background

struct BeautifulGradientBackground: View {
    private var timeBasedGradient: LinearGradient {
        let hour = Calendar.current.component(.hour, from: Date())
        
        switch hour {
        case 5...8: // Morning - sunrise colors
            return LinearGradient(
                colors: [
                    Color(red: 1.0, green: 0.6, blue: 0.4).opacity(0.9),   // Peach
                    Color(red: 1.0, green: 0.4, blue: 0.5).opacity(0.8),   // Coral
                    Color(red: 0.9, green: 0.3, blue: 0.6).opacity(0.7)    // Pink
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case 9...16: // Day - sky blue colors  
            return LinearGradient(
                colors: [
                    Color(red: 0.4, green: 0.6, blue: 0.9).opacity(0.9),   // Sky blue
                    Color(red: 0.3, green: 0.5, blue: 0.8).opacity(0.8),   // Medium blue
                    Color(red: 0.5, green: 0.7, blue: 0.9).opacity(0.7)    // Light blue
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case 17...20: // Evening - sunset colors
            return LinearGradient(
                colors: [
                    Color(red: 0.9, green: 0.4, blue: 0.3).opacity(0.9),   // Orange
                    Color(red: 0.8, green: 0.3, blue: 0.5).opacity(0.8),   // Pink-purple
                    Color(red: 0.6, green: 0.2, blue: 0.6).opacity(0.7)    // Purple
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        default: // Night - dark blue/purple
            return LinearGradient(
                colors: [
                    Color(red: 0.1, green: 0.1, blue: 0.3).opacity(0.95),  // Dark blue
                    Color(red: 0.2, green: 0.1, blue: 0.4).opacity(0.9),   // Deep purple
                    Color(red: 0.1, green: 0.05, blue: 0.25).opacity(0.85) // Midnight
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
    
    var body: some View {
        ZStack {
            // Base time-based gradient
            timeBasedGradient
            
            // Subtle mesh gradient overlay for depth
            RadialGradient(
                colors: [
                    Color.white.opacity(0.1),
                    Color.clear
                ],
                center: .topLeading,
                startRadius: 50,
                endRadius: 300
            )
        }
    }
}

// MARK: - Gradient Background

struct WidgetGradientBackground: View {
    
    private enum GradientColors {
        static let morning: [Color] = [.orange.opacity(0.3), .yellow.opacity(0.3)]
        static let afternoon: [Color] = [.blue.opacity(0.3), .cyan.opacity(0.3)]
        static let evening: [Color] = [.purple.opacity(0.3), .indigo.opacity(0.3)]
        static let night: [Color] = [.indigo.opacity(0.3), .black.opacity(0.5)]
    }
    
    var body: some View {
        LinearGradient(
            gradient: Gradient(colors: timeBasedColors),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private var timeBasedColors: [Color] {
        let colors: [Color]
        
        switch TimeBasedGreeting.current {
        case .morning:
            colors = GradientColors.morning
        case .afternoon:
            colors = GradientColors.afternoon
        case .evening:
            colors = GradientColors.evening
        case .night:
            colors = GradientColors.night
        }
        
        // Return a stable 2-color gradient (no randomization for consistency)
        return Array(colors.prefix(2))
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
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled() // Use full widget space
    }
}

// MARK: - Widget Preview

#if DEBUG
struct PromisesWidget_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Small widget preview
            PromisesWidgetEntryView(
                entry: SimpleEntry(
                    date: Date(),
                    promise: "Trust in the Lord with all your heart; do not depend on your own understanding."
                )
            )
            .previewContext(WidgetPreviewContext(family: .systemSmall))
            .previewDisplayName("Small")
            
            // Medium widget preview
            PromisesWidgetEntryView(
                entry: SimpleEntry(
                    date: Date(),
                    promise: "For I know the plans I have for you, says the Lord. They are plans for good and not for disaster, to give you a future and a hope."
                )
            )
            .previewContext(WidgetPreviewContext(family: .systemMedium))
            .previewDisplayName("Medium")
            
            // Large widget preview
            PromisesWidgetEntryView(
                entry: SimpleEntry(
                    date: Date(),
                    promise: "Don't worry about anything; instead, pray about everything. Tell God what you need, and thank him for all he has done."
                )
            )
            .previewContext(WidgetPreviewContext(family: .systemLarge))
            .previewDisplayName("Large")
        }
    }
}
#endif