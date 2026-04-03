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

    static func recommend(
        userCategories: [String],
        contentByFilter: [String: [AudioDeclaration]],
        availableFilterIds: [String]
    ) -> AudioRecommendation {
        let filterId = bestFilterId(for: userCategories, availableFilterIds: availableFilterIds)
        let content = contentByFilter[filterId] ?? []
        let episode = firstUnplayed(in: content)
        return AudioRecommendation(filterId: filterId, episode: episode)
    }

    private static func bestFilterId(for userCategories: [String], availableFilterIds: [String]) -> String {
        let availableSet = Set(availableFilterIds)
        for category in userCategories {
            guard let preferred = categoryToFilterPriority[category.lowercased()] else { continue }
            for filterId in preferred where availableSet.contains(filterId) { return filterId }
        }
        return availableSet.contains(defaultFilterId) ? defaultFilterId :
               (availableFilterIds.first(where: { $0 != "favorites" }) ?? defaultFilterId)
    }

    private static func firstUnplayed(in content: [AudioDeclaration]) -> AudioDeclaration? {
        content.first { !AudioProgressStore.shared.isPlayed($0.id) } ?? content.first
    }
}
