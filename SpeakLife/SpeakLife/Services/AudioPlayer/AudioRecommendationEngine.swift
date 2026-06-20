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

    /// Relative weights for each personalization signal. Stated intent
    /// (declaration, onboarding picks) outweighs revealed behavior (engagement,
    /// favorites, plays); the second-choice filter in a mapping is halved.
    private enum Weight {
        static let personalDeclaration = 100.0
        static let selectedCategory    = 30.0
        static let engagement          = 12.0
        static let favorite            = 8.0
        static let played              = 3.0
        static let secondaryFilter     = 0.5
        /// Cap on how many favorites / plays count, so a single high-volume
        /// category can't dominate purely by raw count.
        static let favoriteCountCap    = 5
        static let playedCountCap      = 8
    }

    /// Re-orders the curated audio filters so the categories the user cares about
    /// are promoted to the front. Filters are scored from both stated intent
    /// (personal declaration, onboarding categories) and revealed behavior
    /// (recency-weighted category engagement, favorites, and plays); the
    /// highest-scoring filters are promoted, with ties broken by curated order.
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
    ///   - engagementCategories: `DeclarationCategory` rawValue → recency-weighted
    ///     strength (e.g. from `UserPreferencesTracker.topCategories`).
    ///   - favoritesByFilterId: Filter id → number of favorited episodes.
    ///   - playedByFilterId: Filter id → number of played episodes.
    ///   - maxPromoted: Cap on how many filters float to the front.
    static func personalizedOrder(
        filters: [FilterConfig],
        personalDeclarationCategory: String?,
        selectedCategories: [String],
        engagementCategories: [String: Double] = [:],
        favoritesByFilterId: [String: Int] = [:],
        playedByFilterId: [String: Int] = [:],
        maxPromoted: Int = 3
    ) -> [FilterConfig] {
        guard filters.count > 1, maxPromoted > 0 else { return filters }

        var scores: [String: Double] = [:]
        func add(_ filterId: String, _ value: Double) {
            guard value > 0 else { return }
            scores[filterId, default: 0] += value
        }
        // A declaration category maps to one or two filters; the first gets the
        // full weight, the second a halved weight.
        func scoreMapping(for category: String?, base: Double) {
            guard base > 0, let raw = category?.lowercased(), !raw.isEmpty,
                  let mapped = categoryToFilterPriority[raw] else { return }
            for (index, id) in mapped.enumerated() {
                add(id, base * (index == 0 ? 1.0 : Weight.secondaryFilter))
            }
        }

        // 1. Personal declaration — strongest intent.
        scoreMapping(for: personalDeclarationCategory, base: Weight.personalDeclaration)

        // 2. Onboarding-selected categories — earlier picks weighted slightly higher.
        for (index, category) in selectedCategories.enumerated() {
            let positionFactor = max(0.5, 1.0 - Double(index) * 0.1)
            scoreMapping(for: category, base: Weight.selectedCategory * positionFactor)
        }

        // 3. Recency-weighted category engagement.
        for (category, strength) in engagementCategories {
            scoreMapping(for: category, base: Weight.engagement * strength)
        }

        // 4. Revealed behavior — favorites and plays map straight to a filter id.
        for (filterId, count) in favoritesByFilterId {
            add(filterId, Weight.favorite * Double(min(count, Weight.favoriteCountCap)))
        }
        for (filterId, count) in playedByFilterId {
            add(filterId, Weight.played * Double(min(count, Weight.playedCountCap)))
        }

        // Promote the highest-scoring filters; ties fall back to curated order.
        let curatedIndex = Dictionary(uniqueKeysWithValues: filters.enumerated().map { ($1.id, $0) })
        let candidates = scores.filter { $0.value > 0 && $0.key != "favorites" && curatedIndex[$0.key] != nil }
        guard !candidates.isEmpty else { return filters }

        let promotedIds = candidates.keys.sorted { lhs, rhs in
            if candidates[lhs]! != candidates[rhs]! { return candidates[lhs]! > candidates[rhs]! }
            return curatedIndex[lhs]! < curatedIndex[rhs]!
        }.prefix(maxPromoted)

        let promotedSet = Set(promotedIds)
        let pinned = filters.filter { $0.id == "favorites" }
        let promoted = promotedIds.compactMap { id in filters.first { $0.id == id } }
        let rest = filters.filter { $0.id != "favorites" && !promotedSet.contains($0.id) }
        return pinned + promoted + rest
    }
}
