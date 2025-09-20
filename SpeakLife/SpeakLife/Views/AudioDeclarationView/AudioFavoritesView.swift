//
//  AudioFavoritesView.swift
//  SpeakLife
//
//  Audio favorites view displaying user's favorited audio content
//

import SwiftUI
import FirebaseAnalytics

// MARK: - Audio Content Row
struct AudioContentRow: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    @StateObject private var favoritesManager = AudioFavoritesManager()
    
    @State private var showShareSheet = false
    @State private var isPressed = false
    @State private var shouldGlow = false
    @State private var showRemoveAnimation = false
    
    let audio: AudioDeclaration
    var onPlay: (() -> Void)?
    var onRemove: (() -> Void)?
    
    init(_ audio: AudioDeclaration, onPlay: (() -> Void)? = nil, onRemove: (() -> Void)? = nil) {
        self.audio = audio
        self.onPlay = onPlay
        self.onRemove = onRemove
    }
    
    var body: some View {
        Button(action: {
            handlePlay()
        }) {
            HStack(spacing: 16) {
                // Audio artwork
                Image(audio.imageUrl)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(audio.title)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    Text(audio.subtitle)
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(1)
                    
                    HStack(spacing: 8) {
                        HStack(spacing: 4) {
                            Image(systemName: "play.fill")
                                .font(.caption2)
                            Text(audio.duration)
                                .font(.caption2)
                        }
                        .foregroundColor(.white.opacity(0.6))
                        
                        if audio.isPremium && !subscriptionStore.isPremium {
                            HStack(spacing: 2) {
                                Image(systemName: "lock.fill")
                                    .font(.caption2)
                                Text("Premium")
                                    .font(.caption2)
                            }
                            .foregroundColor(.yellow.opacity(0.8))
                        }
                        
                        if let tag = audio.tag {
                            Text(tag.capitalized)
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.5))
                        }
                    }
                }
                
                Spacer()
                
                // Action menu
                Image(systemName: "ellipsis.circle.fill")
                    .font(.title3)
                    .foregroundColor(.white.opacity(0.8))
                    .padding(8)
                    .background(Color.white.opacity(0.05))
                    .clipShape(Circle())
                    .contextMenu {
                        Button(action: shareAudio) {
                            Label("Share", systemImage: "square.and.arrow.up.fill")
                        }
                        
                        Button(action: handleRemove) {
                            Label("Remove from Favorites", systemImage: "heart.slash.fill")
                        }
                        .foregroundColor(.red)
                    }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
                    )
                    .shadow(
                        color: shouldGlow ? Color.pink.opacity(0.4) : .black.opacity(0.15),
                        radius: shouldGlow ? 10 : 6,
                        x: 0,
                        y: shouldGlow ? 4 : 2
                    )
            )
            .scaleEffect(showRemoveAnimation ? 0.95 : 1.0)
            .opacity(showRemoveAnimation ? 0.7 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: showRemoveAnimation)
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: shouldGlow)
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(activityItems: [
                "🎵 \(audio.title) - \(audio.subtitle)",
                "Listen on SpeakLife App",
                "https://apps.apple.com/app/speaklife/id1234567890"
            ])
        }
    }
    
    // MARK: - Actions
    
    private func handlePlay() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        
        withAnimation(.easeInOut(duration: 0.4)) {
            shouldGlow = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation { shouldGlow = false }
        }
        
        AudioAnalytics.shared.trackFavoriteAudioPlayed(audio: audio, playSource: .favoritesList)
        onPlay?()
    }
    
    private func handleRemove() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            showRemoveAnimation = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            favoritesManager.removeFavorite(withId: audio.id)
            onRemove?()
        }
    }
    
    private func shareAudio() {
        AudioAnalytics.shared.trackFavoriteAudioShared(audio: audio, shareMethod: .social)
        showShareSheet = true
    }
}

// MARK: - Audio Favorites View
struct AudioFavoritesView: View {
    @StateObject private var favoritesManager = AudioFavoritesManager()
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.presentationMode) var presentationMode
    
    // Audio player integration
    @StateObject private var audioPlayerViewModel = AudioPlayerViewModel()
    @State private var audioURL: URL?
    @State private var errorMessage: ErrorWrapper?
    
    // UI State
    @State private var sortOrder: SortOrder = .dateAdded
    @State private var searchText = ""
    @State private var showSortOptions = false
    @State private var showClearAllAlert = false
    
    enum SortOrder: String, CaseIterable {
        case dateAdded = "Date Added"
        case alphabetical = "A-Z"
        case duration = "Duration"
        case category = "Category"
        
        var icon: String {
            switch self {
            case .dateAdded: return "clock.fill"
            case .alphabetical: return "textformat.abc"
            case .duration: return "timer"
            case .category: return "folder.fill"
            }
        }
    }
    
    var sortedAndFilteredFavorites: [AudioDeclaration] {
        var favorites = favoritesManager.favorites
        
        // Apply search filter
        if !searchText.isEmpty {
            favorites = favorites.filter { audio in
                audio.title.localizedCaseInsensitiveContains(searchText) ||
                audio.subtitle.localizedCaseInsensitiveContains(searchText) ||
                (audio.tag?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
            
            // Track search
            AudioAnalytics.shared.trackFavoritesSearched(
                searchTerm: searchText,
                resultsCount: favorites.count
            )
        }
        
        // Apply sorting
        switch sortOrder {
        case .dateAdded:
            return favorites.sorted { 
                ($0.dateFavorited ?? Date.distantPast) > ($1.dateFavorited ?? Date.distantPast)
            }
        case .alphabetical:
            return favorites.sorted { $0.title < $1.title }
        case .duration:
            return favorites.sorted { $0.duration < $1.duration }
        case .category:
            return favorites.sorted { ($0.tag ?? "") < ($1.tag ?? "") }
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Gradients().speakLifeCYOCell
                    .ignoresSafeArea()
                
                configureView()
            }
            .navigationTitle("Audio Favorites")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        ForEach(SortOrder.allCases, id: \.self) { order in
                            Button(action: {
                                sortOrder = order
                                AudioAnalytics.shared.trackFavoritesSorted(
                                    sortOrder: AudioAnalytics.FavoritesSortOrder(rawValue: order.rawValue.lowercased().replacingOccurrences(of: " ", with: "_")) ?? .dateAdded,
                                    favoritesCount: favoritesManager.favorites.count
                                )
                            }) {
                                Label(order.rawValue, systemImage: order.icon)
                                if sortOrder == order {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                        
                        Divider()
                        
                        Button(action: {
                            showClearAllAlert = true
                        }) {
                            Label("Clear All Favorites", systemImage: "trash")
                        }
                        .foregroundColor(.red)
                        
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(.white)
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search favorites...")
            .alert("Clear All Favorites", isPresented: $showClearAllAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Clear All", role: .destructive) {
                    favoritesManager.clearAllFavorites()
                }
            } message: {
                Text("This will remove all audio from your favorites. This action cannot be undone.")
            }
            .sheet(item: $audioPlayerViewModel.selectedItem) { item in
                if audioURL != nil {
                    AudioPlayerView(viewModel: audioPlayerViewModel)
                        .presentationDetents([.large])
                }
            }
            .onAppear {
                AudioAnalytics.shared.trackFavoritesCategoryViewed(
                    favoritesCount: favoritesManager.favorites.count,
                    sortOrder: AudioAnalytics.FavoritesSortOrder(rawValue: sortOrder.rawValue.lowercased().replacingOccurrences(of: " ", with: "_")) ?? .dateAdded
                )
            }
        }
    }
    
    @ViewBuilder
    private func configureView() -> some View {
        if favoritesManager.isLoading {
            VStack {
                ProgressView()
                    .scaleEffect(1.2)
                    .tint(.white)
                Text("Loading favorites...")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.top, 8)
            }
        } else if sortedAndFilteredFavorites.isEmpty {
            emptyStateView
        } else {
            favoritesListView
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: searchText.isEmpty ? "heart.text.square" : "magnifyingglass")
                .resizable()
                .frame(width: 80, height: 80)
                .foregroundColor(.white.opacity(0.6))
            
            Text(searchText.isEmpty ? "No Audio Favorites Yet" : "No Results Found")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.white)
            
            Text(searchText.isEmpty ? 
                 "Tap the heart icon on any audio to add it to your favorites." :
                 "Try adjusting your search terms.")
                .font(.body)
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            if searchText.isEmpty {
                Button("Browse Audio") {
                    presentationMode.wrappedValue.dismiss()
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.pink.opacity(0.8))
                )
                .padding(.top, 10)
            }
        }
        .padding(40)
    }
    
    private var favoritesListView: some View {
        List {
            ForEach(sortedAndFilteredFavorites, id: \.id) { audio in
                AudioContentRow(audio) {
                    handleAudioPlay(audio)
                } onRemove: {
                    // Refresh handled automatically by @StateObject
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
            }
            .onDelete(perform: removeFavorites)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.clear)
    }
    
    // MARK: - Actions
    
    private func handleAudioPlay(_ audio: AudioDeclaration) {
        // Check premium status
        if audio.isPremium && !subscriptionStore.isPremium {
            // Could present premium view here
            return
        }
        
        // Load and play audio (simplified - would need integration with existing audio loading system)
        audioPlayerViewModel.selectedItem = audio
        audioPlayerViewModel.currentTrack = audio.title
        audioPlayerViewModel.subtitle = audio.subtitle
        audioPlayerViewModel.imageUrl = audio.imageUrl
        
        // This would need to be integrated with the existing audio loading system
        // from AudioDeclarationViewModel.fetchAudio(for:completion:)
    }
    
    private func removeFavorites(at offsets: IndexSet) {
        for index in offsets {
            let audio = sortedAndFilteredFavorites[index]
            favoritesManager.removeFavorite(withId: audio.id)
        }
    }
}

// MARK: - ShareSheet
//struct ShareSheet: UIViewControllerRepresentable {
//    let activityItems: [Any]
//    
//    func makeUIViewController(context: Context) -> UIActivityViewController {
//        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
//        return controller
//    }
//    
//    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
//}

// MARK: - Preview
#if DEBUG
struct AudioFavoritesView_Previews: PreviewProvider {
    static var previews: some View {
        AudioFavoritesView()
            .environmentObject(SubscriptionStore())
    }
}
#endif
