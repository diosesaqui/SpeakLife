//
//  AudioRecommendationEngine.swift
//  SpeakLife
//
//  Maps user's onboarding DeclarationCategory preferences to the most relevant
//  audio filter, then surfaces the first unplayed episode in that filter.
//
//  Usage:
//    let rec = AudioRecommendationEngine.recommend(
//        userCategories: ["anxiety", "identity"],
//        contentByFilter: audioDeclarationViewModel.contentByFilter,
//        availableFilterIds: audioDeclarationViewModel.dynamicFilters.map { $0.id }
//    )
//    audioDeclarationViewModel.setSelectedFilter(rec.filterId)
//    // rec.episode is the specific AudioDeclaration to highlight / auto-scroll to
//

import Foundation

// MARK: - Recommendation Result

struct AudioRecommendation {
    /// The filter ID to switch to in AudioDeclarationViewModel
    let filterId: String
    /// The specific episode to highlight (first unplayed, or first in filter if all played)
    let episode: AudioDeclaration?
}

// MARK: - Engine

final class AudioRecommendationEngine {

    // MARK: - Category → Filter Priority Map
    //
    // Keys = DeclarationCategory.rawValue (lowercase).
    // Values = ordered list of audio filter IDs to try. First available wins.
    // Audio filter IDs come from FilterConfig.id in AudioDeclarationViewModel.

    static let categoryToFilterPriority: [String: [String]] = [
        // Emotional / Mental health
        "anxiety":        ["meditation", "speaklife"],
        "fear":           ["meditation", "speaklife"],
        "hardtimes":      ["speaklife", "growWithJesus"],
        "addiction":      ["speaklife", "declarations"],

        // Identity / Purpose
        "identity":       ["meditation", "speaklife"],
        "confidence":     ["speaklife", "declarations"],
        "destiny":        ["speaklife", "growWithJesus"],
        "purity":         ["speaklife"],

        // Spiritual growth
        "faith":          ["speaklife", "growWithJesus"],
        "grace":          ["growWithJesus", "speaklife"],
        "hope":           ["speaklife", "growWithJesus"],
        "general":        ["growWithJesus", "speaklife"],
        "godsheart":      ["godsHeart", "speaklife"],
        "heaven":         ["gospel", "speaklife"],
        "friendship":     ["growWithJesus"],

        // Warfare / Protection
        "warfare":        ["divineHealth", "declarations"],
        "godsprotection": ["psalm91", "declarations"],

        // Health
        "health":         ["divineHealth", "declarations"],

        // Wisdom
        "wisdom":         ["meditation"],

        // Emotional connection
        "joy":            ["meditation", "speaklife"],
        "love":           ["meditation", "declarations"],
        "gratitude":      ["meditation", "declarations"],
        "praise":         ["meditation"],
        "rest":           ["meditation"],

        // Relationships
        "marriage":       ["declarations"],
        "parenting":      ["declarations"],
        "friendship":     ["growWithJesus"],
        "innerhealing":   ["growWithJesus", "declarations"],

        // Provision
        "wealth":         ["declarations"],
        "favor":          ["declarations"],
        "work":           ["declarations"],

        // Other
        "miracles":       ["declarations"],
        "speaklife":      ["speaklife"],
    ]

    static let defaultFilterId = "speaklife"

    // MARK: - Public API

    /// Returns the best filter and next unplayed episode for the user's selected categories.
    /// - Parameters:
    ///   - userCategories: Raw values from the user's `userSelectedCategories` UserDefaults key
    ///   - contentByFilter: The AudioDeclarationViewModel's contentByFilter dictionary
    ///   - availableFilterIds: The filter IDs currently available (from dynamicFilters)
    /// - Returns: An `AudioRecommendation` with filterId + optional first unplayed episode
    static func recommend(
        userCategories: [String],
        contentByFilter: [String: [AudioDeclaration]],
        availableFilterIds: [String]
    ) -> AudioRecommendation {
        let filterId = bestFilterId(
            for: userCategories,
            availableFilterIds: availableFilterIds
        )
        let content = contentByFilter[filterId] ?? []
        let episode = firstUnplayed(in: content)
        return AudioRecommendation(filterId: filterId, episode: episode)
    }

    // MARK: - Private Helpers

    /// Walks the user's categories in order, returning the first filter that:
    ///   (a) appears in the category-to-filter priority list, AND
    ///   (b) exists in the currently available filter IDs.
    /// Falls back to `defaultFilterId` ("speaklife") if nothing matches.
    private static func bestFilterId(
        for userCategories: [String],
        availableFilterIds: [String]
    ) -> String {
        let availableSet = Set(availableFilterIds)
        for category in userCategories {
            let key = category.lowercased()
            guard let preferred = categoryToFilterPriority[key] else { continue }
            for filterId in preferred {
                if availableSet.contains(filterId) {
                    return filterId
                }
            }
        }
        if availableSet.contains(defaultFilterId) { return defaultFilterId }
        return availableFilterIds.first(where: { $0 != "favorites" }) ?? defaultFilterId
    }

    /// First episode the user hasn't listened to past 50%.
    /// If all episodes are played, falls back to episode 1 (restart from beginning).
    private static func firstUnplayed(in content: [AudioDeclaration]) -> AudioDeclaration? {
        content.first { !AudioProgressStore.shared.isPlayed($0.id) } ?? content.first
    }
}
