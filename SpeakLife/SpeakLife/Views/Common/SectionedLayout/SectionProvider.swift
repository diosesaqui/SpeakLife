//
//  SectionProvider.swift
//  SpeakLife
//
//  Created by Claude on 12/26/24.
//

import Foundation

// MARK: - Section Provider Protocol

/// Protocol for any service that can provide sectioned content
protocol SectionProvider {
    associatedtype ContentType: SectionableContent
    
    /// The main sections to display
    var sections: [GenericSectionModel<ContentType>] { get }
    
    /// Get full list of items for a specific section (for "See All" functionality)
    func getFullSectionItems(sectionId: String) -> [ContentType]
    
    /// Check if sectioned layout should be used for current state
    var shouldUseSectionedLayout: Bool { get }
}

// MARK: - Tab Configuration

enum SectionedTabConfig {
    case speakLife
    case devotionals
    case declarations
    case testimonies
    case custom(String)
    
    var shouldUseSectionedLayout: Bool {
        switch self {
        case .speakLife:
            return true
        case .devotionals:
            return false // Can be enabled later
        case .declarations:
            return false
        case .testimonies:
            return false
        case .custom:
            return true
        }
    }
    
    var identifier: String {
        switch self {
        case .speakLife:
            return "speaklife"
        case .devotionals:
            return "devotional"
        case .declarations:
            return "declarations"
        case .testimonies:
            return "testimonies"
        case .custom(let id):
            return id
        }
    }
}

// MARK: - Generic Content Actions

/// Protocol for handling content interactions
protocol ContentActionHandler {
    associatedtype ContentType: SectionableContent
    
    func handleItemTap(_ item: ContentType)
    func handleFavoriteTap(_ item: ContentType)
    func handleDownload(_ item: ContentType)
    func isFavorite(_ item: ContentType) -> Bool
}

// MARK: - Section Content Organizer

/// Helper for organizing content into logical sections
protocol SectionContentOrganizer {
    associatedtype ContentType: SectionableContent
    
    func organizeFavorites(from items: [ContentType]) -> [ContentType]
    func organizeRecent(from items: [ContentType]) -> [ContentType]
    func organizeFeatured(from items: [ContentType]) -> [ContentType]
    func organizeByCategory(from items: [ContentType]) -> [String: [ContentType]]
}