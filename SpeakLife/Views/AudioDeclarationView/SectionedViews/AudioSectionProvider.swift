//
//  AudioSectionProvider.swift
//  SpeakLife
//
//  Created by Claude on 12/26/24.
//

import Foundation

// MARK: - Audio Section Provider

/// Concrete implementation of SectionProvider for AudioDeclaration content
class AudioSectionProvider: SectionProvider {
    typealias ContentType = AudioDeclaration
    
    private let viewModel: AudioDeclarationViewModel
    private let tabConfig: SectionedTabConfig
    
    init(viewModel: AudioDeclarationViewModel, tabConfig: SectionedTabConfig) {
        self.viewModel = viewModel
        self.tabConfig = tabConfig
    }
    
    var sections: [GenericSectionModel<AudioDeclaration>] {
        switch tabConfig {
        case .speakLife:
            return createSpeakLifeSections()
        case .devotionals:
            return createDevotionalSections()
        case .declarations:
            return createDeclarationSections()
        case .testimonies:
            return createTestimonySections()
        case .custom(let identifier):
            // Handle specific custom filters here
            // Example for a new filter:
            // if identifier == "yournewfilter" {
            //     return createYourNewFilterSections()
            // }
            return createCustomSections(for: identifier)
        }
    }
    
    var shouldUseSectionedLayout: Bool {
        tabConfig.shouldUseSectionedLayout && !sections.isEmpty
    }
    
    func getFullSectionItems(sectionId: String) -> [AudioDeclaration] {
        switch tabConfig {
        case .speakLife:
            return viewModel.getFullSectionItems(sectionId: sectionId)
        case .devotionals:
            return getDevotionalSectionItems(sectionId: sectionId)
        default:
            return []
        }
    }
    
    // MARK: - Private Section Creators
    
    private func createSpeakLifeSections() -> [GenericSectionModel<AudioDeclaration>] {
        // Reuse existing speakLifeSections logic but convert to generic format
        return viewModel.speakLifeSections.map { oldSection in
            GenericSectionModel(
                id: oldSection.id,
                title: oldSection.title,
                subtitle: oldSection.subtitle,
                items: oldSection.items,
                configuration: convertConfiguration(oldSection.configuration),
                sectionType: convertSectionType(oldSection.sectionType)
            )
        }
    }
    
    private func createDevotionalSections() -> [GenericSectionModel<AudioDeclaration>] {
        // Future implementation for devotionals
        guard let devotionalContent = getDevotionalContent() else { return [] }
        
        var sections: [GenericSectionModel<AudioDeclaration>] = []
        
        // Daily Devotions
        let dailyDevotions = devotionalContent.filter { item in
            item.subtitle.lowercased().contains("daily") ||
            item.title.lowercased().contains("daily")
        }
        
        if !dailyDevotions.isEmpty {
            sections.append(GenericSectionModel(
                id: "daily-devotions",
                title: "Daily Devotions",
                subtitle: "\(dailyDevotions.count) devotions",
                items: Array(dailyDevotions.prefix(10)),
                configuration: .default,
                sectionType: .standard
            ))
        }
        
        // Weekly Series
        let weeklySeries = organizeWeeklySeries(from: devotionalContent)
        sections.append(contentsOf: weeklySeries)
        
        return sections
    }
    
    private func createDeclarationSections() -> [GenericSectionModel<AudioDeclaration>] {
        // Future implementation for declarations
        return []
    }
    
    private func createTestimonySections() -> [GenericSectionModel<AudioDeclaration>] {
        // Future implementation for testimonies
        return []
    }
    
    private func createCustomSections(for identifier: String) -> [GenericSectionModel<AudioDeclaration>] {
        // Get content for this filter
        guard let filterContent = viewModel.contentByFilter[identifier], !filterContent.isEmpty else {
            return []
        }
        
        var sections: [GenericSectionModel<AudioDeclaration>] = []
        
        // 1. Favorites Section (if any)
//        let favoriteItems = filterContent.filter { viewModel.favoritesManager.isFavorite($0) }
//        if !favoriteItems.isEmpty {
//            sections.append(GenericSectionModel(
//                id: "\(identifier)-favorites",
//                title: "Your Favorites",
//                subtitle: "\(favoriteItems.count) saved",
//                items: Array(favoriteItems.prefix(10)),
//                configuration: GenericSectionConfiguration(
//                    showSeeAll: favoriteItems.count > 10,
//                    maxVisibleItems: 10,
//                    itemWidth: 140,
//                    itemHeight: 180,
//                    horizontalSpacing: 10,
//                    showPlayCount: false,
//                    cellStyle: .standard
//                ),
//                type: .favorites
//            ))
//        }
        
        // 2. Check if content has seasons/episodes
        let itemsWithSeasons = filterContent.filter { $0.season != nil }
//        
//        if !itemsWithSeasons.isEmpty {
            // Create season-based sections
            let seasonGroups = Dictionary(grouping: itemsWithSeasons) { $0.season ?? 0 }
            let sortedSeasons = seasonGroups.keys.sorted()
            
            for season in sortedSeasons {
                guard let seasonItems = seasonGroups[season] else { continue }
                let sortedEpisodes = seasonItems.sorted { ($0.episode ?? 0) < ($1.episode ?? 0) }
                
                sections.append(GenericSectionModel(
                    id: "\(identifier)-season-\(season)",
                    title: "Season \(season)",
                    subtitle: "\(seasonItems.count) episodes",
                    items: sortedEpisodes,
                    configuration: GenericSectionConfiguration(
                        showSeeAll: false,
                        maxVisibleItems: min(15, seasonItems.count),
                        itemWidth: 160,
                        itemHeight: 200,
                        horizontalSpacing: 12,
                        showPlayCount: false,
                        cellStyle: .standard
                    )
                ))
            }
            
            // Handle items without seasons separately if any exist
            let itemsWithoutSeasons = filterContent.filter { $0.season == nil }
            if !itemsWithoutSeasons.isEmpty {
                sections.append(GenericSectionModel(
                    id: "\(identifier)-other",
                    title: "More \(identifier.capitalized)",
                    subtitle: "\(itemsWithoutSeasons.count) items",
                    items: itemsWithoutSeasons,
                    configuration: GenericSectionConfiguration(
                        showSeeAll: false,
                        maxVisibleItems: min(15, itemsWithoutSeasons.count),
                        itemWidth: 160,
                        itemHeight: 200,
                        horizontalSpacing: 12,
                        showPlayCount: false,
                        cellStyle: .standard
                    )
                ))
            }
     //   } else {
            // No seasons - create smart sections based on content analysis
            
            // 2. Recently Added Section (first 15 items, assuming newer items are at the beginning)
            let recentItems = Array(filterContent.prefix(15))
            if !recentItems.isEmpty {
                sections.append(GenericSectionModel(
                    id: "\(identifier)-recent",
                    title: "Recently Added",
                    subtitle: "Latest content",
                    items: recentItems,
                    configuration: GenericSectionConfiguration(
                        showSeeAll: false,
                        maxVisibleItems: 10,
                        itemWidth: 160,
                        itemHeight: 200,
                        horizontalSpacing: 12,
                        showPlayCount: false,
                        cellStyle: .standard
                    )
                ))
            }
            
            // 3. Quick Sessions (items under 5 minutes)
//            let quickItems = filterContent.filter { item in
//                let minutes = extractMinutes(from: item.duration)
//                return minutes > 0 && minutes <= 5
//            }
//            if !quickItems.isEmpty {
//                sections.append(GenericSectionModel(
//                    id: "\(identifier)-quick",
//                    title: "Quick Sessions",
//                    subtitle: "5 minutes or less",
//                    items: Array(quickItems.prefix(10)),
//                    configuration: GenericSectionConfiguration(
//                        showSeeAll: quickItems.count > 10,
//                        maxVisibleItems: 10,
//                        itemWidth: 140,
//                        itemHeight: 180,
//                        horizontalSpacing: 10,
//                        showPlayCount: false,
//                        cellStyle: .compact
//                    ),
//                    type: .standard
//                ))
//            }
//            
//            // 4. Featured/Longer Sessions (items over 10 minutes)
//            let featuredItems = filterContent.filter { item in
//                let minutes = extractMinutes(from: item.duration)
//                return minutes >= 10
//            }
//            if !featuredItems.isEmpty {
//                sections.append(GenericSectionModel(
//                    id: "\(identifier)-featured",
//                    title: "Deep Dives",
//                    subtitle: "Extended sessions",
//                    items: Array(featuredItems.prefix(10)),
//                    configuration: GenericSectionConfiguration(
//                        showSeeAll: featuredItems.count > 10,
//                        maxVisibleItems: 10,
//                        itemWidth: 180,
//                        itemHeight: 220,
//                        horizontalSpacing: 12,
//                        showPlayCount: false,
//                        cellStyle: .featured
//                    ),
//                    type: .standard
//                ))
//            }
            
            // 5. All Content (if we have more items than shown in sections above)
//            let shownItemsCount = (favoriteItems.count > 0 ? min(10, favoriteItems.count) : 0) +
//                                  min(10, recentItems.count) +
//                                  (quickItems.count > 0 ? min(10, quickItems.count) : 0) +
//                                  (featuredItems.count > 0 ? min(10, featuredItems.count) : 0)
//            
//            if filterContent.count > shownItemsCount {
//                sections.append(GenericSectionModel(
//                    id: "\(identifier)-all",
//                    title: "Browse All",
//                    subtitle: "\(filterContent.count) total items",
//                    items: filterContent,
//                    configuration: GenericSectionConfiguration(
//                        showSeeAll: false,
//                        maxVisibleItems: min(20, filterContent.count),
//                        itemWidth: 160,
//                        itemHeight: 200,
//                        horizontalSpacing: 12,
//                        showPlayCount: false,
//                        cellStyle: .standard
//                    ),
//                    type: .standard
//                ))
         //   }
      //  }
        
        return sections
   // }
}
    
    private func extractMinutes(from duration: String) -> Int {
        // Parse duration string like "5:30" or "10:45"
        let components = duration.split(separator: ":")
        guard components.count >= 1,
              let minutes = Int(components[0]) else { return 0 }
        return minutes
    }
    
    // MARK: - Helper Methods
    
    private func convertConfiguration(_ oldConfig: SectionConfiguration) -> GenericSectionConfiguration {
        return GenericSectionConfiguration(
            showSeeAll: oldConfig.showSeeAll,
            maxVisibleItems: oldConfig.maxVisibleItems,
            itemWidth: oldConfig.itemWidth,
            itemHeight: oldConfig.itemHeight,
            horizontalSpacing: oldConfig.horizontalSpacing,
            showPlayCount: oldConfig.showPlayCount,
            cellStyle: convertCellStyle(from: oldConfig)
        )
    }
    
    private func convertSectionType(_ oldType: SectionType) -> GenericSectionType {
        switch oldType {
        case .featured:
            return .featured
        case .favorites:
            return .favorites
        case .recent:
            return .recent
        case .standard:
            return .standard
        case .continueListening:
            return .continueListening
        }
    }
    
    private func convertCellStyle(from config: SectionConfiguration) -> GenericSectionConfiguration.SectionCellStyle {
        // Determine cell style based on configuration
        if config.itemWidth > 250 {
            return .featured
        } else if config.itemWidth < 150 {
            return .compact
        } else {
            return .standard
        }
    }
    
    private func getDevotionalContent() -> [AudioDeclaration]? {
        // Get devotional content from viewModel
        // This would be implemented when devotionals are ready
        return nil
    }
    
    private func organizeWeeklySeries(from items: [AudioDeclaration]) -> [GenericSectionModel<AudioDeclaration>] {
        // Group devotionals by week/series
        // Future implementation
        return []
    }
    
    private func getDevotionalSectionItems(sectionId: String) -> [AudioDeclaration] {
        // Future implementation for devotional section items
        return []
    }
}

// MARK: - Audio Content Action Handler

/// Handles actions for audio content
class AudioContentActionHandler: ContentActionHandler {
    typealias ContentType = AudioDeclaration
    
    private let viewModel: AudioDeclarationViewModel
    
    init(viewModel: AudioDeclarationViewModel) {
        self.viewModel = viewModel
    }
    
    func handleItemTap(_ item: AudioDeclaration) {
        // Implementation would be injected from parent view
    }
    
    func handleFavoriteTap(_ item: AudioDeclaration) {
        viewModel.favoritesManager.toggleFavorite(item)
    }
    
    func handleDownload(_ item: AudioDeclaration) {
        // Future implementation for download functionality
    }
    
    func isFavorite(_ item: AudioDeclaration) -> Bool {
        return viewModel.favoritesManager.isFavorite(item)
    }
}
