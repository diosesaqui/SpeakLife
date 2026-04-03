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

    /// Recommends the next audio episode, cycling through the user's categories as each is exhausted.
    ///
    /// Rotation logic:
    ///   1. Look up the user's current category index (persisted in UserDefaults).
    ///   2. Find the first unplayed episode in that category's filter.
    ///   3. If all episodes in the current category are played → advance index → try next category.
    ///   4. If all categories exhausted → wrap back to index 0.
    static func recommend(
        userCategories: [String],
        contentByFilter: [String: [AudioDeclaration]],
        availableFilterIds: [String]
    ) -> AudioRecommendation {
        let categories = userCategories.isEmpty ? [defaultFilterId] : userCategories
        let savedIndex = UserDefaults.standard.integer(forKey: categoryIndexKey)
        let startIndex = savedIndex % categories.count

        // Walk categories starting at current index, wrapping around
        for offset in 0..<categories.count {
            let index = (startIndex + offset) % categories.count
            let category = categories[index]
            let filterId = preferredFilterId(for: category, availableFilterIds: availableFilterIds)
            let content = contentByFilter[filterId] ?? []

            if let unplayed = content.first(where: { !AudioProgressStore.shared.isPlayed($0.id) }) {
                // Found an unplayed episode — advance index if we moved to a new category
                if index != startIndex {
                    UserDefaults.standard.set(index, forKey: categoryIndexKey)
                }
                return AudioRecommendation(filterId: filterId, episode: unplayed)
            }
            // All played in this category → try the next one
        }

        // All categories fully played — wrap to 0 and restart from the beginning
        UserDefaults.standard.set(0, forKey: categoryIndexKey)
        let fallbackCategory = categories[0]
        let fallbackFilter = preferredFilterId(for: fallbackCategory, availableFilterIds: availableFilterIds)
        let fallbackContent = contentByFilter[fallbackFilter] ?? []
        return AudioRecommendation(filterId: fallbackFilter, episode: fallbackContent.first)
    }

    /// Manually advances to the next category (call when a category's content is fully completed).
    static func advanceCategory(userCategories: [String]) {
        let categories = userCategories.isEmpty ? [defaultFilterId] : userCategories
        let current = UserDefaults.standard.integer(forKey: categoryIndexKey)
        let next = (current + 1) % categories.count
        UserDefaults.standard.set(next, forKey: categoryIndexKey)
    }

    // MARK: - Private Helpers

    /// Public so ModernDailyChecklistView can set the filter before content loads.
    static func bestFilterId(for userCategories: [String], availableFilterIds: [String]) -> String {
        for category in userCategories {
            if let filterId = preferredFilterId(for: category, availableFilterIds: availableFilterIds),
               filterId != defaultFilterId || availableFilterIds.contains(defaultFilterId) {
                return filterId
            }
        }
        return availableFilterIds.contains(defaultFilterId) ? defaultFilterId :
               (availableFilterIds.first(where: { $0 != "favorites" }) ?? defaultFilterId)
    }

    private static func preferredFilterId(for category: String, availableFilterIds: [String]) -> String? {
        let availableSet = Set(availableFilterIds)
        guard let preferred = categoryToFilterPriority[category.lowercased()] else { return nil }
        return preferred.first(where: { availableSet.contains($0) })
    }

    private static func firstUnplayed(in content: [AudioDeclaration]) -> AudioDeclaration? {
        content.first { !AudioProgressStore.shared.isPlayed($0.id) } ?? content.first
    }
}
