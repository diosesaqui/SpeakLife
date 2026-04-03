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
    let audioViewModel: AudioPlayerViewModel
    let onItemTap: (AudioDeclaration) -> Void
    let onFavoriteSwipe: (AudioDeclaration) -> Void
    
    var body: some View {
        Button(action: {
            onItemTap(item)
        }) {
            VStack {
                UpNextCell(
                    viewModel: viewModel, 
                    audioViewModel: audioViewModel, 
                    item: item
                )
                .frame(
                    width: proxy.size.width * 0.9, 
                    height: proxy.size.height * 0.15
                )
                
                if let progress = viewModel.downloadProgress[item.id], progress > 0 {
                    ProgressView(value: progress)
                        .progressViewStyle(LinearProgressViewStyle())
                        .padding(.top, 8)
                }
            }
            .listRowInsets(EdgeInsets())
            .background(Color.clear)
            .swipeActions(edge: .leading) {
                favoriteSwipeButton
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