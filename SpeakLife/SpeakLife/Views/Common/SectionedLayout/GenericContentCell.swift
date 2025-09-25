//
//  GenericContentCell.swift
//  SpeakLife
//
//  Created by Claude on 12/26/24.
//

import SwiftUI

// MARK: - Generic Content Cell

struct GenericContentCell<ContentType: SectionableContent>: View {
    let item: ContentType
    let configuration: GenericSectionConfiguration
    let isFavorite: Bool
    let onTap: () -> Void
    let onFavoriteTap: () -> Void
    
    @State private var isPressed = false
    @State private var showFavoriteAnimation = false
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    
    var body: some View {
        Group {
            switch configuration.cellStyle {
            case .standard:
                standardCell
            case .compact:
                compactCell
            case .featured:
                featuredCell
            case .custom(let width, let height):
                customCell(width: width, height: height)
            }
        }
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
    
    // MARK: - Cell Variations
    
    private var standardCell: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Image with overlay (fixed height)
            cellImageView(
                width: configuration.itemWidth,
                height: configuration.itemHeight * 0.65
            )
            
            // Content area with fixed height
            VStack(alignment: .leading, spacing: 4) {
                // Title with fixed height container
                Text(item.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(height: 34, alignment: .top) // Fixed height for 2 lines
                
                // Duration/controls
                HStack(spacing: 4) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                    
                    if let duration = item.duration {
                        Text(duration)
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                    }
                }
                .frame(height: 16) // Fixed height for controls
                
                Spacer(minLength: 0) // Fill remaining space
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 8)
            .frame(height: configuration.itemHeight * 0.35) // Fixed height for text area
        }
        .frame(width: configuration.itemWidth, height: configuration.itemHeight, alignment: .top) // Fixed total size with top alignment
    }
    
    private var compactCell: some View {
        HStack(spacing: 12) {
            // Thumbnail (fixed size)
            cellImageView(width: 60, height: 60)
                .cornerRadius(8)
            
            // Content with fixed height
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(height: 40, alignment: .top) // Fixed height for title, align to top
                
                HStack(spacing: 6) {
                    if let duration = item.duration {
                        Text(duration)
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                    }
                    
                    if item.isPremium && !subscriptionStore.isPremium {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.gray)
                    }
                }
                .frame(height: 16) // Fixed height for metadata
                
                Spacer(minLength: 0) // Fill remaining space
            }
            .frame(height: 60) // Fixed content area height
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Favorite button (fixed width)
            favoriteButton
                .frame(width: 44, height: 44)
        }
        .frame(height: 76, alignment: .top) // Fixed total height with top alignment
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
        )
    }
    
    private var featuredCell: some View {
        ZStack(alignment: .bottomLeading) {
            // Background image
            cellImageView(
                width: configuration.itemWidth,
                height: configuration.itemHeight
            )
            .overlay(
                LinearGradient(
                    colors: [.clear, .clear, .black.opacity(0.7)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            
            // Content overlay with fixed positioning
            VStack(alignment: .leading, spacing: 6) {
                Spacer()
                
                if item.isPremium && !subscriptionStore.isPremium {
                    premiumBadge
                }
                
                Text(item.title)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(height: 44, alignment: .top) // Fixed height for title
                
                Text(item.subtitle)
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.9))
                    .lineLimit(1)
                    .frame(height: 18, alignment: .top) // Fixed height for subtitle
                
                HStack {
                    if let duration = item.duration {
                        HStack(spacing: 4) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 10))
                            Text(duration)
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundColor(.white.opacity(0.9))
                    }
                    
                    Spacer()
                    
                    favoriteButton
                }
                .frame(height: 32) // Fixed height for controls
            }
            .frame(height: configuration.itemHeight * 0.4) // Fixed content area height
            .padding(16)
        }
        .frame(width: configuration.itemWidth, height: configuration.itemHeight)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
    }
    
    private func customCell(width: CGFloat, height: CGFloat) -> some View {
        // Custom implementation - can be extended for specific needs
        standardCell
            .frame(width: width, height: height, alignment: .top)
    }
    
    // MARK: - Helper Views
    
    private func cellImageView(width: CGFloat, height: CGFloat) -> some View {
        ZStack(alignment: .topTrailing) {
            Image(item.imageUrl)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: width, height: height)
                .clipped()
                .contentShape(Rectangle()) // Ensure consistent hit testing
                .overlay(
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.3)],
                        startPoint: .center,
                        endPoint: .bottom
                    )
                )
            
            // Favorite button for standard cell
            if configuration.cellStyle == GenericSectionConfiguration.SectionCellStyle.standard {
                favoriteButton
                    .padding(8)
            }
            
            // Premium lock indicator
            if item.isPremium && !subscriptionStore.isPremium &&
               configuration.cellStyle == .standard {
                premiumLockIndicator
            }
        }
        .frame(width: width, height: height) // Strict frame constraint
        .cornerRadius(12)
    }
    
    private var favoriteButton: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                showFavoriteAnimation = true
            }
            onFavoriteTap()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                showFavoriteAnimation = false
            }
        }) {
            Image(systemName: isFavorite ? "heart.fill" : "heart")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(isFavorite ? .pink : .white)
                .padding(8)
                .background(
                    Circle()
                        .fill(.ultraThinMaterial)
                )
                .scaleEffect(showFavoriteAnimation ? 1.3 : 1.0)
        }
    }
    
    private var premiumBadge: some View {
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
    
    private var premiumLockIndicator: some View {
        VStack {
            Spacer()
            HStack {
                Image(systemName: "lock.fill")
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding(6)
                    .background(
                        Circle()
                            .fill(Color.black.opacity(0.6))
                    )
                Spacer()
            }
            .padding(8)
        }
    }
}