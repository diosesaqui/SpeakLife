//
//  AudioDeclarationViewModel.swift
//  SpeakLife
//
//  Created by Riccardo Washington on 11/14/24.
//

import FirebaseStorage
import SwiftUI
import Combine
import FirebaseAnalytics

final class AudioDeclarationViewModel: ObservableObject {
    // New dynamic system
    @Published var dynamicFilters: [FilterConfig] = []  // Filter configs from JSON (display order, may be personalized)
    // The curated order before any personalization. Source of truth that is
    // cached to disk, so toggling the personalization flag off cleanly restores
    // the original order without a server refetch.
    private var curatedFilters: [FilterConfig] = []
    @Published var contentByFilter: [String: [AudioDeclaration]] = [:]  // All content organized by filter ID
    @Published var selectedFilterId: String = "speaklife" {  // Selected filter ID (set dynamically from server)
        // didSet fires even on same-value assignment (the chip buttons assign
        // unconditionally); without the guard a re-tap of the active chip
        // would collapse the pagination window under the user's scroll.
        didSet { if oldValue != selectedFilterId { refreshFilteredContent(resetPaging: true) } }
    }
    @Published var playedFilter: PlayedFilter = .all {  // Played / Unplayed sub-filter
        didSet { if oldValue != playedFilter { refreshFilteredContent(resetPaging: true) } }
    }
    // Foundation week deep-link from the Today checklist: the exact episode to
    // play. Consumed atomically by AudioDeclarationView once the catalog can
    // resolve it. Carries its request time so a link that never resolved
    // (e.g. tapped offline) expires instead of ghost-autoplaying on a later,
    // unrelated visit to the tab.
    struct ChecklistDeepLink {
        let audioId: String
        let requestedAt: Date
    }
    var pendingChecklistDeepLink: ChecklistDeepLink? = nil
    
    private(set) var allAudioFiles: [AudioDeclaration] = []
    @Published var downloadProgress: [String: Double] = [:]
    @Published var fetchingAudioIDs: Set<String> = []

    // The list the UI renders. `filteredContent` is the full filtered set,
    // recomputed only when its inputs change (never per body evaluation);
    // `visibleContent` is the client-side page window over it so the List
    // starts with a small number of live rows and grows as the user scrolls.
    @Published private(set) var visibleContent: [AudioDeclaration] = []
    private var filteredContent: [AudioDeclaration] = []
    private let pageSize = 25
    private var visibleCount = 25

    // Favorites manager
    let favoritesManager = AudioFavoritesManager()
    private let storage = Storage.storage()
    private let fileManager = FileManager.default
    @AppStorage("lastCachedAudioVersion") private var lastCachedAudioVersion = 0
    private let service: APIService = LocalAPIClient()
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Rebuild the list on favorites changes only when the Favorites filter
        // is showing; rows read heart state from favoritesManager directly, so
        // a toggle elsewhere re-renders one row, not the whole list. The
        // objectWillChange fallback keeps the Favorites chip badge count fresh.
        // receive(on:) defers past @Published's willSet so we read post-update state.
        favoritesManager.$favorites
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                if self.selectedFilterId == "favorites" {
                    self.refreshFilteredContent(resetPaging: false)
                }
                // Always nudge the view model: the Favorites chip badge reads
                // favoritesManager.favoritesCount through the VM, and a change
                // beyond the visible page publishes nothing on its own.
                self.objectWillChange.send()
            }
            .store(in: &cancellables)

        // Played status only reshapes the list when a played/unplayed filter is
        // active; the per-row checkmarks observe AudioProgressStore themselves.
        AudioProgressStore.shared.$playedIDs
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self, self.playedFilter != .all else { return }
                self.refreshFilteredContent(resetPaging: false)
            }
            .store(in: &cancellables)
        
        // Listen for real-time audio version updates via push notifications
        NotificationCenter.default
            .publisher(for: .audioVersionUpdated)
            .sink { [weak self] notification in
                if let version = notification.userInfo?["version"] as? Int {
                    DispatchQueue.main.async {
                        self?.fetchAudio(version: version)
                    }
                }
            }
            .store(in: &cancellables)
        
        // Load cached audio data on startup
        loadCachedAudioData()
    }

    private func loadCachedAudioData() {
        // File IO + JSON decode happen off the main thread; only the
        // @Published assignments hop back to main.
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let fileManager = FileManager.default
            let documentDirURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
            let fileURL = documentDirURL.appendingPathComponent("audioDeclarations").appendingPathExtension("txt")
            let filtersURL = documentDirURL.appendingPathComponent("audioFilters").appendingPathExtension("txt")

            guard fileManager.fileExists(atPath: fileURL.path) else {
                return
            }

            do {
                let data = try Data(contentsOf: fileURL)
                let decoder = JSONDecoder()
                let cachedAudios = try decoder.decode([AudioDeclaration].self, from: data)
                    .filter { $0.isPlayableAudio }

                // Try to load cached filters
                var cachedFilters: [FilterConfig]? = nil
                if fileManager.fileExists(atPath: filtersURL.path) {
                    let filtersData = try Data(contentsOf: filtersURL)
                    cachedFilters = try decoder.decode([FilterConfig].self, from: filtersData)
                }

                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    // A fetch that completed while we were reading disk wins.
                    // Without this guard the disk snapshot (started at init)
                    // could land after a remote fetch and revert the catalog
                    // for the whole session, since the version watermark has
                    // already advanced.
                    guard self.allAudioFiles.isEmpty else { return }
                    self.allAudioFiles = cachedAudios
                    if let cachedFilters = cachedFilters {
                        self.dynamicFilters = cachedFilters
                    }
                    self.populateDynamicFiltersFromCache()
                }
            } catch {}
        }
    }
    
    private func populateDynamicFiltersFromCache() {
        // Clear previous content
        contentByFilter.removeAll()
        
        // Group all content by tag
        let groupedContent = Dictionary(grouping: allAudioFiles) { $0.tag ?? "" }
        
        // If we don't have dynamicFilters loaded yet, create default ones
        if dynamicFilters.isEmpty {
            // Default filter order with favorites first
            var defaultFilters: [FilterConfig] = []
            
            // Always add favorites filter first
            defaultFilters.append(FilterConfig(
                id: "favorites",
                displayName: "Favorites",
                order: 0,
                reversed: false
            ))
            
            // Define the preferred order and reversal settings for known filters
            let knownFilters: [(id: String, displayName: String, order: Int, reversed: Bool)] = [
                ("speaklife", "Speak Life", 1, true),
                ("declarations", "Declarations", 3, false),
                ("godsHeart", "God's Heart", 4, true),
                ("growWithJesus", "Grow With Jesus", 2, false),
                ("psalm91", "Psalm 91", 5, true),
                ("divineHealth", "Divine Health", 6, false),
                ("magnify", "Magnify", 7, true),
                ("gospel", "Gospel", 8, false),
                ("meditation", "Meditation", 9, false),
                ("bedtimeStories", "Bedtime Stories", 10, false)
            ]
            
            // Add known filters in order
            for filter in knownFilters {
                if groupedContent[filter.id] != nil {
                    defaultFilters.append(FilterConfig(
                        id: filter.id,
                        displayName: filter.displayName,
                        order: filter.order,
                        reversed: filter.reversed
                    ))
                }
            }
            
            // Add any unknown tags at the end
            let knownIds = Set(knownFilters.map { $0.id })
            let unknownTags = Set(allAudioFiles.compactMap { $0.tag }).filter { !knownIds.contains($0) }.sorted()
            for tag in unknownTags {
                defaultFilters.append(FilterConfig(
                    id: tag,
                    displayName: tag.capitalized,
                    order: defaultFilters.count,
                    reversed: false
                ))
            }
            
            dynamicFilters = defaultFilters
        }
        
        // Populate content for each filter
        for config in dynamicFilters {
            if config.id == "favorites" {
                // Favorites is handled separately via favoritesManager
                continue
            }
            
            var content = groupedContent[config.id] ?? []
            
            // Apply reversal if specified
            if config.reversed == true {
                content = content.reversed()
            }
            
            contentByFilter[config.id] = content
        }

        curatedFilters = dynamicFilters
        applyPersonalization()
        refreshFilteredContent(resetPaging: true)
    }

    private func saveAudioDataToCache() {
        // Snapshot on the caller's (main) thread, then encode + write off main.
        let audiosToCache = allAudioFiles
        // Save the curated (pre-personalization) order so the cache always
        // holds the canonical order. Falls back to the display order if the
        // baseline was never captured.
        let filtersToCache = curatedFilters.isEmpty ? dynamicFilters : curatedFilters

        DispatchQueue.global(qos: .utility).async {
            let fileManager = FileManager.default
            let documentDirURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
            let fileURL = documentDirURL.appendingPathComponent("audioDeclarations").appendingPathExtension("txt")
            let filtersURL = documentDirURL.appendingPathComponent("audioFilters").appendingPathExtension("txt")

            do {
                let encoder = JSONEncoder()

                // Save audio data (.atomic: LocalAPIClient reads this same file
                // from another queue and must never see a partial write)
                let data = try encoder.encode(audiosToCache)
                try data.write(to: fileURL, options: .atomic)

                if !filtersToCache.isEmpty {
                    let filtersData = try encoder.encode(filtersToCache)
                    try filtersData.write(to: filtersURL, options: .atomic)
                }
            } catch {
                // Failed to save cache, not critical
            }
        }
    }
    
    // The full filtered list. Cached — recomputed by refreshFilteredContent
    // when an input changes, not on every body evaluation.
    var dynamicFilteredContent: [AudioDeclaration] {
        filteredContent
    }

    /// Recomputes the filtered list from the current filter + played state.
    /// `resetPaging` collapses the visible window back to the first page
    /// (filter switches); in-place changes like a played toggle keep it.
    private func refreshFilteredContent(resetPaging: Bool) {
        let base: [AudioDeclaration]
        if selectedFilterId == "favorites" {
            base = favoritesManager.getFavoritesSortedByDate()
        } else {
            base = contentByFilter[selectedFilterId] ?? []
        }

        switch playedFilter {
        case .all:      filteredContent = base
        case .played:   filteredContent = base.filter { AudioProgressStore.shared.isPlayed($0.id) }
        case .unplayed: filteredContent = base.filter { !AudioProgressStore.shared.isPlayed($0.id) }
        }

        if resetPaging {
            visibleCount = pageSize
        }
        updateVisibleContent()
    }

    private func updateVisibleContent() {
        let newVisible = Array(filteredContent.prefix(visibleCount))
        if newVisible != visibleContent {
            visibleContent = newVisible
        }
    }

    var canLoadMore: Bool {
        visibleContent.count < filteredContent.count
    }

    /// Extends the window by one page. Growth derives from the actual visible
    /// count so a stale `visibleCount` (left inflated after a non-reset
    /// refresh shrank the list) can never skew the math.
    func loadNextPage() {
        guard canLoadMore else { return }
        visibleCount = visibleContent.count + pageSize
        updateVisibleContent()
    }

    /// Called from the list rows' onAppear: when the user nears the end of the
    /// visible window, extend it by another page.
    func loadMoreIfNeeded(currentItem: AudioDeclaration) {
        guard canLoadMore,
              visibleContent.suffix(5).contains(where: { $0.id == currentItem.id }) else { return }
        loadNextPage()
    }
    
    func fetchAudio(version: Int) {
        // Don't clear cache if remote version is 0 (not loaded from Remote Config yet)
        if version == 0 {
            return
        }
        
        // If we already have this version and content, don't refetch
        if version <= lastCachedAudioVersion && !allAudioFiles.isEmpty {
            return
        }
        
        if version > lastCachedAudioVersion {
            clearCache()
            clearAudioDeclarationsCache()
        }
        service.audio(version: version) { [weak self] welcome, audios in
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.allAudioFiles = (welcome?.audios ?? audios ?? []).filter { $0.isPlayableAudio }

                if welcome != nil {
                    self.setupDynamicFilters(welcome)
                } else {
                    // Disk/fallback path carries no filter configs.
                    // setupDynamicFilters(nil) would clear contentByFilter and
                    // repopulate nothing, blanking the list for the session;
                    // rebuild groups + default filters from the audios instead.
                    self.populateDynamicFiltersFromCache()
                }
                self.saveAudioDataToCache()
                self.lastCachedAudioVersion = version
            }
        }
    }
    
    private func setupDynamicFilters(_ welcome: WelcomeAudio?) {
        // Clear previous content
        contentByFilter.removeAll()
        
        // Group all content by tag
        let groupedContent = Dictionary(grouping: allAudioFiles) { $0.tag ?? "" }
        
        // Process filter configs from JSON
        if let filterConfigs = welcome?.filterConfigs {
            // Sort by order if provided
            dynamicFilters = filterConfigs.sorted { 
                ($0.order ?? Int.max) < ($1.order ?? Int.max) 
            }
            
            // Set selectedFilterId from server if provided and valid
            if let serverSelectedFilterId = welcome?.selectedFilterId {
                let availableFilterIds = filterConfigs.map { $0.id } + ["favorites"]
                if availableFilterIds.contains(serverSelectedFilterId) {
                    selectedFilterId = serverSelectedFilterId
                } else {
                    // Warning: 
                    print("⚠️ Server provided invalid filter ID: \(serverSelectedFilterId)")
                }
            }
            
            // Populate content for each filter
            for config in filterConfigs {
                if config.id == "favorites" {
                    // Favorites is handled separately
                    continue
                }
                
                var content = groupedContent[config.id] ?? []
                
                // Apply reversal if specified
                if config.reversed == true {
                    content = content.reversed()
                }
                
                contentByFilter[config.id] = content
            }
        } else if let filterStrings = welcome?.filters {
            // Fallback to old system if no filterConfigs
            dynamicFilters = filterStrings.map { filterId in
                FilterConfig(
                    id: filterId,
                    displayName: filterId.capitalized,
                    order: nil,
                    reversed: nil
                )
            }
            
            // Set selectedFilterId from server if provided and valid (fallback)
            if let serverSelectedFilterId = welcome?.selectedFilterId {
                if filterStrings.contains(serverSelectedFilterId) || serverSelectedFilterId == "favorites" {
                    selectedFilterId = serverSelectedFilterId
                }
            }
            
            // Populate content using old filter strings
            for filterId in filterStrings {
                if filterId != "favorites" {
                    contentByFilter[filterId] = groupedContent[filterId] ?? []
                }
            }
        }

        curatedFilters = dynamicFilters
        applyPersonalization()
        refreshFilteredContent(resetPaging: true)
    }

    // MARK: - Personalized Ordering

    /// True when the personalized audio order experiment is enabled via Remote Config.
    var isPersonalizedOrderEnabled: Bool {
        // Through the flag seam, not Remote Config directly, so the debug panel
        // can flip the experiment on a TestFlight device.
        DefaultFeatureFlags.shared.bool("personalizedAudioOrderEnabled", default: false)
    }

    /// Re-applies personalization on demand. Inputs (the Remote Config flag and
    /// favorites) load asynchronously after launch and existing users may not
    /// rebuild filters at all on update, so the audio screen calls this on
    /// appear — by which point those inputs are ready. Safe to call repeatedly.
    func refreshPersonalization() {
        guard !curatedFilters.isEmpty else { return }
        applyPersonalization()
    }

    /// Derives the display order in `dynamicFilters` from the curated baseline.
    /// When the flag is off (or there is no preference signal) the curated order
    /// is restored verbatim, so the experiment is cleanly reversible. Only
    /// publishes when the resulting order actually changes, so repeated calls
    /// (e.g. on every appear) are cheap and don't churn the UI.
    private func applyPersonalization() {
        let newOrder: [FilterConfig]
        if isPersonalizedOrderEnabled {
            let selected = UserDefaults.standard
                .string(forKey: "selectedNotificationCategories")?
                .split(separator: ",")
                .map { String($0).trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty } ?? []

            newOrder = AudioRecommendationEngine.personalizedOrder(
                filters: curatedFilters,
                personalDeclarationCategory: PersonalDeclarationRepository.activeCategoryRaw(),
                selectedCategories: selected,
                engagementCategories: engagementCategoryStrengths(),
                favoritesByFilterId: favoritesCountByFilterId(),
                playedByFilterId: playedCountByFilterId()
            )
        } else {
            newOrder = curatedFilters
        }

        if newOrder.map(\.id) != dynamicFilters.map(\.id) {
            dynamicFilters = newOrder
        }
    }

    /// Recency-weighted strength per category from the user's tracked selections.
    /// Strength = selection count decayed by a 14-day half-life, so categories the
    /// user engaged with recently carry more pull than long-stale ones.
    private func engagementCategoryStrengths() -> [String: Double] {
        let halfLifeDays = 14.0
        var result: [String: Double] = [:]
        for pref in UserPreferencesTracker.shared.topCategories {
            let days = max(0, Date().timeIntervalSince(pref.lastSelected) / 86_400)
            let recency = pow(0.5, days / halfLifeDays)
            result[pref.category] = Double(pref.count) * recency
        }
        return result
    }

    /// Number of favorited episodes per filter id (audio tag).
    private func favoritesCountByFilterId() -> [String: Int] {
        Dictionary(grouping: favoritesManager.favorites.compactMap { $0.tag }) { $0 }
            .mapValues { $0.count }
    }

    /// Number of played episodes per filter id, from already-loaded content.
    private func playedCountByFilterId() -> [String: Int] {
        var counts: [String: Int] = [:]
        for (filterId, items) in contentByFilter {
            let played = items.filter { AudioProgressStore.shared.isPlayed($0.id) }.count
            if played > 0 { counts[filterId] = played }
        }
        return counts
    }

    func fetchAudio(for item: AudioDeclaration, completion: @escaping (Result<URL, Error>) -> Void) {
           // Get the local URL for the file
           let localURL = cachedFileURL(for: item.id)

           // Check if the file exists locally and is valid
           if fileManager.fileExists(atPath: localURL.path) {
               let fileSize = (try? fileManager.attributesOfItem(atPath: localURL.path)[.size] as? Int) ?? 0
               if fileSize > 0 {
                   completion(.success(localURL))
                   return
               } else {
                   // Remove the empty file and re-download
                   try? fileManager.removeItem(at: localURL)
               }
           }

           // If not, download from Firebase
           downloadAudio(for: item, to: localURL, completion: completion)
       }
    
    func downloadAudio(for item: AudioDeclaration, to localURL: URL, completion: @escaping (Result<URL, Error>) -> Void) {
        let storageRef = storage.reference().child(item.id)
        
        let downloadTask = storageRef.write(toFile: localURL) { url, error in
            DispatchQueue.main.async {
                self.downloadProgress[item.id] = 0.0 // Reset progress when download completes
            }
            if let error = error {
                completion(.failure(error))
            } else if let url = url {
                completion(.success(url))
            }
        }
        
        downloadTask.observe(.progress) { snapshot in
            if let progress = snapshot.progress {
                let fraction = progress.fractionCompleted
                DispatchQueue.main.async {
                    // Firebase reports progress many times per second and every
                    // update re-renders the list; only publish visible changes (≥1%).
                    let current = self.downloadProgress[item.id] ?? 0
                    if fraction >= 1.0 || abs(fraction - current) >= 0.01 {
                        self.downloadProgress[item.id] = fraction
                    }
                }
            }
        }
    }
    
    private func cachedFileURL(for filename: String) -> URL {
        let cacheDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
            return cacheDirectory.appendingPathComponent(filename)
        }
    
    private func clearCache() {
        let fileManager = FileManager.default
        if let cacheDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first {
            do {
                let cacheContents = try fileManager.contentsOfDirectory(atPath: cacheDirectory.path)
                for file in cacheContents {
                    let fileURL = cacheDirectory.appendingPathComponent(file)
                    try fileManager.removeItem(at: fileURL)
                }
            } catch {
                // Failed to clear cache
            }
        }
    }
    
    private func clearAudioDeclarationsCache() {
        let fileManager = FileManager.default
        let documentDirURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = documentDirURL.appendingPathComponent("audioDeclarations").appendingPathExtension("txt")
        let filtersURL = documentDirURL.appendingPathComponent("audioFilters").appendingPathExtension("txt")
        
        do {
            if fileManager.fileExists(atPath: fileURL.path) {
                try fileManager.removeItem(at: fileURL)
            }
            if fileManager.fileExists(atPath: filtersURL.path) {
                try fileManager.removeItem(at: filtersURL)
            }
        } catch {
            // Failed to clear cache
        }
    }
    
    // MARK: - Dynamic Filter Management
    
    /// Sets the selected filter ID dynamically
    /// - Parameter filterId: The filter ID to select
    func setSelectedFilter(_ filterId: String) {
        // Validate that the filter exists
        guard filterId == "favorites" || dynamicFilters.contains(where: { $0.id == filterId }) else {
            // Warning: 
            print("⚠️ Invalid filter ID: \(filterId)")
            return
        }
        
        selectedFilterId = filterId
    }
    
    /// Gets the display name for a filter ID
    /// - Parameter filterId: The filter ID
    /// - Returns: The display name for the filter
    func getFilterDisplayName(for filterId: String) -> String {
        if filterId == "favorites" {
            return "Favorites"
        }
        return dynamicFilters.first(where: { $0.id == filterId })?.displayName ?? filterId.capitalized
    }
  }

// MARK: - Played Filter

enum PlayedFilter: String, CaseIterable, Identifiable {
    case all      = "All"
    case played   = "Played"
    case unplayed = "Unplayed"
    var id: String { rawValue }
}

// `FilterConfig`, `WelcomeAudio`, and `AudioDeclaration` were moved into
// `SpeakLifeCore` (see Packages/SpeakLifeKit/Sources/SpeakLifeCore/AudioDeclaration.swift).
// They ship as public types re-exported through `SpeakLifeCoreExports.swift`,
// so every call site here (and elsewhere in the app) keeps working with no
// import change. The move was needed so `SpeakLifePersistence` could persist
// audio favorites without depending on the view layer.
