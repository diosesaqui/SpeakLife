//
//  HorizontalAudioSection.swift
//  SpeakLife
//
//  Created by Claude on 12/26/24.
//

import SwiftUI

struct HorizontalAudioSection: View {
    let section: AudioSectionModel
    let onItemTap: (AudioDeclaration) -> Void
    let onFavoriteTap: (AudioDeclaration) -> Void
    let onSeeAllTap: () -> Void
    
    @EnvironmentObject var viewModel: AudioDeclarationViewModel
    @State private var scrollOffset: CGFloat = 0
    @State private var showLeftGradient = false
    @State private var showRightGradient = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section Header
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
                
                if section.configuration.showSeeAll && section.items.count > section.configuration.maxVisibleItems {
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
            
            // Horizontal scroll content
            ZStack {
                ScrollViewReader { scrollProxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: section.configuration.horizontalSpacing) {
                            ForEach(Array(section.items.prefix(section.configuration.maxVisibleItems).enumerated()), id: \.element.id) { index, item in
                                buildCell(for: item, at: index)
                                    .id("\(section.id)_\(item.id)")
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 4)
                    }
                }
                
                // Edge gradients for visual polish
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
        .padding(.vertical, 8)
    }
    
    @ViewBuilder
    private func buildCell(for item: AudioDeclaration, at index: Int) -> some View {
        let isFavorite = viewModel.favoritesManager.isFavorite(item)
        
        switch section.sectionType {
        case .featured:
            FeaturedAudioCell(
                item: item,
                configuration: section.configuration,
                isFavorite: isFavorite,
                onTap: { onItemTap(item) },
                onFavoriteTap: { onFavoriteTap(item) }
            )
            .transition(.asymmetric(
                insertion: .scale.combined(with: .opacity).animation(.spring(response: 0.4, dampingFraction: 0.8).delay(Double(index) * 0.05)),
                removal: .scale.combined(with: .opacity)
            ))
            
        case .favorites, .recent:
            OptimizedAudioCell(
                item: item,
                configuration: section.configuration,
                isFavorite: isFavorite,
                onTap: { onItemTap(item) },
                onFavoriteTap: { onFavoriteTap(item) }
            )
            .transition(.asymmetric(
                insertion: .scale.combined(with: .opacity).animation(.spring(response: 0.4, dampingFraction: 0.8).delay(Double(index) * 0.05)),
                removal: .scale.combined(with: .opacity)
            ))
            
        default:
            OptimizedAudioCell(
                item: item,
                configuration: section.configuration,
                isFavorite: isFavorite,
                onTap: { onItemTap(item) },
                onFavoriteTap: { onFavoriteTap(item) }
            )
        }
    }
}

// Featured cell for highlighted content
struct FeaturedAudioCell: View {
    let item: AudioDeclaration
    let configuration: SectionConfiguration
    let isFavorite: Bool
    let onTap: () -> Void
    let onFavoriteTap: () -> Void
    
    @State private var isPressed = false
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Background image
            Image(item.imageUrl)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: configuration.itemWidth, height: configuration.itemHeight)
                .clipped()
                .overlay(
                    LinearGradient(
                        colors: [.clear, .clear, .black.opacity(0.7)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            
            // Content overlay
            VStack(alignment: .leading, spacing: 6) {
                Spacer()
                
                if item.isPremium && !subscriptionStore.isPremium {
                    HStack(spacing: 4) {
                        Image(systemName: "lock.fill")
                            .font(.caption)
                        Text("PREMIUM")
                            .font(.caption.weight(.bold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.yellow.opacity(0.9))
                    )
                }
                
                Text(item.title)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(2)
                
                Text(item.subtitle)
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.9))
                    .lineLimit(1)
                
                HStack {
                    HStack(spacing: 4) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 10))
                        Text(item.duration)
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(.white.opacity(0.9))
                    
                    Spacer()
                    
                    Button(action: onFavoriteTap) {
                        Image(systemName: isFavorite ? "heart.fill" : "heart")
                            .font(.system(size: 20))
                            .foregroundColor(isFavorite ? .pink : .white)
                    }
                }
            }
            .padding(16)
        }
        .frame(width: configuration.itemWidth, height: configuration.itemHeight)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
        .onTapGesture {
            isPressed = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isPressed = false
            }
            onTap()
        }
    }
}