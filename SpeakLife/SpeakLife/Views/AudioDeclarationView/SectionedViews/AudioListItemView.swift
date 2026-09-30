//
//  AudioListItemView.swift
//  SpeakLife
//
//  Created by Claude on 12/26/24.
//

import SwiftUI

struct AudioListItemView: View {
    let item: AudioDeclaration
    let proxy: GeometryProxy
    let viewModel: AudioDeclarationViewModel
    var isQueued: Bool = false
    let onItemTap: (AudioDeclaration) -> Void
    let onFavoriteSwipe: (AudioDeclaration) -> Void
    var onPlayNext: ((AudioDeclaration) -> Void)? = nil
    var onAddToQueue: ((AudioDeclaration) -> Void)? = nil
    var onRemoveFromQueue: ((AudioDeclaration) -> Void)? = nil
    
    var body: some View {
        Button(action: {
            onItemTap(item)
        }) {
            VStack {
                UpNextCell(
                    favoritesManager: viewModel.favoritesManager,
                    item: item,
                    isQueued: isQueued,
                    onPlayNext: onPlayNext,
                    onAddToQueue: onAddToQueue,
                    onRemoveFromQueue: onRemoveFromQueue
                )
                .frame(
                    width: proxy.size.width * 0.9, 
                    height: proxy.size.height * 0.15
                )
                
                if let progress = viewModel.downloadProgress[item.id], progress > 0 {
                    ProgressView(value: progress)
                        .progressViewStyle(LinearProgressViewStyle())
                        .padding(.top, DS.Spacing.xs)
                }
            }
            .listRowInsets(EdgeInsets())
            .background(Color.clear)
            .swipeActions(edge: .leading) {
                favoriteSwipeButton
            }
            .swipeActions(edge: .trailing) {
                if let onPlayNext = onPlayNext {
                    Button {
                        onPlayNext(item)
                    } label: {
                        Label("Play Next", systemImage: "text.line.first.and.arrowtriangle.forward")
                    }
                    .tint(.indigo)
                }
            }
        }
        .disabled(viewModel.fetchingAudioIDs.contains(item.id))
        .listRowBackground(Color.clear)
    }
    
    private var favoriteSwipeButton: some View {
        Button {
            onFavoriteSwipe(item)
        } label: {
            Label(
                favoriteButtonTitle,
                systemImage: favoriteButtonIcon
            )
        }
        .tint(favoriteButtonTint)
    }
    
    private var favoriteButtonTitle: String {
        viewModel.favoritesManager.isFavorite(item) ? "Unfavorite" : "Favorite"
    }
    
    private var favoriteButtonIcon: String {
        viewModel.favoritesManager.isFavorite(item) ? "heart.slash" : "heart.fill"
    }
    
    private var favoriteButtonTint: Color {
        viewModel.favoritesManager.isFavorite(item) ? .gray : .pink
    }
}