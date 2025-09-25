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
        // Future implementation for custom tabs
        return []
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