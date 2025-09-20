//
//  AudioDeclarationViewModel.swift
//  SpeakLife
//
//  Created by Riccardo Washington on 11/14/24.
//

import Foundation
import FirebaseStorage
import SwiftUI
import Combine

final class AudioDeclarationViewModel: ObservableObject {
    // Legacy arrays - kept for backward compatibility, will be deprecated
    @Published var audioDeclarations: [AudioDeclaration]  = []
    @Published var bedtimeStories: [AudioDeclaration]  = []
    @Published var gospelStories: [AudioDeclaration]  = []
    @Published var meditations: [AudioDeclaration]  = []
    @Published var devotionals: [AudioDeclaration]  = []
    @Published var speaklife: [AudioDeclaration]  = []
    @Published var godsHeart: [AudioDeclaration]  = []
    @Published var growWithJesus: [AudioDeclaration]  = []
    @Published var divineHealth: [AudioDeclaration]  = []
    @Published var imagination: [AudioDeclaration]  = []
    @Published var psalm91: [AudioDeclaration]  = []
    @Published var magnify: [AudioDeclaration]  = []
    @Published var praise: [AudioDeclaration]  = []
    
    // New dynamic system
    @Published var dynamicFilters: [FilterConfig] = []  // Filter configs from JSON
    @Published var contentByFilter: [String: [AudioDeclaration]] = [:]  // All content organized by filter ID
    @Published var selectedFilterId: String = "speaklife"  // Selected filter ID
    
    private(set) var allAudioFiles: [AudioDeclaration] = []
    @Published var downloadProgress: [String: Double] = [:]
    @Published var fetchingAudioIDs: Set<String> = []
    
    // Legacy filter system - will be deprecated
    @Published var filters: [Filter] = [.favorites, .speaklife, .declarations, .praise, .godsHeart, .growWithJesus, .psalm91, .divineHealth, .magnify, .gospel, .meditation, .bedtimeStories]
    @Published var selectedFilter: Filter = .speaklife

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
        
        // Load cached audio data on startup
        loadCachedAudioData()
    }
    
    private func loadCachedAudioData() {
        let fileManager = FileManager.default
        let documentDirURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = documentDirURL.appendingPathComponent("audioDeclarations").appendingPathExtension("txt")
        
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return
        }
        
        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            let cachedAudios = try decoder.decode([AudioDeclaration].self, from: data)
            
            self.allAudioFiles = cachedAudios
            
            // Populate the filtered arrays
            audioDeclarations = allAudioFiles.filter { $0.tag == "declarations" }
            bedtimeStories = allAudioFiles.filter { $0.tag == "bedtimeStories" }
            gospelStories = allAudioFiles.filter { $0.tag == "gospel" }
            meditations = allAudioFiles.filter { $0.tag == "meditation" }
            speaklife = allAudioFiles.filter { $0.tag == "speaklife" }
            godsHeart = allAudioFiles.filter { $0.tag == "godsHeart" }
            growWithJesus = allAudioFiles.filter { $0.tag == "growWithJesus" }
            divineHealth = allAudioFiles.filter { $0.tag == "divineHealth" }
            psalm91 = allAudioFiles.filter { $0.tag == "psalm91" }
            imagination = allAudioFiles.filter { $0.tag == "imagination" }
            magnify = allAudioFiles.filter { $0.tag == "magnify" }
            praise = allAudioFiles.filter { $0.tag == "praise" }
            
        } catch {
            // Failed to load cached data, will fetch from service
        }
    }
    
    private func saveAudioDataToCache() {
        let fileManager = FileManager.default
        let documentDirURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = documentDirURL.appendingPathComponent("audioDeclarations").appendingPathExtension("txt")
        
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(allAudioFiles)
            try data.write(to: fileURL)
        } catch {
            // Failed to save cache, not critical
        }
    }

    
    // Legacy computed property for backward compatibility
    var filteredContent: [AudioDeclaration] {
        switch selectedFilter {
        case .favorites:
            return favoritesManager.getFavoritesSortedByDate()
        case .declarations:
            return audioDeclarations
        case .bedtimeStories:
            return bedtimeStories
        case .gospel:
            return gospelStories
        case .meditation:
            return meditations
        case .devotional:
            return devotionals
        case .speaklife:
            return speaklife.reversed()
        case .godsHeart:
            return godsHeart.reversed()
        case .growWithJesus:
            return growWithJesus
        case .divineHealth:
            return divineHealth
        case .imagination:
            return imagination
        case .psalm91:
            return psalm91.reversed()
        case .magnify:
            return magnify.reversed()
        case .praise:
            return praise.reversed()
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
                
                // Legacy system - populate individual arrays
                audioDeclarations = self.allAudioFiles.filter { $0.tag == "declarations" }
                bedtimeStories = self.allAudioFiles.filter { $0.tag == "bedtimeStories" }
                gospelStories = self.allAudioFiles.filter { $0.tag == "gospel" }
                meditations = self.allAudioFiles.filter { $0.tag == "meditation" }
                speaklife = self.allAudioFiles.filter { $0.tag == "speaklife" }
                godsHeart = self.allAudioFiles.filter { $0.tag == "godsHeart" }
                growWithJesus = self.allAudioFiles.filter { $0.tag == "growWithJesus" }
                divineHealth = self.allAudioFiles.filter { $0.tag == "divineHealth" }
                psalm91 = self.allAudioFiles.filter { $0.tag == "psalm91" }
                imagination = self.allAudioFiles.filter { $0.tag == "imagination" }
                magnify = self.allAudioFiles.filter { $0.tag == "magnify" }
                praise = self.allAudioFiles.filter { $0.tag == "praise" }
                
                // New dynamic system
                self.setupDynamicFilters(welcome)
                
                // Legacy filter setup
                setFilters(welcome)
                
                // Save audio data to cache
                self.saveAudioDataToCache()
                
                // Update the cached version after successful fetch
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
            
            // Populate content using old filter strings
            for filterId in filterStrings {
                if filterId != "favorites" {
                    contentByFilter[filterId] = groupedContent[filterId] ?? []
                }
            }
        }
    }
                    
    private func setFilters(_ welcome: WelcomeAudio?) {
        // Default filters to use if none provided
        let defaultFilters: [Filter] = [.favorites, .speaklife, .declarations, .praise, .godsHeart, .growWithJesus, .psalm91, .divineHealth, .magnify, .gospel, .meditation, .bedtimeStories]
        
        guard let filterStrings = welcome?.filters else {
            self.filters = defaultFilters
            return 
        }
        
        // Dynamically map JSON strings to Filter enum cases
        // This works because Filter enum raw values now match the JSON strings exactly
        let mappedFilters = filterStrings.compactMap { filterString in
            // Try to create Filter from raw value (this matches enum case names)
            Filter(rawValue: filterString)
        }
        
        // If we successfully mapped some filters, use them; otherwise use defaults
        self.filters = mappedFilters.isEmpty ? defaultFilters : mappedFilters
        
        // Log any unmapped filters for debugging
        let unmappedFilters = filterStrings.filter { filterString in
            Filter(rawValue: filterString) == nil
        }
        if !unmappedFilters.isEmpty {
            print("Warning: Could not map these filters from JSON: \(unmappedFilters)")
            print("Available filter cases: \(Filter.allCases.map { $0.rawValue })")
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
        
        do {
            if fileManager.fileExists(atPath: fileURL.path) {
                try fileManager.removeItem(at: fileURL)
            }
        } catch {
            // Failed to clear cache
        }
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
    let audios: [AudioDeclaration]
}

struct AudioDeclaration: Identifiable, Equatable, Codable, Comparable {
    static func < (lhs: AudioDeclaration, rhs: AudioDeclaration) -> Bool {
        return lhs.id == rhs.id
    }
    
      let id: String
      let title: String
      let subtitle: String
      let duration: String
      let imageUrl: String
      let isPremium: Bool
      var tag: String?
      var isFavorite: Bool = false
      var favoriteId: String?
      var dateFavorited: Date?
    
    // Initializer for creating new instances (used in AudioFiles.swift)
    init(id: String, title: String, subtitle: String, duration: String, imageUrl: String, 
         isPremium: Bool, tag: String? = nil, isFavorite: Bool = false, 
         favoriteId: String? = nil, dateFavorited: Date? = nil) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.duration = duration
        self.imageUrl = imageUrl
        self.isPremium = isPremium
        self.tag = tag
        self.isFavorite = isFavorite
        self.favoriteId = favoriteId
        self.dateFavorited = dateFavorited
    }
    
    // Custom coding keys for the core properties
    private enum CodingKeys: String, CodingKey {
        case id, title, subtitle, duration, imageUrl, isPremium, tag
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
        try container.encode(isFavorite, forKey: .isFavorite)
        try container.encodeIfPresent(favoriteId, forKey: .favoriteId)
        try container.encodeIfPresent(dateFavorited, forKey: .dateFavorited)
    }
}
