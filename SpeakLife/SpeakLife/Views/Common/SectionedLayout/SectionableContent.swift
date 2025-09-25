//
//  SectionableContent.swift
//  SpeakLife
//
//  Created by Claude on 12/26/24.
//

import Foundation

// MARK: - Generic Content Protocol

/// Protocol for any content that can be displayed in sections
protocol SectionableContent: Identifiable, Hashable {
    var id: String { get }
    var title: String { get }
    var subtitle: String { get }
    var imageUrl: String { get }
    var isPremium: Bool { get }
    
    // Optional properties with defaults
    var duration: String? { get }
    var tag: String? { get }
}

// Default implementations for optional properties
extension SectionableContent {
    var duration: String? { nil }
    var tag: String? { nil }
}

// MARK: - AudioDeclaration Conformance

extension AudioDeclaration: SectionableContent {
    // AudioDeclaration already has duration (String) and tag (String?) properties
    // No additional implementation needed
}

// MARK: - Generic Section Configuration

struct GenericSectionConfiguration {
    let showSeeAll: Bool
    let maxVisibleItems: Int
    let itemWidth: CGFloat
    let itemHeight: CGFloat
    let horizontalSpacing: CGFloat
    let showPlayCount: Bool
    let cellStyle: SectionCellStyle
    
    enum SectionCellStyle: Equatable {
        case standard
        case compact
        case featured
        case custom(CGFloat, CGFloat) // width, height
    }
    
    static let `default` = GenericSectionConfiguration(
        showSeeAll: false,
        maxVisibleItems: 10,
        itemWidth: 160,
        itemHeight: 200,
        horizontalSpacing: 12,
        showPlayCount: false,
        cellStyle: .standard
    )
    
    static let compact = GenericSectionConfiguration(
        showSeeAll: false,
        maxVisibleItems: 10,
        itemWidth: 140,
        itemHeight: 180,
        horizontalSpacing: 10,
        showPlayCount: false,
        cellStyle: .compact
    )
    
    static let featured = GenericSectionConfiguration(
        showSeeAll: false,
        maxVisibleItems: 5,
        itemWidth: 280,
        itemHeight: 160,
        horizontalSpacing: 16,
        showPlayCount: true,
        cellStyle: .featured
    )
}

// MARK: - Generic Section Types

enum GenericSectionType {
    case featured
    case favorites
    case recent
    case standard
    case continueListening
    case custom(String)
}

// MARK: - Generic Section Model

struct GenericSectionModel<T: SectionableContent>: Identifiable {
    let id: String
    let title: String
    let subtitle: String?
    let items: [T]
    let configuration: GenericSectionConfiguration
    let sectionType: GenericSectionType
    
    init(
        id: String,
        title: String,
        subtitle: String? = nil,
        items: [T],
        configuration: GenericSectionConfiguration = .default,
        sectionType: GenericSectionType = .standard
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.items = items
        self.configuration = configuration
        self.sectionType = sectionType
    }
}
