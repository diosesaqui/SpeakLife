//
//  SectionedAudioView.swift
//  SpeakLife
//
//  Created by Claude on 12/26/24.
//

import SwiftUI

struct SectionedAudioView: View {
    @EnvironmentObject var viewModel: AudioDeclarationViewModel
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    
    let audioViewModel: AudioPlayerViewModel
    let onItemTap: (AudioDeclaration) -> Void
    let onFavoriteToggle: (AudioDeclaration) -> Void
    
    @State private var refreshing = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Main content
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 24) {
                        // Pull to refresh indicator
                        if refreshing {
                            HStack {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                                Text("Refreshing...")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.7))
                            }
                            .padding(.top, 8)
                            .transition(.move(edge: .top).combined(with: .opacity))
                        }
                        
                        // Sections
                        ForEach(viewModel.speakLifeSections) { section in
                            HorizontalAudioSection(
                                section: section,
                                onItemTap: { item in
                                    onItemTap(item)
                                },
                                onFavoriteTap: { item in
                                    onFavoriteToggle(item)
                                },
                                onSeeAllTap: {
                                    // No action - See All button is disabled
                                }
                            )
                            .id(section.id)
                            .transition(.asymmetric(
                                insertion: .move(edge: .bottom).combined(with: .opacity),
                                removal: .move(edge: .top).combined(with: .opacity)
                            ))
                        }
                        
                        // Bottom spacing for tab bar
                        Spacer()
                            .frame(height: geometry.size.height * 0.15)
                    }
                    .padding(.top, 8)
                }
                .refreshable {
                    await refreshContent()
                }
                
                // Empty state
                if viewModel.speakLifeSections.isEmpty {
                    emptyStateView
                }
                
                // Audio bar is handled by parent view
            }
            // All sheets and alerts are handled by parent AudioDeclarationView
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "waveform.circle")
                .resizable()
                .frame(width: 80, height: 80)
                .foregroundColor(.white.opacity(0.5))
            
            Text("No SpeakLife Content")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text("Check back later for new content")
                .font(.body)
                .foregroundColor(.white.opacity(0.7))
            
            Button(action: {
                Task {
                    await refreshContent()
                }
            }) {
                Label("Refresh", systemImage: "arrow.clockwise")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Constants.DAMidBlue)
                    )
            }
        }
        .padding(40)
    }
    
    // Removed getSectionTitle since See All is disabled
    
    private func refreshContent() async {
        withAnimation {
            refreshing = true
        }
        
        // Simulate network refresh
        viewModel.fetchAudio(version: subscriptionStore.audioRemoteVersion)
        
        try? await Task.sleep(nanoseconds: 1_500_000_000)
        
        withAnimation {
            refreshing = false
        }
    }
    
    // handleItemTap and handleFavoriteToggle are now passed as parameters
}