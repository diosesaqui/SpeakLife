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
}
