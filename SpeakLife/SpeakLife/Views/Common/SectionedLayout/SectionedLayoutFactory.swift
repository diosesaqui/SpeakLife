//
//  SectionedLayoutFactory.swift
//  SpeakLife
//
//  Created by Claude on 12/26/24.
//

import SwiftUI
import Foundation

// MARK: - Sectioned Layout Factory

/// Factory for creating sectioned layouts for different tabs
struct SectionedLayoutFactory {
    
    /// Creates a sectioned view for the given tab configuration
    static func createSectionedView<Provider: SectionProvider>(
        for tabConfig: SectionedTabConfig,
        with sectionProvider: Provider,
        onItemTap: @escaping (Provider.ContentType) -> Void,
        onFavoriteTap: @escaping (Provider.ContentType) -> Void
    ) -> AnyView {
        
        return AnyView(
            GenericSectionedView(
                sectionProvider: sectionProvider,
                onItemTap: onItemTap,
                onFavoriteTap: onFavoriteTap
            )
        )
    }
    
    /// Determines if a tab should use sectioned layout
    static func shouldUseSectionedLayout<Provider: SectionProvider>(
        for tabConfig: SectionedTabConfig,
        with sectionProvider: Provider
    ) -> Bool {
        return tabConfig.shouldUseSectionedLayout && 
               sectionProvider.shouldUseSectionedLayout
    }
    
    /// Creates appropriate section provider for tab
    static func createSectionProvider(
        for tabConfig: SectionedTabConfig,
        with viewModel: AudioDeclarationViewModel
    ) -> AudioSectionProvider {
        return AudioSectionProvider(viewModel: viewModel, tabConfig: tabConfig)
    }
}

// MARK: - Tab Configuration Helper

extension AudioDeclarationViewModel {
    
    /// Determines the current tab configuration based on selected filter
    var currentTabConfig: SectionedTabConfig {
        if !dynamicFilters.isEmpty {
            // Using dynamic filter system
            switch selectedFilterId.lowercased() {
            case "speaklife":
                return .speakLife
            case "devotional":
                return .devotionals
            case "declarations":
                return .declarations
            default:
                return .custom(selectedFilterId)
            }
        } else {
            // Using legacy filter system
            switch selectedFilter {
            case .speaklife:
                return .speakLife
            case .devotional:
                return .devotionals
            case .declarations:
                return .declarations
            default:
                return .custom(selectedFilter.rawValue)
            }
        }
    }
}

// MARK: - View Extension for Easy Usage

extension View {
    
    /// Conditionally shows sectioned or regular layout based on configuration
    func sectionedLayout<Content: View>(
        when condition: Bool,
        @ViewBuilder sectionedContent: () -> Content,
        @ViewBuilder regularContent: () -> Content
    ) -> some View {
        Group {
            if condition {
                sectionedContent()
            } else {
                regularContent()
            }
        }
    }
}