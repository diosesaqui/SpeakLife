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
    @Published var dynamicFilters: [FilterConfig] = []  // Filter configs from JSON
    @Published var contentByFilter: [String: [AudioDeclaration]] = [:]  // All content organized by filter ID
    @Published var selectedFilterId: String = "speaklife"  // Selected filter ID (set dynamically from server)
    
    private(set) var allAudioFiles: [AudioDeclaration] = []
    @Published var downloadProgress: [String: Double] = [:]
    @Published var fetchingAudioIDs: Set<String> = []

    // Favorites manager
    let favoritesManager = AudioFavoritesManager()
    private let storage = Storage.storage()
    private let fileManager = FileManager.default
    @AppStorage("lastCachedAudioVersion") private var lastCachedAudioVersion = 0
    private let service: APIService = LocalAPIClient()
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Observe changes in favorites manager to trigger UI updates
        favoritesManager.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
        
        // Listen for real-time audio version updates via push notifications
        NotificationCenter.default
            .publisher(for: .audioVersionUpdated)
            .sink { [weak self] notification in
                if let version = notification.userInfo?["version"] as? Int {
                    print("🎵 AudioDeclarationViewModel: Received version update notification: v\(version)")
                    DispatchQueue.main.async {
                        self?.fetchAudio(version: version)
                    }
                }
            }
            .store(in: &cancellables)
        
        // Load cached audio data on startup (ensure on main thread for @Published updates)
        DispatchQueue.main.async { [weak self] in
            self?.loadCachedAudioData()
        }
    }
    
    private func loadCachedAudioData() {
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
            self.allAudioFiles = cachedAudios
            
            // Try to load cached filters
            if fileManager.fileExists(atPath: filtersURL.path) {
                let filtersData = try Data(contentsOf: filtersURL)
                let cachedFilters = try decoder.decode([FilterConfig].self, from: filtersData)
                self.dynamicFilters = cachedFilters
            }
            
            populateDynamicFiltersFromCache()
        } catch {}
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
    }
    
    private func saveAudioDataToCache() {
        let fileManager = FileManager.default
        let documentDirURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = documentDirURL.appendingPathComponent("audioDeclarations").appendingPathExtension("txt")
        let filtersURL = documentDirURL.appendingPathComponent("audioFilters").appendingPathExtension("txt")
        
        do {
            let encoder = JSONEncoder()
            
            // Save audio data
            let data = try encoder.encode(allAudioFiles)
            try data.write(to: fileURL)
            
            // Save filter configuration if available
            if !dynamicFilters.isEmpty {
                let filtersData = try encoder.encode(dynamicFilters)
                try filtersData.write(to: filtersURL)
            }
        } catch {
            // Failed to save cache, not critical
        }
    }
    
    // New dynamic filtered content
    var dynamicFilteredContent: [AudioDeclaration] {
        if selectedFilterId == "favorites" {
            return favoritesManager.getFavoritesSortedByDate()
        }
        return contentByFilter[selectedFilterId] ?? []
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
                self.allAudioFiles = welcome?.audios ?? audios!
                
                self.setupDynamicFilters(welcome)
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
                    print("🎵 Selected filter updated from server: \(serverSelectedFilterId)")
                } else {
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
                    print("🎵 Selected filter updated from server (fallback): \(serverSelectedFilterId)")
                }
            }
            
            // Populate content using old filter strings
            for filterId in filterStrings {
                if filterId != "favorites" {
                    contentByFilter[filterId] = groupedContent[filterId] ?? []
                }
            }
        }
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
                DispatchQueue.main.async {
                    self.downloadProgress[item.id] = progress.fractionCompleted
                    
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

struct FilterConfig: Codable {
    let id: String
    let displayName: String
    let order: Int?
    let reversed: Bool?
}

struct WelcomeAudio: Codable {
    let version: Int
    let filters: [String]?  // Keep for backward compatibility
    let filterConfigs: [FilterConfig]?  // New dynamic filters
    let selectedFilterId: String?  // Default selected filter from server
    let audios: [AudioDeclaration]
}

struct AudioDeclaration: Identifiable, Equatable, Codable, Comparable, Hashable {
    static func < (lhs: AudioDeclaration, rhs: AudioDeclaration) -> Bool {
        return lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
      let id: String
      let title: String
      let subtitle: String
      let duration: String
      let imageUrl: String
      let isPremium: Bool
      var tag: String?
      var season: Int? // Season number (e.g., 1, 2, 3)
      var episode: Int? // Episode number within the season
      var isFavorite: Bool = false
      var favoriteId: String?
      var dateFavorited: Date?
    
    // Initializer for creating new instances (used in AudioFiles.swift)
    init(id: String, title: String, subtitle: String, duration: String, imageUrl: String, 
         isPremium: Bool, tag: String? = nil, season: Int? = nil, episode: Int? = nil,
         isFavorite: Bool = false, favoriteId: String? = nil, dateFavorited: Date? = nil) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.duration = duration
        self.imageUrl = imageUrl
        self.isPremium = isPremium
        self.tag = tag
        self.season = season
        self.episode = episode
        self.isFavorite = isFavorite
        self.favoriteId = favoriteId
        self.dateFavorited = dateFavorited
    }
    
    // Custom coding keys for the core properties
    private enum CodingKeys: String, CodingKey {
        case id, title, subtitle, duration, imageUrl, isPremium, tag, season, episode
        case isFavorite, favoriteId, dateFavorited
    }
    
    // Custom decoder to handle missing favorite fields
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Decode required fields
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        subtitle = try container.decode(String.self, forKey: .subtitle)
        duration = try container.decode(String.self, forKey: .duration)
        imageUrl = try container.decode(String.self, forKey: .imageUrl)
        isPremium = try container.decode(Bool.self, forKey: .isPremium)
        tag = try container.decodeIfPresent(String.self, forKey: .tag)
        season = try container.decodeIfPresent(Int.self, forKey: .season)
        episode = try container.decodeIfPresent(Int.self, forKey: .episode)
        
        // Decode favorite fields with defaults if missing
        isFavorite = try container.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false
        favoriteId = try container.decodeIfPresent(String.self, forKey: .favoriteId)
        dateFavorited = try container.decodeIfPresent(Date.self, forKey: .dateFavorited)
    }
    
    // Custom encoder to include all fields when saving
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(subtitle, forKey: .subtitle)
        try container.encode(duration, forKey: .duration)
        try container.encode(imageUrl, forKey: .imageUrl)
        try container.encode(isPremium, forKey: .isPremium)
        try container.encodeIfPresent(tag, forKey: .tag)
        try container.encodeIfPresent(season, forKey: .season)
        try container.encodeIfPresent(episode, forKey: .episode)
        try container.encode(isFavorite, forKey: .isFavorite)
        try container.encodeIfPresent(favoriteId, forKey: .favoriteId)
        try container.encodeIfPresent(dateFavorited, forKey: .dateFavorited)
    }
}
