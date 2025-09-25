//
//  AudioSectionViewModel.swift
//  SpeakLife
//
//  Created by Claude on 12/26/24.
//

import Foundation
import SwiftUI

extension AudioDeclarationViewModel {
    
    var speakLifeSections: [AudioSectionModel] {
        // Check if it's speaklife filter (case-insensitive)
        let isSpeakLifeFilter = selectedFilterId.lowercased() == "speaklife" || selectedFilter == .speaklife
        
        guard isSpeakLifeFilter else { return [] }
        
        // Try to get content from dynamic system first, then fallback to legacy
        var allSpeakLife: [AudioDeclaration] = []
        
        if !contentByFilter.isEmpty {
            allSpeakLife = contentByFilter["speaklife"] ?? []
        }
        
        // If dynamic system has no content, use legacy speaklife array
        if allSpeakLife.isEmpty {
            allSpeakLife = speaklife
        }
        
        guard !allSpeakLife.isEmpty else { return [] }
        
        var sections: [AudioSectionModel] = []
        
        // 1. Favorites Section (if any)
        let favoriteItems = allSpeakLife.filter { favoritesManager.isFavorite($0) }
        if !favoriteItems.isEmpty {
            sections.append(AudioSectionModel(
                id: "favorites",
                title: "Your Favorites",
                subtitle: "\(favoriteItems.count) saved",
                items: Array(favoriteItems.prefix(10)),
                configuration: SectionConfiguration(
                    showSeeAll: false,
                    maxVisibleItems: 10,
                    itemWidth: 140,
                    itemHeight: 180,
                    horizontalSpacing: 10,
                    showPlayCount: false
                ),
                sectionType: .favorites
            ))
        }
        
        // 2. Recently Added Section (Latest episodes first)
        let sortedItems = allSpeakLife.sorted { item1, item2 in
            // Use new season/episode fields with fallback to parsing
            let season1 = item1.season ?? SpeakLifeEpisodeInfo.parse(from: item1.subtitle, id: item1.id)?.season ?? 0
            let episode1 = item1.episode ?? SpeakLifeEpisodeInfo.parse(from: item1.subtitle, id: item1.id)?.episode ?? 0
            let season2 = item2.season ?? SpeakLifeEpisodeInfo.parse(from: item2.subtitle, id: item2.id)?.season ?? 0
            let episode2 = item2.episode ?? SpeakLifeEpisodeInfo.parse(from: item2.subtitle, id: item2.id)?.episode ?? 0
            
            // Sort by season descending, then episode descending (newest first)
            if season1 != season2 {
                return season1 > season2
            }
            return episode1 > episode2
        }
        
        let recentItems = Array(sortedItems.prefix(15))
        if !recentItems.isEmpty {
            sections.append(AudioSectionModel(
                id: "recent",
                title: "Recently Added",
                subtitle: "Latest episodes",
                items: recentItems,
                configuration: SectionConfiguration(
                    showSeeAll: false,
                    maxVisibleItems: 10,
                    itemWidth: 160,
                    itemHeight: 200,
                    horizontalSpacing: 12,
                    showPlayCount: false
                ),
                sectionType: .recent
            ))
        }
        
        // 3. Dynamic Season-Based Sections
        let seasonSections = createSeasonBasedSections(from: allSpeakLife)
        sections.append(contentsOf: seasonSections)
        
        // 4. Continue Listening (placeholder for future implementation)
        // Could track partially played episodes
        
        return sections
    }
    
    private func createSeasonBasedSections(from audioItems: [AudioDeclaration]) -> [AudioSectionModel] {
        var seasonSections: [AudioSectionModel] = []
        
        // Group items by season using the new season field with fallback to parsing
        var seasonGroups: [Int: [AudioDeclaration]] = [:]
        
        for item in audioItems {
            var seasonNumber: Int?
            var episodeNumber: Int?
            
            // First try to use the new season/episode fields from JSON
            if let season = item.season {
                seasonNumber = season
                episodeNumber = item.episode
            } else {
                // Fallback to existing parsing logic for backwards compatibility
                if let episodeInfo = SpeakLifeEpisodeInfo.parse(from: item.subtitle, id: item.id) {
                    seasonNumber = episodeInfo.season
                    episodeNumber = episodeInfo.episode
                }
            }
            
            if let season = seasonNumber {
                if seasonGroups[season] == nil {
                    seasonGroups[season] = []
                }
                seasonGroups[season]?.append(item)
            }
        }
        
        // Create sections for each season (sorted by season number descending)
        let sortedSeasons = seasonGroups.keys.sorted { $0 > $1 }
        
        for seasonNumber in sortedSeasons {
            guard let items = seasonGroups[seasonNumber] else { continue }
            
            // Sort episodes within season by episode number ascending (1, 2, 3...)
            let sortedEpisodes = items.sorted { item1, item2 in
                let ep1 = item1.episode ?? getEpisodeFromParsing(item1)
                let ep2 = item2.episode ?? getEpisodeFromParsing(item2)
                return (ep1 ?? 0) < (ep2 ?? 0)
            }
            
            seasonSections.append(AudioSectionModel(
                id: "speaklife-season-\(seasonNumber)",
                title: "Season \(seasonNumber)",
                subtitle: "\(items.count) episodes",
                items: sortedEpisodes,
                configuration: SectionConfiguration(
                    showSeeAll: false, 
                    maxVisibleItems: min(items.count, 15), // Show up to 15 episodes, or all if fewer
                    itemWidth: 160,
                    itemHeight: 200,
                    horizontalSpacing: 12,
                    showPlayCount: false
                ),
                sectionType: .standard
            ))
        }
        
        return seasonSections
    }
    
    // Helper function for backward compatibility
    private func getEpisodeFromParsing(_ item: AudioDeclaration) -> Int? {
        return SpeakLifeEpisodeInfo.parse(from: item.subtitle, id: item.id)?.episode
    }
    
    private func createTopicBasedSections(from audioItems: [AudioDeclaration]) -> [AudioSectionModel] {
        var topicSections: [AudioSectionModel] = []
        
        for topic in AudioTopicCategory.allCases {
            let topicItems = audioItems.filter { item in
                categorizeAudioContent(item).contains(topic)
            }
            
            if !topicItems.isEmpty {
                topicSections.append(AudioSectionModel(
                    id: topic.rawValue,
                    title: topic.displayName,
                    subtitle: "\(topicItems.count) sessions",
                    items: Array(topicItems.prefix(10)),
                    configuration: .default,
                    sectionType: .standard
                ))
            }
        }
        
        // Sort sections by item count (most content first)
        return topicSections.sorted { $0.items.count > $1.items.count }
    }
    
    private func categorizeAudioContent(_ item: AudioDeclaration) -> [AudioTopicCategory] {
        let text = "\(item.title) \(item.subtitle)".lowercased()
        var categories: [AudioTopicCategory] = []
        
        for topic in AudioTopicCategory.allCases {
            for keyword in topic.keywords {
                if text.contains(keyword) {
                    categories.append(topic)
                    break
                }
            }
        }
        
        // If no category found, check for daily essentials keywords
        if categories.isEmpty && (text.contains("affirmation") || text.contains("declaration")) {
            categories.append(.dailyEssentials)
        }
        
        return categories
    }
    
    private func extractMinutes(from duration: String) -> Int {
        // Parse duration string like "5:30" or "10:45"
        let components = duration.split(separator: ":")
        guard components.count >= 1,
              let minutes = Int(components[0]) else { return 0 }
        return minutes
    }
    
    // Get full list for a specific section
    func getFullSectionItems(sectionId: String) -> [AudioDeclaration] {
        // Always use speaklife data regardless of current filter since this is for SpeakLife sections
        let allSpeakLife = !contentByFilter.isEmpty ? (contentByFilter["speaklife"] ?? speaklife) : speaklife
        
        let result: [AudioDeclaration]
        
        switch sectionId {
        case "favorites":
            result = allSpeakLife.filter { favoritesManager.isFavorite($0) }
        case "recent":
            // Return sorted items (latest episodes first)
            let sortedItems = allSpeakLife.sorted { item1, item2 in
                let episode1 = SpeakLifeEpisodeInfo.parse(from: item1.subtitle, id: item1.id)
                let episode2 = SpeakLifeEpisodeInfo.parse(from: item2.subtitle, id: item2.id)
                
                if let ep1 = episode1, let ep2 = episode2 {
                    if ep1.season != ep2.season {
                        return ep1.season > ep2.season
                    }
                    return ep1.episode > ep2.episode
                }
                return false
            }
            result = sortedItems
        case "featured":
            result = allSpeakLife.filter { 
                let durationMinutes = extractMinutes(from: $0.duration)
                return durationMinutes >= 10
            }
        case "quick":
            result = allSpeakLife.filter { 
                let durationMinutes = extractMinutes(from: $0.duration)
                return durationMinutes > 0 && durationMinutes <= 5
            }
        default:
            // Check if it's a season key (s1, s2, s3, etc.)
            if sectionId.starts(with: "s") && sectionId.dropFirst().allSatisfy({ $0.isNumber }) {
                result = allSpeakLife.filter { item in
                    if let episodeInfo = SpeakLifeEpisodeInfo.parse(from: item.subtitle, id: item.id) {
                        return episodeInfo.seasonKey == sectionId
                    }
                    return false
                }.sorted { item1, item2 in
                    // Sort episodes within season by episode number descending
                    let ep1 = SpeakLifeEpisodeInfo.parse(from: item1.subtitle, id: item1.id)
                    let ep2 = SpeakLifeEpisodeInfo.parse(from: item2.subtitle, id: item2.id)
                    return (ep1?.episode ?? 0) > (ep2?.episode ?? 0)
                }
            }
            // Check if it's a topic category
            else if let topic = AudioTopicCategory(rawValue: sectionId) {
                result = allSpeakLife.filter { item in
                    categorizeAudioContent(item).contains(topic)
                }
            } else {
                result = []
            }
        }
        
        return result
    }
}
