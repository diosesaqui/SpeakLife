//
//  OptimizedAudioCell.swift
//  SpeakLife
//
//  Created by Claude on 12/26/24.
//

import SwiftUI

struct OptimizedAudioCell: View {
    let item: AudioDeclaration
    let configuration: SectionConfiguration
    let isFavorite: Bool
    let onTap: () -> Void
    let onFavoriteTap: () -> Void
    
    @State private var isPressed = false
    @State private var showFavoriteAnimation = false
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    @ObservedObject private var progressStore = AudioProgressStore.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Image with overlay
            ZStack(alignment: .topTrailing) {
                Image(item.imageUrl)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: configuration.itemWidth, height: configuration.itemHeight * 0.65)
                    .clipped()
                    .overlay(
                        LinearGradient(
                            colors: [.clear, .black.opacity(0.3)],
                            startPoint: .center,
                            endPoint: .bottom
                        )
                    )
                    .overlay(alignment: .bottomTrailing) {
                        if progressStore.isPlayed(item.id) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 18, weight: .bold))
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(Color.white, Color(red: 0.18, green: 0.78, blue: 0.45))
                                .background(
                                    Circle()
                                        .fill(Color.black.opacity(0.3))
                                        .padding(2)
                                )
                                .offset(x: -6, y: -6)
                        }
                    }
                
                // Favorite button
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
                        .padding(DS.Spacing.xs)
                        .background(
                            Circle()
                                .fill(.ultraThinMaterial)
                        )
                        .scaleEffect(showFavoriteAnimation ? 1.3 : 1.0)
                }
                .padding(DS.Spacing.xs)
                
                // Premium lock indicator
                if item.isPremium && !subscriptionStore.isPremium {
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
                        .padding(DS.Spacing.xs)
                    }
                }
            }
            .cornerRadius(12)
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                Spacer(minLength: 0)
                
                HStack(spacing: 4) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                    
                    Text(item.duration)
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 8)
            .frame(height: 60, alignment: .top)
        }
        .frame(width: configuration.itemWidth)
        .contentShape(Rectangle())
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(DS.Motion.quick, value: isPressed)
        .onTapGesture {
            isPressed = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isPressed = false
            }
            onTap()
        }
    }
}

// Compact cell variant for smaller displays
struct CompactAudioCell: View {
    let item: AudioDeclaration
    let isFavorite: Bool
    let onTap: () -> Void
    let onFavoriteTap: () -> Void
    
    @State private var isPressed = false
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    
    var body: some View {
        HStack(spacing: DS.Spacing.sm) {
            // Thumbnail
            Image(item.imageUrl)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 60, height: 60)
                .cornerRadius(8)
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(2)
                
                HStack(spacing: 6) {
                    Text(item.duration)
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                    
                    if item.isPremium && !subscriptionStore.isPremium {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.gray)
                    }
                }
            }
            
            Spacer()
            
            // Favorite button
            Button(action: onFavoriteTap) {
                Image(systemName: isFavorite ? "heart.fill" : "heart")
                    .font(.system(size: 18))
                    .foregroundColor(isFavorite ? .pink : .white.opacity(0.6))
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
        )
        .scaleEffect(isPressed ? 0.97 : 1.0)
        .animation(DS.Motion.quick, value: isPressed)
        .onTapGesture {
            isPressed = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isPressed = false
            }
            onTap()
        }
    }
}