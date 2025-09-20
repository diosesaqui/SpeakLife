//
//  AudioDeclarationView.swift
//  SpeakLife
//
//  Created by Riccardo Washington on 11/14/24.
//

import SwiftUI
import FirebaseAnalytics
import SwiftUI
import UIKit

struct UpNextCell: View {
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    @ObservedObject var viewModel: AudioDeclarationViewModel
    @ObservedObject var audioViewModel: AudioPlayerViewModel
    @StateObject private var metricsService = ListenerMetricsService.shared

    let item: AudioDeclaration

    @State private var showToast = false
    @State private var isTapped = false
    @State private var animateGlow = false
    @State private var showFavoriteAnimation = false
    @State private var listenerCount: String? = nil

    var body: some View {
        ZStack {
                HStack(spacing: 16) {
                    Image(item.imageUrl)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 80, height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .shadow(color: .black.opacity(0.2), radius: 6, x: 0, y: 4)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text(item.title)
                            .font(.system(size: 17, weight: .semibold))
                            .minimumScaleFactor(0.8)
                            .lineLimit(2)
                        
                        Text(item.subtitle)
                            .font(.system(size: 13))
                            .foregroundColor(.gray)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                        
                        HStack(spacing: 4) {
                            Image(systemName: "play.fill")
                                .font(.caption)
                            Text(item.duration)
                                .font(.system(size: 13))
                                .foregroundColor(.gray)
                            
//                            if let listenerCount = listenerCount {
//                                Text("•")
//                                    .font(.caption)
//                                    .foregroundColor(.gray)
//                                Image(systemName: "headphones")
//                                    .font(.caption)
//                                    .foregroundColor(.gray)
//                                Text(listenerCount)
//                                    .font(.system(size: 13))
//                                    .foregroundColor(.gray)
//                            }
                            
                            if item.isPremium, !subscriptionStore.isPremium {
                                Image(systemName: "lock")
                                    .font(.caption)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    // Favorite Button
                    Button(action: {
                        toggleFavorite()
                    }) {
                        Image(systemName: viewModel.favoritesManager.isFavorite(item) ? "heart.fill" : "heart")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(viewModel.favoritesManager.isFavorite(item) ? .pink : .white.opacity(0.7))
                            .scaleEffect(showFavoriteAnimation ? 1.3 : 1.0)
                            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: showFavoriteAnimation)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .contentShape(Circle())
                    .frame(width: 44, height: 44)
                }
                .contentShape(Rectangle())
                .padding(.vertical, 16)
                .padding(.horizontal, 20)
                .foregroundColor(.white)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.white.opacity(animateGlow ? 0.15 : 0.05), lineWidth: animateGlow ? 1.5 : 0.5)
                                .shadow(color: Color.blue.opacity(animateGlow ? 0.3 : 0), radius: animateGlow ? 10 : 0)
                        )
                        .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
                )
                .scaleEffect(isTapped ? 0.97 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isTapped)
                .onAppear {
                    // Fetch listener count for this audio
                    print("🎵 UpNextCell appearing for: \(item.id)")
//                    Task {
//                        let metrics = await metricsService.fetchMetrics(for: [item.id], contentType: .audio)
//                        print("📊 Metrics received for \(item.id): \(metrics)")
//                        if let count = metrics[item.id] {
//                            let formatted = ListenerMetricsService.formatListenerCount(count)
//                            print("📝 Setting listenerCount to: \(formatted ?? "nil")")
//                            await MainActor.run {
//                                listenerCount = formatted
//                            }
//                        } else {
//                            print("❌ No count found for \(item.id)")
//                        }
//                    }
                }


            if showToast {
                VStack {
                    Text(viewModel.favoritesManager.isFavorite(item) ? "Added to Favorites" : "Removed from Favorites")
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.8))
                        .cornerRadius(8)
                        .scaleEffect(showToast ? 1.05 : 0.8)
                        .animation(.spring(response: 0.35, dampingFraction: 0.5), value: showToast)
                }
                .transition(.opacity)
                .zIndex(1)
            }
        }
    }
    
    // MARK: - Favorite Actions
    private func toggleFavorite() {
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        // Animate favorite button
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            showFavoriteAnimation = true
        }
        
        // Delay the actual toggle to allow animation to complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            // Reset animation
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                showFavoriteAnimation = false
            }
            
            // Toggle favorite status after animation
            viewModel.favoritesManager.toggleFavorite(item)
            
            // Show toast for feedback after toggle
            showToast = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation {
                    showToast = false
                }
            }
        }
    }

//    func addToQueue(_ url: URL?) {
//        audioViewModel.addToQueue(url)
//        showToast = true
//        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
//            withAnimation {
//                showToast = false
//            }
//        }
//    }
}


struct ErrorWrapper: Identifiable {
    let id = UUID() // Unique identifier
    let message: String
}

enum Filter: String, CaseIterable {
    case favorites
    case declarations
    case bedtimeStories
    case gospel  
    case meditation
    case devotional
    case speaklife
    case godsHeart
    case growWithJesus
    case divineHealth
    case imagination
    case psalm91
    case magnify
    case praise
    
    // Display name for UI
    var displayName: String {
        switch self {
        case .favorites: return "Favorites"
        case .declarations: return "Mountain-Moving Prayers"
        case .bedtimeStories: return "Bedtime Stories"
        case .gospel: return "Gospel"
        case .meditation: return "Scripture Meditation's"
        case .devotional: return "Devotional"
        case .speaklife: return "SpeakLife"
        case .godsHeart: return "God's Heart"
        case .growWithJesus: return "Grow With Jesus"
        case .divineHealth: return "Divine Health"
        case .imagination: return "Imagination"
        case .psalm91: return "Psalm 91"
        case .magnify: return "Behold & Become"
        case .praise: return "Praise Wins Wars"
        }
    }
}

struct FetchedFilter: Identifiable, Hashable {
    var id: String  // unique ID for the filter
    var displayName: String
    var tag: String // used to filter audio files
}

struct AudioDeclarationView: View {
    @EnvironmentObject private var viewModel: AudioDeclarationViewModel
    @StateObject private var audioViewModel = AudioPlayerViewModel()
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    @EnvironmentObject var declarationStore: DeclarationViewModel
   
    @State private var audioURL: URL? = nil
    @State private var errorMessage: ErrorWrapper? = nil
    @State private var isPresentingPremiumView = false
    @State var presentDevotionalSubscriptionView = false
   
    
    
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Gradients().speakLifeCYOCell
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Meditation")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal)
                            .padding(.top, 8)
                    }
                    .padding(.top, 44)

                    // Horizontal Scrollable Header
                    ScrollView(.horizontal, showsIndicators: false) {
                        // Use dynamic header if filter configs are available, otherwise fall back to legacy
                        if !viewModel.dynamicFilters.isEmpty {
                            dynamicHeader
                        } else {
                            header
                        }
                    }
                    .padding(.vertical)

                    // Episode List with swipe support
                    episodeRow(proxy)
                        .listStyle(.plain)

                    Spacer().frame(height: proxy.size.height * 0.09)
                }

                // Audio bar at bottom
                VStack {
                    Spacer()
                    audioBar
                    Spacer().frame(height: proxy.size.height * 0.09)
                }
            }
            // Premium Sheet
            .sheet(isPresented: $isPresentingPremiumView) {
                isPresentingPremiumView = false
            } content: {
                OptimizedSubscriptionView() { //size: UIScreen.main.bounds.size) {
                        isPresentingPremiumView = false
                    }
                    .frame(height: UIScreen.main.bounds.height * 0.96)
                    .onDisappear {
                        if !subscriptionStore.isPremium,
                           !subscriptionStore.isInDevotionalPremium,
                           subscriptionStore.showDevotionalSubscription {
                            presentDevotionalSubscriptionView = true
                        }
                    }
            }

            // Error Alert
            .alert(item: $errorMessage) { error in
                Alert(
                    title: Text("Error"),
                    message: Text(error.message),
                    dismissButton: .default(Text("OK"))
                )
            }

            // Audio Player Sheet
            .sheet(item: $audioViewModel.selectedItem, onDismiss: {
                withAnimation {
                    audioViewModel.isBarVisible = true
                }
            }) { item in
                if let _ = audioURL {
                    AudioPlayerView(viewModel: audioViewModel)
                        .presentationDetents([.large])
                        .onAppear {
                            audioViewModel.lastSelectedItem = item
                            Analytics.logEvent(item.id, parameters: nil)
                        }
                }
            }

            // Devotional Subscription Sheet
            .sheet(isPresented: $presentDevotionalSubscriptionView) {
                DevotionalSubscriptionView {
                    presentDevotionalSubscriptionView = false
                }
            }
            .task {
                // Only fetch once when view first loads
                viewModel.fetchAudio(version: subscriptionStore.audioRemoteVersion)
            }
        }
    }
    
    // Dynamic header using new filter system
    var dynamicHeader: some View {
        HStack(spacing: 15) {
            ForEach(viewModel.dynamicFilters, id: \.id) { filterConfig in
                Button(action: {
                    viewModel.selectedFilterId = filterConfig.id
                    // Update legacy system for compatibility
                    if let legacyFilter = Filter(rawValue: filterConfig.id) {
                        viewModel.selectedFilter = legacyFilter
                    }
                    if filterConfig.id == "favorites" {
                        AudioAnalytics.shared.trackFavoritesCategoryViewed(
                            favoritesCount: viewModel.favoritesManager.favoritesCount
                        )
                    }
                }) {
                    HStack(spacing: 6) {
                        if filterConfig.id == "favorites" {
                            Image(systemName: "heart.fill")
                                .font(.caption2)
                                .foregroundColor(viewModel.selectedFilterId == filterConfig.id ? .white : .pink)
                        }
                        
                        Text(filterConfig.displayName)
                            .font(.caption)
                        
                        if filterConfig.id == "favorites" && viewModel.favoritesManager.favoritesCount > 0 {
                            Text("(\(viewModel.favoritesManager.favoritesCount))")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                    .padding(.horizontal, 15)
                    .padding(.vertical, 10)
                    .background(
                        viewModel.selectedFilterId == filterConfig.id ? 
                        (filterConfig.id == "favorites" ? Color.pink : Constants.DAMidBlue) :
                        Color.gray.opacity(0.2)
                    )
                    .foregroundColor(.white)
                    .cornerRadius(20)
                }
            }
        }
    }
    
    // Legacy header for backward compatibility
    var header: some View {
        HStack(spacing: 15) {
            ForEach(viewModel.filters, id: \.self) { filter in
                Button(action: {
                    viewModel.selectedFilter = filter
                    if filter == .favorites {
                        AudioAnalytics.shared.trackFavoritesCategoryViewed(
                            favoritesCount: viewModel.favoritesManager.favoritesCount
                        )
                    }
                }) {
                    HStack(spacing: 6) {
                        if filter == .favorites {
                            Image(systemName: "heart.fill")
                                .font(.caption2)
                                .foregroundColor(viewModel.selectedFilter == filter ? .white : .pink)
                        }
                        
                        Text(filter.displayName)
                            .font(.caption)
                        
                        if filter == .favorites && viewModel.favoritesManager.favoritesCount > 0 {
                            Text("(\(viewModel.favoritesManager.favoritesCount))")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                    .padding(.horizontal, 15)
                    .padding(.vertical, 10)
                    .background(
                        viewModel.selectedFilter == filter ? 
                        (filter == .favorites ? Color.pink : Constants.DAMidBlue) :
                        Color.gray.opacity(0.2)
                    )
                    .foregroundColor(.white)
                    .cornerRadius(20)
                }
            }
        }
        .padding(.horizontal)
    }
    
    func episodeRow(_ proxy: GeometryProxy) -> some View {
        Group {
            // Use dynamic filtered content if available, otherwise fall back to legacy
            let currentContent = !viewModel.dynamicFilters.isEmpty ? viewModel.dynamicFilteredContent : viewModel.filteredContent
            
            if viewModel.selectedFilterId == "favorites" && currentContent.isEmpty {
                // Empty favorites state
                VStack(spacing: 20) {
                    Image(systemName: "heart.text.square")
                        .resizable()
                        .frame(width: 80, height: 80)
                        .foregroundColor(.white.opacity(0.6))
                    
                    Text("No Audio Favorites Yet")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    Text("Tap the heart icon on any audio to add it to your favorites.")
                        .font(.body)
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                    
                    Button("Browse Audio") {
                        viewModel.selectedFilter = .speaklife
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
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(40)
            } else {
                List {
                    // Use dynamic filtered content if available, otherwise fall back to legacy
                    ForEach(!viewModel.dynamicFilters.isEmpty ? viewModel.dynamicFilteredContent : viewModel.filteredContent) { item in
                Button(action: {
                        handleItemTap(item)
                }) {
                    VStack {
                        UpNextCell(viewModel: viewModel, audioViewModel: audioViewModel, item: item)
                            .frame(width: proxy.size.width * 0.9, height: proxy.size.height * 0.15)
                        
                        if let progress = viewModel.downloadProgress[item.id], progress > 0 {
                            ProgressView(value: progress)
                                .progressViewStyle(LinearProgressViewStyle())
                                .padding(.top, 8)
                        }
                    }
                    .listRowInsets(EdgeInsets()) // remove default padding
                    .background(Color.clear)
                    .swipeActions(edge: .leading) {
                        Button {
                            handleFavoriteSwipeAction(for: item)
                        } label: {
                            Label(
                                viewModel.favoritesManager.isFavorite(item) ? "Unfavorite" : "Favorite",
                                systemImage: viewModel.favoritesManager.isFavorite(item) ? "heart.slash" : "heart.fill"
                            )
                        }
                        .tint(viewModel.favoritesManager.isFavorite(item) ? .gray : .pink)
                    }
                }
                .disabled(viewModel.fetchingAudioIDs.contains(item.id))
                .listRowBackground(Color.clear)
            }
                }
                .scrollContentBackground(.hidden)
                .background(.clear)
            }
        }
    }
    
    @ViewBuilder
    var audioBar: some View {
        if audioViewModel.isBarVisible {
            PersistentAudioBar(viewModel: audioViewModel)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.easeOut(duration: 0.4), value: audioViewModel.isBarVisible)
                .onDisappear {
                    if declarationStore.backgroundMusicEnabled, !audioViewModel.isPlaying {
                        AudioPlayerService.shared.playMusic()
                    }
                }
                .onTapGesture {
                    if let lastSelectedItem = audioViewModel.lastSelectedItem {
                        self.audioViewModel.selectedItem = lastSelectedItem
                    }
                }
        }
    }
    
    private func handleItemTap(_ item: AudioDeclaration) {
        if item.isPremium, !subscriptionStore.isPremium {
            isPresentingPremiumView = true
            return
        }

        // Check if tapping the same item that's already loaded
        if audioViewModel.selectedItem?.id == item.id {
            // Just open the modal for the same item without reloading
            // This prevents re-triggering loadAudio for the same item
            return
        }

        viewModel.downloadProgress[item.id] = nil
        viewModel.fetchingAudioIDs.insert(item.id)

        viewModel.fetchAudio(for: item) { result in
            DispatchQueue.main.async {
                viewModel.fetchingAudioIDs.remove(item.id)
                switch result {
                case .success(let url):
                    audioURL = url
                    let isSameItem = audioViewModel.selectedItem?.id == item.id
                    viewModel.downloadProgress[item.id] = 0.0
                    audioViewModel.currentTrack = item.title
                    audioViewModel.subtitle = item.subtitle
                    audioViewModel.imageUrl = item.imageUrl
                    // Load audio and set selectedItem together
                    audioViewModel.loadAudio(from: url, isSameItem: isSameItem)
                    audioViewModel.selectedItem = item
                    // Show the audio bar when playing
                    audioViewModel.isBarVisible = true
                case .failure(let error):
                    errorMessage = ErrorWrapper(message: "Failed to download audio: \(error.localizedDescription)")
                    audioViewModel.selectedItem = nil
                    viewModel.downloadProgress[item.id] = 0.0
                }
            }
        }
    }
    
    private func handleFavoriteSwipeAction(for item: AudioDeclaration) {
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        // Add a small delay to allow swipe animation to complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            // Toggle favorite status
            viewModel.favoritesManager.toggleFavorite(item)
        }
    }
}



extension View {
    func frostedCardStyle(cornerRadius: CGFloat = 20) -> some View {
        self
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
    }
}
