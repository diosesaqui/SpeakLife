//
//  WidgetDataBridge.swift
//  SpeakLife
//
//  Created by Claude on 8/9/25.
//

import Foundation
import CoreData
import WidgetKit

/// Bridge between widget UserDefaults (App Group) and main app CoreData.
class WidgetDataBridge: ObservableObject {
    static let shared = WidgetDataBridge()

    private enum Keys {
        // Widget content (additional keys not in WidgetSharedConstants.Keys)
        static let allDeclarations = "allDeclarations"
        static let lastSyncDate = "lastSyncDate"

        // Categories
        static let availableCategories = "availableCategories"
        static let lastCategorySyncDate = "lastCategorySyncDate"
        static let lastCategoryUpdate = "lastCategoryUpdate"
        static let categoryUsage = "categoryUsage"
    }

    private static let widgetKind = WidgetSharedConstants.widgetKind
    private static let pendingActionWindow: TimeInterval = -300 // 5 minutes

    private init() {}

    // MARK: - Sync app → widget

    /// Sync full declaration records (text + reference + scripture) to the widget.
    /// Sorted by text so the daily-verse seed picks a stable verse across syncs.
    /// `reloadTimeline` lets callers batch multiple syncs into a single reload to preserve WidgetKit's daily budget.
    func syncFullDeclarationsToWidget(_ declarations: [Declaration], reloadTimeline: Bool = true) {
        guard !declarations.isEmpty else { return }

        // Sort deterministically: identical app state produces identical widget order,
        // so the daily seed always lands on the same verse.
        let records = declarations
            .map { declaration in
                WidgetDeclaration(
                    text: declaration.text,
                    book: declaration.book,
                    bibleVerseText: declaration.bibleVerseText,
                    category: declaration.category.rawValue
                )
            }
            .sorted { $0.text < $1.text }

        do {
            let data = try JSONEncoder().encode(records)
            UserDefaults.widgetGroup.set(data, forKey: WidgetSharedConstants.Keys.syncedRecords)
        } catch {
            // Encoding a [String: String?] Codable cannot fail in practice — fall back to text-only.
        }

        // Keep the legacy text array populated for backward compatibility
        // until older widget binaries are no longer in flight.
        let texts = records.map { $0.text }
        UserDefaults.widgetGroup.set(texts, forKey: WidgetSharedConstants.Keys.syncedPromises)
        UserDefaults.widgetGroup.set(declarations.map { $0.text }, forKey: Keys.allDeclarations)
        UserDefaults.widgetGroup.set(Date(), forKey: Keys.lastSyncDate)

        if reloadTimeline {
            WidgetCenter.shared.reloadTimelines(ofKind: Self.widgetKind)
        }
    }

    /// Legacy text-only sync. Kept for callers that don't yet have full records.
    func syncAllDeclarationsToWidget(_ declarations: [String], reloadTimeline: Bool = true) {
        guard !declarations.isEmpty else { return }
        let sorted = declarations.sorted()
        UserDefaults.widgetGroup.set(sorted, forKey: WidgetSharedConstants.Keys.syncedPromises)
        UserDefaults.widgetGroup.set(Date(), forKey: Keys.lastSyncDate)
        if reloadTimeline {
            WidgetCenter.shared.reloadTimelines(ofKind: Self.widgetKind)
        }
    }

    /// Sync favorite declarations to the widget. Used by the heart-button intent.
    func syncDeclarationFavorites(_ favoriteTexts: [String], reloadTimeline: Bool = true) {
        UserDefaults.widgetGroup.set(favoriteTexts, forKey: WidgetSharedConstants.Keys.widgetFavorites)
        if reloadTimeline {
            WidgetCenter.shared.reloadTimelines(ofKind: Self.widgetKind)
        }
    }

    /// Sync declarations organized by categories for filtered widget content.
    func syncCategorizedDeclarations(_ declarationsByCategory: [String: [String]], reloadTimeline: Bool = true) {
        guard !declarationsByCategory.isEmpty else { return }

        for (category, declarations) in declarationsByCategory {
            let key = "category_\(category)"
            let optimized = Array(declarations.prefix(50))
            UserDefaults.widgetGroup.set(optimized, forKey: key)
        }

        let categories = Array(declarationsByCategory.keys)
        UserDefaults.widgetGroup.set(categories, forKey: Keys.availableCategories)
        UserDefaults.widgetGroup.set(Date(), forKey: Keys.lastCategorySyncDate)

        if reloadTimeline {
            WidgetCenter.shared.reloadTimelines(ofKind: Self.widgetKind)
        }
    }

    /// Update user's selected categories for widget filtering.
    func updateSelectedCategories(_ categories: [String], reloadTimeline: Bool = true) {
        UserDefaults.widgetGroup.set(categories, forKey: WidgetSharedConstants.Keys.selectedCategories)
        UserDefaults.widgetGroup.set(Date(), forKey: Keys.lastCategoryUpdate)
        if reloadTimeline {
            WidgetCenter.shared.reloadTimelines(ofKind: Self.widgetKind)
        }
    }

    /// Trigger a single widget reload after a batch of syncs.
    func reloadWidgetTimelines() {
        WidgetCenter.shared.reloadTimelines(ofKind: Self.widgetKind)
    }

    /// Track category usage for intelligent recommendations.
    func trackCategoryUsage(_ category: String) {
        var usage = UserDefaults.widgetGroup.dictionary(forKey: Keys.categoryUsage) as? [String: Int] ?? [:]
        usage[category] = (usage[category] ?? 0) + 1
        UserDefaults.widgetGroup.set(usage, forKey: Keys.categoryUsage)
    }

    // MARK: - Sync widget → app

    /// Process any pending favorite / read actions left by widget App Intents.
    /// Call from app launch and scene activation.
    func processPendingWidgetActions() {
        processPendingFavoriteAction()
        processPendingReadAction()
    }

    private func processPendingFavoriteAction() {
        let defaults = UserDefaults.widgetGroup
        guard
            let stamp = defaults.object(forKey: WidgetSharedConstants.Keys.pendingFavoriteSyncStamp) as? Date,
            stamp.timeIntervalSinceNow > Self.pendingActionWindow,
            let action = defaults.dictionary(forKey: WidgetSharedConstants.Keys.pendingFavoriteAction),
            let promise = action["promise"] as? String,
            let isFavorited = action["isFavorited"] as? Bool
        else { return }

        updateFavoriteInCoreData(promise: promise, isFavorited: isFavorited)
        defaults.removeObject(forKey: WidgetSharedConstants.Keys.pendingFavoriteSyncStamp)
        defaults.removeObject(forKey: WidgetSharedConstants.Keys.pendingFavoriteAction)
    }

    private func processPendingReadAction() {
        let defaults = UserDefaults.widgetGroup
        guard
            let stamp = defaults.object(forKey: WidgetSharedConstants.Keys.pendingReadStamp) as? Date,
            stamp.timeIntervalSinceNow > Self.pendingActionWindow,
            let promise = defaults.string(forKey: WidgetSharedConstants.Keys.pendingReadPromise)
        else { return }

        markAsReadInCoreData(promise: promise)
        defaults.removeObject(forKey: WidgetSharedConstants.Keys.pendingReadStamp)
        defaults.removeObject(forKey: WidgetSharedConstants.Keys.pendingReadPromise)
    }

    private func updateFavoriteInCoreData(promise: String, isFavorited: Bool) {
        let context = PersistenceController.shared.container.viewContext
        let request: NSFetchRequest<AffirmationEntry> = AffirmationEntry.fetchRequest()
        request.predicate = NSPredicate(format: "text == %@", promise)

        do {
            let existing = try context.fetch(request)

            if let entry = existing.first {
                entry.isFavorite = isFavorited
                entry.lastModified = Date()
            } else if isFavorited {
                let allDeclarations = UserDefaults.widgetGroup.stringArray(forKey: Keys.allDeclarations) ?? []
                guard allDeclarations.contains(promise) else { return }
                let entry = AffirmationEntry(context: context)
                entry.text = promise
                entry.isFavorite = true
                entry.createdAt = Date()
                entry.lastModified = Date()
            }

            try context.save()
        } catch {
            assertionFailure("Failed to update favorite from widget: \(error)")
        }
    }

    private func markAsReadInCoreData(promise: String) {
        // Tracked in UserDefaults until a `readAt` property is added to AffirmationEntry.
        var read = UserDefaults.widgetGroup.stringArray(forKey: WidgetSharedConstants.Keys.readPromises) ?? []
        if !read.contains(promise) {
            read.append(promise)
            UserDefaults.widgetGroup.set(read, forKey: WidgetSharedConstants.Keys.readPromises)
        }
    }

    // MARK: - Lifecycle

    /// Single entry point called from app launch / activation.
    func syncAllData() {
        processPendingWidgetActions()
        ensureFallbackContent()
        WidgetCenter.shared.reloadTimelines(ofKind: Self.widgetKind)
    }

    /// Ensure the widget has *something* to show before the first real sync completes.
    private func ensureFallbackContent() {
        let defaults = UserDefaults.widgetGroup

        // If we already have either full records or legacy strings, nothing to do.
        if defaults.data(forKey: WidgetSharedConstants.Keys.syncedRecords) != nil { return }
        if let existing = defaults.stringArray(forKey: WidgetSharedConstants.Keys.syncedPromises), !existing.isEmpty { return }

        let fallback = Self.fallbackRecords
        if let data = try? JSONEncoder().encode(fallback) {
            defaults.set(data, forKey: WidgetSharedConstants.Keys.syncedRecords)
        }
        defaults.set(fallback.map { $0.text }, forKey: WidgetSharedConstants.Keys.syncedPromises)
        defaults.set(fallback.map { $0.text }, forKey: Keys.allDeclarations)
    }

    private static let fallbackRecords: [WidgetDeclaration] = [
        .init(text: "Trust in the Lord with all your heart; do not depend on your own understanding.",
              book: "Proverbs 3:5", bibleVerseText: nil, category: "faith"),
        .init(text: "For I know the plans I have for you, plans for good and not for disaster, to give you a future and a hope.",
              book: "Jeremiah 29:11", bibleVerseText: nil, category: "hope"),
        .init(text: "Don't worry about anything; instead, pray about everything.",
              book: "Philippians 4:6", bibleVerseText: nil, category: "anxiety"),
        .init(text: "The Lord is for me, so I will have no fear.",
              book: "Psalm 118:6", bibleVerseText: nil, category: "fear"),
        .init(text: "Peace I leave with you; my peace I give you.",
              book: "John 14:27", bibleVerseText: nil, category: "rest"),
        .init(text: "God has not given me a spirit of fear, but of power, love, and self-discipline.",
              book: "2 Timothy 1:7", bibleVerseText: nil, category: "fear"),
        .init(text: "Be joyful in hope, patient in affliction, faithful in prayer.",
              book: "Romans 12:12", bibleVerseText: nil, category: "joy"),
        .init(text: "This is the day the Lord has made. I will rejoice and be glad in it.",
              book: "Psalm 118:24", bibleVerseText: nil, category: "gratitude"),
        .init(text: "I can do all things through Christ who strengthens me.",
              book: "Philippians 4:13", bibleVerseText: nil, category: "faith"),
        .init(text: "The Lord is my shepherd; I shall not want.",
              book: "Psalm 23:1", bibleVerseText: nil, category: "rest")
    ]
}
