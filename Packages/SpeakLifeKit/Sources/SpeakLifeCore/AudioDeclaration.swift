//
//  AudioDeclaration.swift
//  SpeakLifeCore
//
//  Foundation-only audio declaration model. Moved from
//  Views/AudioDeclarationView/AudioDeclarationViewModel.swift so
//  SpeakLifePersistence (which persists these as favorites) and the
//  networking / API layer can decode them without depending on the app's
//  view layer.
//

import Foundation

public struct FilterConfig: Codable {
    public let id: String
    public let displayName: String
    public let order: Int?
    public let reversed: Bool?

    public init(id: String, displayName: String, order: Int? = nil, reversed: Bool? = nil) {
        self.id = id
        self.displayName = displayName
        self.order = order
        self.reversed = reversed
    }
}

public struct WelcomeAudio: Codable {
    public let version: Int
    public let filters: [String]?  // Keep for backward compatibility
    public let filterConfigs: [FilterConfig]?  // New dynamic filters
    public let selectedFilterId: String?  // Default selected filter from server
    public let audios: [AudioDeclaration]

    public init(version: Int,
                filters: [String]? = nil,
                filterConfigs: [FilterConfig]? = nil,
                selectedFilterId: String? = nil,
                audios: [AudioDeclaration]) {
        self.version = version
        self.filters = filters
        self.filterConfigs = filterConfigs
        self.selectedFilterId = selectedFilterId
        self.audios = audios
    }
}

public struct AudioDeclaration: Identifiable, Equatable, Codable, Comparable, Hashable {
    public static func < (lhs: AudioDeclaration, rhs: AudioDeclaration) -> Bool {
        return lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    public let id: String
    public let title: String
    public let subtitle: String
    public let duration: String
    public let imageUrl: String
    public let isPremium: Bool
    public var tag: String?
    public var season: Int? // Season number (e.g., 1, 2, 3)
    public var episode: Int? // Episode number within the season
    public var isFavorite: Bool = false
    public var favoriteId: String?
    public var dateFavorited: Date?

    /// A real audio record's `id` is its Firebase Storage filename
    /// (e.g. "speaklife-s3ep1.mp3"); playback resolves via
    /// `storage.reference().child(id)`. Schema-priming / test rows that leak
    /// into the remote `audioDevotionals.json` have ids that are not audio
    /// files, so they could never play. Gate them out wherever the catalog is
    /// loaded so junk records can't surface in the list, in any build.
    public var isPlayableAudio: Bool {
        let name = id.lowercased()
        return name.hasSuffix(".mp3") || name.hasSuffix(".m4a")
            || name.hasSuffix(".wav") || name.hasSuffix(".aac")
            || name.hasSuffix(".caf")
    }

    // Initializer for creating new instances (used in AudioFiles.swift)
    public init(id: String, title: String, subtitle: String, duration: String, imageUrl: String,
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
    public init(from decoder: Decoder) throws {
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
    public func encode(to encoder: Encoder) throws {
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
