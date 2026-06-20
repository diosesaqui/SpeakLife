//
//  AudioRecommendationEngine.swift
//  SpeakLife
//
//  Maps user's onboarding DeclarationCategory preferences to the most relevant
//  audio filter, then surfaces the first unplayed episode in that filter.
//

import Foundation

struct AudioRecommendation {
    let filterId: String
    let episode: AudioDeclaration?
}

final class AudioRecommendationEngine {

    // MARK: - Category → Filter Priority Map
    static let categoryToFilterPriority: [String: [String]] = [
        "anxiety":        ["meditation", "speaklife"],
        "fear":           ["meditation", "speaklife"],
        "hardtimes":      ["speaklife", "growWithJesus"],
        "addiction":      ["speaklife", "declarations"],
        "identity":       ["meditation", "speaklife"],
        "confidence":     ["speaklife", "declarations"],
        "destiny":        ["speaklife", "growWithJesus"],
        "purity":         ["speaklife"],
        "faith":          ["speaklife", "growWithJesus"],
        "grace":          ["growWithJesus", "speaklife"],
        "hope":           ["speaklife", "growWithJesus"],
        "general":        ["growWithJesus", "speaklife"],
        "godsheart":      ["godsHeart", "speaklife"],
        "heaven":         ["gospel", "speaklife"],
        "friendship":     ["growWithJesus"],
        "warfare":        ["divineHealth", "declarations"],
        "godsprotection": ["psalm91", "declarations"],
        "health":         ["divineHealth", "declarations"],
        "wisdom":         ["meditation"],
        "joy":            ["meditation", "speaklife"],
        "love":           ["meditation", "declarations"],
        "gratitude":      ["meditation", "declarations"],
        "praise":         ["meditation"],
        "rest":           ["meditation"],
        "marriage":       ["declarations"],
        "parenting":      ["declarations"],
        "innerhealing":   ["growWithJesus", "declarations"],
        "wealth":         ["declarations"],
        "favor":          ["declarations"],
        "work":           ["declarations"],
        "miracles":       ["declarations"],
        "speaklife":      ["speaklife"],
    ]

    static let defaultFilterId = "speaklife"
    private static let categoryIndexKey = "audioCategoryProgressIndex"

    // MARK: - Public API

    /// Returns the best filter ID for the user's onboarding categories.
    /// Used by the checklist to pre-set the filter before content loads.
    static func bestFilterId(for userCategories: [String], availableFilterIds: [String]) -> String {
        let available = Set(availableFilterIds)
        for category in userCategories {
            guard let preferred = categoryToFilterPriority[category.lowercased()] else { continue }
            if let match = preferred.first(where: { available.contains($0) }) { return match }
        }
        return available.contains(defaultFilterId) ? defaultFilterId :
               (availableFilterIds.first(where: { $0 != "favorites" }) ?? defaultFilterId)
    }

    /// Recommends the next episode, cycling through the user's categories as each is exhausted.
    static func recommend(
        userCategories: [String],
        contentByFilter: [String: [AudioDeclaration]],
        availableFilterIds: [String]
    ) -> AudioRecommendation {
        let categories = userCategories.isEmpty ? [defaultFilterId] : userCategories
        let savedIndex = UserDefaults.standard.integer(forKey: categoryIndexKey)
        let startIndex = min(savedIndex, categories.count - 1)

        for offset in 0..<categories.count {
            let index = (startIndex + offset) % categories.count
            let filterId = bestFilterId(for: [categories[index]], availableFilterIds: availableFilterIds)
            let content = contentByFilter[filterId] ?? []
            if let unplayed = content.first(where: { !AudioProgressStore.shared.isPlayed($0.id) }) {
                if index != startIndex {
                    UserDefaults.standard.set(index, forKey: categoryIndexKey)
                }
                return AudioRecommendation(filterId: filterId, episode: unplayed)
            }
        }

        // All categories exhausted — reset and return first episode of first category
        UserDefaults.standard.set(0, forKey: categoryIndexKey)
        let fallbackFilterId = bestFilterId(for: categories, availableFilterIds: availableFilterIds)
        let fallbackContent = contentByFilter[fallbackFilterId] ?? []
        return AudioRecommendation(filterId: fallbackFilterId, episode: fallbackContent.first)
    }

    /// Manually advances to the next category.
    static func advanceCategory(userCategories: [String]) {
        let categories = userCategories.isEmpty ? [defaultFilterId] : userCategories
        let current = UserDefaults.standard.integer(forKey: categoryIndexKey)
        UserDefaults.standard.set((current + 1) % categories.count, forKey: categoryIndexKey)
    }

    // MARK: - Personalized Filter Ordering

    /// Re-orders the curated audio filters so the categories the user cares about
    /// are promoted to the front. The user's personal declaration is the
    /// highest-intent signal and is applied before onboarding-selected
    /// categories; everything else keeps its curated order.
    ///
    /// Pure and side-effect free — returns `filters` unchanged when there is no
    /// signal or no match, so it is always safe to call. A pinned "favorites"
    /// filter (if present) always stays first.
    ///
    /// - Parameters:
    ///   - filters: Curated filter list, already in its intended order.
    ///   - personalDeclarationCategory: `DeclarationCategory` rawValue of the
    ///     user's active personal declaration, if any.
    ///   - selectedCategories: `DeclarationCategory` rawValues chosen during
    ///     onboarding, in selection order.
    ///   - maxPromoted: Cap on how many filters float to the front.
    static func personalizedOrder(
        filters: [FilterConfig],
        personalDeclarationCategory: String?,
        selectedCategories: [String],
        maxPromoted: Int = 3
    ) -> [FilterConfig] {
        guard filters.count > 1, maxPromoted > 0 else { return filters }

        // Ordered, de-duplicated preferred filter IDs. Personal declaration maps
        // first (strongest intent), then each selected category in turn.
        var preferredIds: [String] = []
        func appendMapping(for category: String?) {
            guard let raw = category?.lowercased(), !raw.isEmpty,
                  let mapped = categoryToFilterPriority[raw] else { return }
            for id in mapped where !preferredIds.contains(id) {
                preferredIds.append(id)
            }
        }
        appendMapping(for: personalDeclarationCategory)
        selectedCategories.forEach { appendMapping(for: $0) }

        let available = Set(filters.map { $0.id })
        let promotedIds = preferredIds
            .filter { available.contains($0) && $0 != "favorites" }
            .prefix(maxPromoted)

        guard !promotedIds.isEmpty else { return filters }
        let promotedSet = Set(promotedIds)

        let pinned = filters.filter { $0.id == "favorites" }
        let promoted = promotedIds.compactMap { id in filters.first { $0.id == id } }
        let rest = filters.filter { $0.id != "favorites" && !promotedSet.contains($0.id) }
        return pinned + promoted + rest
    }
}
