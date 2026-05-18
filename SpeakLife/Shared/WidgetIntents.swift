//
//  WidgetIntents.swift
//  SpeakLife & PromisesWidget
//
//  Created by Claude on 8/9/25.
//

import AppIntents
import Foundation
import WidgetKit

// MARK: - App Group Constants

enum WidgetSharedConstants {
    static let appGroupSuiteName = "group.com.Franchiz.SpeakLife"
    static let widgetKind = "PromisesWidget"

    enum Keys {
        static let syncedRecords = "syncedDeclarationRecords"   // JSON [WidgetDeclaration]
        static let syncedPromises = "syncedPromises"            // Legacy [String]
        static let widgetFavorites = "widgetFavorites"
        static let pendingFavoriteAction = "lastFavoriteAction"
        static let pendingFavoriteSyncStamp = "needsSyncFavorites"
        static let pendingReadStamp = "needsSyncReadStatus"
        static let pendingReadPromise = "lastReadPromise"
        static let readPromises = "readPromises"
        static let rotationOffset = "widgetRotationOffset"
        static let selectedCategories = "selectedCategories"
    }
}

// MARK: - UserDefaults Extension

extension UserDefaults {
    static let widgetGroup = UserDefaults(suiteName: WidgetSharedConstants.appGroupSuiteName) ?? UserDefaults.standard
}

// MARK: - Shared Declaration Model

/// Codable record shared between the app (encoder) and the widget (decoder) via the App Group.
struct WidgetDeclaration: Codable, Hashable, Identifiable {
    let text: String
    let book: String?
    let bibleVerseText: String?
    let category: String

    var id: String { text + category }

    init(text: String, book: String? = nil, bibleVerseText: String? = nil, category: String) {
        self.text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        self.book = book?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.bibleVerseText = bibleVerseText?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.category = category
    }

    static let fallback = WidgetDeclaration(
        text: "I am blessed!",
        book: nil,
        bibleVerseText: nil,
        category: "faith"
    )
}

// MARK: - Widget App Intents (iOS 17+)

/// Advances the widget's rotation offset. Each tap re-seeds the daily-verse selection.
@available(iOS 17.0, *)
struct NextDeclarationIntent: AppIntent {
    static var title: LocalizedStringResource = "Next Promise"
    static var description = IntentDescription("Show the next inspirational Bible promise.")
    static var isDiscoverable: Bool = true

    init() {}

    func perform() async throws -> some IntentResult {
        let current = UserDefaults.widgetGroup.integer(forKey: WidgetSharedConstants.Keys.rotationOffset)
        UserDefaults.widgetGroup.set(current &+ 1, forKey: WidgetSharedConstants.Keys.rotationOffset)
        WidgetCenter.shared.reloadTimelines(ofKind: WidgetSharedConstants.widgetKind)
        return .result()
    }
}

/// Toggles favorite status for a specific promise. Records a pending action so the app can sync to Core Data later.
@available(iOS 17.0, *)
struct ToggleFavoriteIntent: AppIntent {
    static var title: LocalizedStringResource = "Favorite Promise"
    static var description = IntentDescription("Save or unsave the current Bible promise to your favorites.")
    static var isDiscoverable: Bool = true

    @Parameter(title: "Promise")
    var promiseText: String

    init() {}

    init(promiseText: String) {
        self.promiseText = promiseText
    }

    func perform() async throws -> some IntentResult {
        let defaults = UserDefaults.widgetGroup
        var favorites = defaults.stringArray(forKey: WidgetSharedConstants.Keys.widgetFavorites) ?? []
        let wasFavorited = favorites.contains(promiseText)

        if wasFavorited {
            favorites.removeAll { $0 == promiseText }
        } else {
            favorites.append(promiseText)
        }
        defaults.set(favorites, forKey: WidgetSharedConstants.Keys.widgetFavorites)

        // Hand off to the app for Core Data sync on next foreground.
        defaults.set(
            ["promise": promiseText, "isFavorited": !wasFavorited],
            forKey: WidgetSharedConstants.Keys.pendingFavoriteAction
        )
        defaults.set(Date(), forKey: WidgetSharedConstants.Keys.pendingFavoriteSyncStamp)

        WidgetCenter.shared.reloadTimelines(ofKind: WidgetSharedConstants.widgetKind)
        return .result()
    }
}

/// Marks a promise as read. Kept for the lock-screen tap flow.
@available(iOS 17.0, *)
struct MarkAsReadIntent: AppIntent {
    static var title: LocalizedStringResource = "Mark as Read"
    static var description = IntentDescription("Mark this promise as read.")
    static var isDiscoverable: Bool = false

    @Parameter(title: "Promise")
    var promiseText: String

    init() {}

    init(promiseText: String) {
        self.promiseText = promiseText
    }

    func perform() async throws -> some IntentResult {
        let defaults = UserDefaults.widgetGroup
        var read = defaults.stringArray(forKey: WidgetSharedConstants.Keys.readPromises) ?? []
        if !read.contains(promiseText) {
            read.append(promiseText)
            defaults.set(read, forKey: WidgetSharedConstants.Keys.readPromises)
        }

        defaults.set(promiseText, forKey: WidgetSharedConstants.Keys.pendingReadPromise)
        defaults.set(Date(), forKey: WidgetSharedConstants.Keys.pendingReadStamp)

        WidgetCenter.shared.reloadTimelines(ofKind: WidgetSharedConstants.widgetKind)
        return .result()
    }
}
