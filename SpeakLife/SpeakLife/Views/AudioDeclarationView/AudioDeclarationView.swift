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
    // Row observes only what it renders: heart state and played state.
    // Observing the whole list view model here made every row re-render on
    // any view-model publish (download ticks, filter changes, ...).
    @ObservedObject var favoritesManager: AudioFavoritesManager
    @ObservedObject private var progressStore = AudioProgressStore.shared

    let item: AudioDeclaration

    @State private var showToast = false
    @State private var toastMessage = ""
    @State private var isTapped = false
    @State private var showFavoriteAnimation = false

    var body: some View {
        ZStack {
                HStack(spacing: DS.Spacing.md) {
                    ArtworkThumbnail(name: item.imageUrl, size: CGSize(width: 80, height: 80))
                        .frame(width: 80, height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .shadow(color: .black.opacity(0.2), radius: 6, x: 0, y: 4)
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
                                    .offset(x: 5, y: 5)
                            }
                        }
                    
                    VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                        Text(item.title)
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                            .minimumScaleFactor(0.8)
                            .lineLimit(2)

                        Text(item.subtitle)
                            .font(.system(size: 13))
                            .foregroundColor(.gray)
                            .lineLimit(1)
                            .multilineTextAlignment(.leading)

                        HStack(spacing: 4) {
                            Image(systemName: "play.fill")
                                .font(.caption)
                            Text(item.duration)
                                .font(.system(size: 13))
                                .foregroundColor(.gray)

                            if item.isPremium, !subscriptionStore.isPremium {
                                Image(systemName: "lock")
                                    .font(.caption)
                            }
                        }
                    }
                    // Let the title/subtitle column claim all the leftover
                    // horizontal space and win it over the trailing controls.
                    // Without this the Spacer ate the slack and the name column
                    // collapsed on narrow devices (titles truncated to a few
                    // characters; "SpeakLife" even broke mid-word).
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .layoutPriority(1)

                    // Trailing controls, kept tight together at the edge so the
                    // title gets the space instead of a wide gap between them.
                    HStack(spacing: 0) {
                        // Played toggle
                        Button(action: {
                            Juice.play(.tapSolid)
                            progressStore.togglePlayed(item.id)
                        }) {
                            Image(systemName: progressStore.isPlayed(item.id) ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(progressStore.isPlayed(item.id) ? Color(red: 0.18, green: 0.78, blue: 0.45) : .white.opacity(0.7))
                        }
                        .buttonStyle(PlainButtonStyle())
                        .contentShape(Circle())
                        .frame(width: 38, height: 44)
                        .accessibilityLabel(progressStore.isPlayed(item.id) ? "Mark as unplayed" : "Mark as played")

                        // Favorite Button
                        Button(action: {
                            toggleFavorite()
                        }) {
                            Image(systemName: favoritesManager.isFavorite(item) ? "heart.fill" : "heart")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(favoritesManager.isFavorite(item) ? .pink : .white.opacity(0.7))
                                .scaleEffect(showFavoriteAnimation ? 1.3 : 1.0)
                                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: showFavoriteAnimation)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .contentShape(Circle())
                        .frame(width: 38, height: 44)
                    }
                }
                .contentShape(Rectangle())
                .padding(.vertical, DS.Spacing.md)
                .padding(.horizontal, DS.Spacing.lg)
                .foregroundColor(.white)
                .background(
                    RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                                .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
                        )
                        .dsShadow(DS.Elevation.low)
                )
                .scaleEffect(isTapped ? 0.97 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isTapped)
                .contextMenu {
                    Button {
                        Juice.play(.tapSolid)
                        progressStore.togglePlayed(item.id)
                    } label: {
                        if progressStore.isPlayed(item.id) {
                            Label("Mark as Unplayed", systemImage: "circle")
                        } else {
                            Label("Mark as Played", systemImage: "checkmark.circle.fill")
                        }
                    }
                }

            if showToast {
                VStack {
                    Text(toastMessage)
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
        Juice.play(.tapSolid)
        
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
            
            // Capture intent before the async Core Data toggle: reading
            // isFavorite after kicking it off shows the inverted message
            // until the repository observer lands.
            let wasFavorite = favoritesManager.isFavorite(item)

            // Toggle favorite status after animation
            favoritesManager.toggleFavorite(item)

            // Show toast for feedback after toggle
            toastMessage = wasFavorite ? "Removed from Favorites" : "Added to Favorites"
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
    @ObservedObject private var progressStore = AudioProgressStore.shared

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
                    VStack(alignment: .leading, spacing: DS.Spacing.xs) {
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
                        }
                    }
                    .padding(.vertical)

                    // Played / Unplayed sub-filter
                    playedFilterRow
                        .padding(.bottom, 4)

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
                            AnalyticsService.shared.track("audio_played", parameters: ["id": item.id])
                        }
                }
            }
            .onAppear() {
                AnalyticsService.shared.track("AudioScreenLoaded")
                // Re-apply ordering now that Remote Config and favorites have
                // loaded — covers existing users who don't rebuild filters on update.
                viewModel.refreshPersonalization()
                // Covers arriving from the checklist when this tab is already
                // alive: contentByFilter won't re-emit, so onReceive alone
                // would miss the pending deep-link.
                attemptChecklistAutoPlay()
            }
            // Auto-play when arriving from daily checklist.
            // Uses onReceive on contentByFilter (a @Published dict) so it fires
            // both when content is already loaded AND when it finishes loading
            // for the first time — solving the empty-content timing issue.
            .onReceive(viewModel.$contentByFilter) { _ in
                attemptChecklistAutoPlay()
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
    
    // MARK: - Played / Unplayed sub-filter

    private var playedFilterRow: some View {
        HStack(spacing: 4) {
            ForEach(PlayedFilter.allCases) { option in
                Button(action: { viewModel.playedFilter = option }) {
                    Text(option.rawValue)
                        .font(.system(size: 13, weight: viewModel.playedFilter == option ? .semibold : .regular))
                        .foregroundColor(viewModel.playedFilter == option ? .white : .white.opacity(0.45))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(viewModel.playedFilter == option
                                      ? Color.white.opacity(0.18)
                                      : Color.clear)
                        )
                }
            }

            Spacer()
        }
        .padding(.horizontal)
    }

    // Dynamic header using new filter system
    var dynamicHeader: some View {
        HStack(spacing: 15) {
            ForEach(viewModel.dynamicFilters, id: \.id) { filterConfig in
                Button(action: {
                    viewModel.selectedFilterId = filterConfig.id
                    AnalyticsService.shared.track("audio_filter_tapped", parameters: [
                        "filter_id": filterConfig.id,
                        "position": viewModel.dynamicFilters.firstIndex(where: { $0.id == filterConfig.id }) ?? -1,
                        "personalized": viewModel.isPersonalizedOrderEnabled
                    ])
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
        .padding(.horizontal)
    }
    
    
    func episodeRow(_ proxy: GeometryProxy) -> some View {
        Group {
//            if isSpeakLifeFilterSelected {
//                speakLifeSectionedView
//            } else if shouldShowEmptyFavoritesState {
//                emptyFavoritesView
//            } else {
                audioListView(proxy)
          //  }
        }
    }
    
    // MARK: - Computed Properties for SOLID Compliance
    
    private var isSpeakLifeFilterSelected: Bool {
      //  if !viewModel.dynamicFilters.isEmpty {
            return viewModel.selectedFilterId.lowercased() == "speaklife"
     //   }
       // return false
//        } else {
//            return viewModel.selectedFilter == .speaklife
//        }
    }
    
    // MARK: - Generic Sectioned Layout Support
    
    private var currentTabConfig: SectionedTabConfig {
        return viewModel.currentTabConfig
    }
    
    private var shouldUseSectionedLayout: Bool {
        let sectionProvider = SectionedLayoutFactory.createSectionProvider(
            for: currentTabConfig,
            with: viewModel
        )
        return SectionedLayoutFactory.shouldUseSectionedLayout(
            for: currentTabConfig,
            with: sectionProvider
        )
    }
    
    private var shouldShowEmptyFavoritesState: Bool {
        let currentContent = viewModel.dynamicFilteredContent
        return viewModel.selectedFilterId == "favorites" && currentContent.isEmpty
    }
    
    private var speakLifeSectionedView: some View {
        SectionedAudioView(
            audioViewModel: audioViewModel,
            onItemTap: handleItemTap,
            onFavoriteToggle: handleFavoriteSwipeAction
        )
        .environmentObject(viewModel)
        .environmentObject(subscriptionStore)
    }
    
    private var emptyFavoritesView: some View {
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
                viewModel.selectedFilterId = "speaklife"
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
    }
    
    private func audioListView(_ proxy: GeometryProxy) -> some View {
        List {
            ForEach(currentFilteredContent) { item in
                AudioListItemView(
                    item: item,
                    proxy: proxy,
                    viewModel: viewModel,
                    onItemTap: handleItemTap,
                    onFavoriteSwipe: handleFavoriteSwipeAction
                )
                .onAppear {
                    viewModel.loadMoreIfNeeded(currentItem: item)
                }
            }

            // Fallback pager: rows already on screen don't re-fire onAppear
            // when a filter reset shrinks the window around them, which would
            // strand the list at one page. The footer takes a new identity per
            // window size, so its onAppear always fires when it's reachable.
            if viewModel.canLoadMore {
                Color.clear
                    .frame(height: 1)
                    .listRowBackground(Color.clear)
                    .id("audio-list-pager-\(viewModel.visibleContent.count)")
                    .onAppear {
                        viewModel.loadNextPage()
                    }
            }
        }
        .scrollContentBackground(.hidden)
        .background(.clear)
    }

    private var currentFilteredContent: [AudioDeclaration] {
        return viewModel.visibleContent
    }
    
    @ViewBuilder
    var audioBar: some View {
        if audioViewModel.isBarVisible {
            PersistentAudioBar(viewModel: audioViewModel)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.easeOut(duration: 0.4), value: audioViewModel.isBarVisible)
                // REMOVED: onDisappear handler that was trying to resume background music
                // This could contribute to unexpected audio playback
                .onTapGesture {
                    if let lastSelectedItem = audioViewModel.lastSelectedItem {
                        self.audioViewModel.selectedItem = lastSelectedItem
                    }
                }
        }
    }
    
    /// Resolves the pending checklist deep-link (the foundation week's exact
    /// episode) once the catalog can. Consumed atomically: an expired link is
    /// dropped, a resolved one plays, and a loaded catalog that no longer
    /// contains the episode clears the link and leaves the user on the open
    /// tab — never a surprise fallback onto an unrelated episode.
    private func attemptChecklistAutoPlay() {
        guard let deepLink = viewModel.pendingChecklistDeepLink else { return }

        // Tap-to-play should resolve within seconds. A link this old means the
        // catalog never loaded at the time (e.g. offline); playing it on some
        // later visit would be unprompted audio the user never asked for.
        guard Date().timeIntervalSince(deepLink.requestedAt) < 300 else {
            viewModel.pendingChecklistDeepLink = nil
            return
        }

        // Resolve against allAudioFiles, which is assigned in one shot —
        // unlike contentByFilter, which is populated one filter at a time and
        // emits partial snapshots that would misreport the catalog as loaded.
        // Empty means still loading: keep the link and wait for the next
        // emission.
        guard !viewModel.allAudioFiles.isEmpty else { return }
        viewModel.pendingChecklistDeepLink = nil

        guard let episode = viewModel.allAudioFiles.first(where: { $0.id == deepLink.audioId }) else { return }
        if let tag = episode.tag {
            // Surface the filter the episode lives under so the list matches
            // what's about to play.
            viewModel.setSelectedFilter(tag)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            handleItemTap(episode)
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
        Juice.play(.tapSolid)
        
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

// MARK: - Downsampled artwork

/// Decodes asset-catalog artwork at its display size instead of full
/// resolution. Each (asset, size) pair is decoded once, cached, and shared
/// across every row that shows it, so scrolling never pays a full-size decode.
enum ArtworkThumbnailCache {
    private static let cache = NSCache<NSString, UIImage>()

    static func thumbnail(named name: String, size: CGSize) -> UIImage {
        let scale = UIScreen.main.scale
        let target = CGSize(width: size.width * scale, height: size.height * scale)
        let key = "\(name)-\(Int(target.width))x\(Int(target.height))" as NSString
        if let cached = cache.object(forKey: key) { return cached }

        guard let image = UIImage(named: name) else {
            // Cache the miss too, or every body evaluation of a row with a
            // bad asset name repeats the bundle lookup.
            let empty = UIImage()
            cache.setObject(empty, forKey: key)
            return empty
        }

        // Scale so the thumbnail covers the target (aspect fill), matching how
        // the rows crop it. Skip when the source is already near display size.
        let sourceWidth = image.size.width * image.scale
        let sourceHeight = image.size.height * image.scale
        let fillScale = max(target.width / sourceWidth, target.height / sourceHeight)
        guard fillScale < 0.85,
              let thumbnail = image.preparingThumbnail(of: CGSize(width: sourceWidth * fillScale,
                                                                  height: sourceHeight * fillScale)) else {
            cache.setObject(image, forKey: key)
            return image
        }

        cache.setObject(thumbnail, forKey: key)
        return thumbnail
    }
}

struct ArtworkThumbnail: View {
    let name: String
    let size: CGSize

    var body: some View {
        Image(uiImage: ArtworkThumbnailCache.thumbnail(named: name, size: size))
            .resizable()
            .aspectRatio(contentMode: .fill)
    }
}
