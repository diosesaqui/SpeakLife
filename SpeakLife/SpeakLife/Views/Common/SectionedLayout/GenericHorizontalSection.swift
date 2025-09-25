//
//  GenericHorizontalSection.swift
//  SpeakLife
//
//  Created by Claude on 12/26/24.
//

import SwiftUI

// MARK: - Generic Horizontal Section

struct GenericHorizontalSection<ContentType: SectionableContent>: View {
    let section: GenericSectionModel<ContentType>
    let onItemTap: (ContentType) -> Void
    let onFavoriteTap: (ContentType) -> Void
    let onSeeAllTap: () -> Void
    
    @State private var scrollOffset: CGFloat = 0
    @State private var showLeftGradient = false
    @State private var showRightGradient = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section Header
            sectionHeader
            
            // Horizontal scroll content
            ZStack {
                ScrollViewReader { scrollProxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: section.configuration.horizontalSpacing) {
                            ForEach(Array(section.items.prefix(section.configuration.maxVisibleItems).enumerated()), id: \.element.id) { index, item in
                                GenericContentCell(
                                    item: item,
                                    configuration: section.configuration,
                                    isFavorite: false, // This would need to be determined by the parent
                                    onTap: { onItemTap(item) },
                                    onFavoriteTap: { onFavoriteTap(item) }
                                )
                                .id("\(section.id)_\(item.id)")
                                .transition(.asymmetric(
                                    insertion: .scale.combined(with: .opacity)
                                        .animation(.spring(response: 0.4, dampingFraction: 0.8)
                                        .delay(Double(index) * 0.05)),
                                    removal: .scale.combined(with: .opacity)
                                ))
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 4)
                    }
                }
                
                // Edge gradients for visual polish
                edgeGradients
            }
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Private Views
    
    private var sectionHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(section.title)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                
                if let subtitle = section.subtitle {
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            
            Spacer()
            
            if section.configuration.showSeeAll && 
               section.items.count > section.configuration.maxVisibleItems {
                Button(action: onSeeAllTap) {
                    HStack(spacing: 4) {
                        Text("See All")
                            .font(.system(size: 14, weight: .medium))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(Constants.DAMidBlue)
                }
            }
        }
        .padding(.horizontal, 20)
    }
    
    private var edgeGradients: some View {
        HStack {
            if showLeftGradient {
                LinearGradient(
                    colors: [Color.black.opacity(0.3), .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: 20)
                .allowsHitTesting(false)
            }
            
            Spacer()
            
            if showRightGradient && section.items.count > 3 {
                LinearGradient(
                    colors: [.clear, Color.black.opacity(0.3)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: 20)
                .allowsHitTesting(false)
            }
        }
    }
}