//
//  AudioAnalytics.swift
//  SpeakLife
//
//  Comprehensive analytics service for audio favorites and engagement tracking
//

import Foundation

final class AudioAnalytics {
    
    static let shared = AudioAnalytics()
    
    private init() {}
    
    // MARK: - Favorites Analytics
    
    /// Track when user toggles favorite status
    func trackFavoriteToggle(audio: AudioDeclaration, isFavorited: Bool) {
        let eventName = isFavorited ? Event.audioFavoriteTapped : Event.audioUnfavoriteTapped
        
        AnalyticsService.shared.track(eventName, parameters: [
            "audio_id": audio.id,
            "audio_title": audio.title,
            "audio_category": audio.tag ?? "unknown",
            "audio_duration": audio.duration,
            "is_premium": audio.isPremium,
            "action_timestamp": Date().iso8601String
        ])
        
    }
    
    /// Track when favorited audio is played
    func trackFavoriteAudioPlayed(audio: AudioDeclaration, playSource: PlaySource = .favoritesList) {
        AnalyticsService.shared.track(Event.favoriteAudioPlayed, parameters: [
            "audio_id": audio.id,
            "audio_title": audio.title,
            "audio_category": audio.tag ?? "unknown",
            "play_source": playSource.rawValue,
            "is_premium": audio.isPremium,
            "play_timestamp": Date().iso8601String
        ])
        
    }
    
    /// Track when favorites category is viewed
    func trackFavoritesCategoryViewed(favoritesCount: Int, sortOrder: FavoritesSortOrder = .dateAdded) {
        AnalyticsService.shared.track(Event.favoritesCategoryViewed, parameters: [
            "favorites_count": favoritesCount,
            "sort_order": sortOrder.rawValue,
            "view_timestamp": Date().iso8601String
        ])
        
    }
    
    /// Track when favorited audio is shared
    func trackFavoriteAudioShared(audio: AudioDeclaration, shareMethod: ShareMethod) {
        AnalyticsService.shared.track(Event.favoriteAudioShared, parameters: [
            "audio_id": audio.id,
            "audio_title": audio.title,
            "audio_category": audio.tag ?? "unknown",
            "share_method": shareMethod.rawValue,
            "is_premium": audio.isPremium,
            "share_timestamp": Date().iso8601String
        ])
        
    }
    
    /// Track when favorite is removed
    func trackFavoriteRemoved(audio: AudioDeclaration, removeSource: RemoveSource = .favoritesList) {
        AnalyticsService.shared.track(Event.favoriteAudioRemoved, parameters: [
            "audio_id": audio.id,
            "audio_title": audio.title,
            "audio_category": audio.tag ?? "unknown",
            "remove_source": removeSource.rawValue,
            "remove_timestamp": Date().iso8601String
        ])
        
    }
    
    /// Track when all favorites are cleared
    func trackFavoritesCleared(count: Int) {
        AnalyticsService.shared.track(Event.favoritesCleared, parameters: [
            "cleared_count": count,
            "clear_timestamp": Date().iso8601String
        ])
        
    }
    
    /// Track favorites sorting behavior
    func trackFavoritesSorted(sortOrder: FavoritesSortOrder, favoritesCount: Int) {
        AnalyticsService.shared.track(Event.favoritesSorted, parameters: [
            "sort_order": sortOrder.rawValue,
            "favorites_count": favoritesCount,
            "sort_timestamp": Date().iso8601String
        ])
        
    }
    
    /// Track favorites search behavior
    func trackFavoritesSearched(searchTerm: String, resultsCount: Int) {
        AnalyticsService.shared.track(Event.favoritesSearched, parameters: [
            "search_term": searchTerm.lowercased(),
            "results_count": resultsCount,
            "search_timestamp": Date().iso8601String
        ])
        
    }
    
    /// Track when user replays a favorite audio
    func trackFavoriteAudioReplay(audio: AudioDeclaration) {
        AnalyticsService.shared.track(Event.favoriteAudioReplayStarted, parameters: [
            "audio_id": audio.id,
            "audio_title": audio.title,
            "audio_category": audio.tag ?? "unknown",
            "replay_timestamp": Date().iso8601String
        ])
        
    }
    
    /// Track favoriting from audio player
    func trackFavoriteFromPlayer(audio: AudioDeclaration, playbackProgress: Double) {
        AnalyticsService.shared.track(Event.favoriteFromPlayer, parameters: [
            "audio_id": audio.id,
            "audio_title": audio.title,
            "audio_category": audio.tag ?? "unknown",
            "playback_progress": playbackProgress,
            "favorite_timestamp": Date().iso8601String
        ])
        
    }
    
    /// Track unfavoriting from audio player
    func trackUnfavoriteFromPlayer(audio: AudioDeclaration, playbackProgress: Double) {
        AnalyticsService.shared.track(Event.unfavoriteFromPlayer, parameters: [
            "audio_id": audio.id,
            "audio_title": audio.title,
            "audio_category": audio.tag ?? "unknown",
            "playback_progress": playbackProgress,
            "unfavorite_timestamp": Date().iso8601String
        ])
        
    }
    
    // MARK: - Engagement Analytics
    
    /// Track comprehensive favorites session data
    func trackFavoritesSession(duration: TimeInterval, actionsPerformed: Int, audioPlayed: Int) {
        AnalyticsService.shared.track("favorites_session_completed", parameters: [
            "session_duration": duration,
            "actions_performed": actionsPerformed,
            "audio_played": audioPlayed,
            "session_timestamp": Date().iso8601String
        ])
        
    }
    
    /// Track user behavior patterns for recommendations
    func trackFavoritesBehaviorPattern(categories: [String], averageListenDuration: TimeInterval) {
        AnalyticsService.shared.track("favorites_behavior_pattern", parameters: [
            "favorite_categories": categories.joined(separator: ","),
            "avg_listen_duration": averageListenDuration,
            "pattern_timestamp": Date().iso8601String
        ])
        
    }
    
    // MARK: - Discovery Analytics
    
    /// Track how users discover content they later favorite
    func trackDiscoveryToFavorite(audio: AudioDeclaration, discoverySource: DiscoverySource, timeToFavorite: TimeInterval) {
        AnalyticsService.shared.track("discovery_to_favorite", parameters: [
            "audio_id": audio.id,
            "audio_title": audio.title,
            "discovery_source": discoverySource.rawValue,
            "time_to_favorite": timeToFavorite,
            "discovery_timestamp": Date().iso8601String
        ])
        
    }
    
    func trackAudioFetch(audio: AudioDeclaration, discoverySource: DiscoverySource) {
        AnalyticsService.shared.track("audio_fetch", parameters: [
            "audio_id": audio.id,
            "audio_title": audio.title,
            "discovery_source": discoverySource.rawValue
        ])
    }
}

// MARK: - Supporting Enums

extension AudioAnalytics {
    
    enum PlaySource: String, CaseIterable {
        case favoritesList = "favorites_list"
        case audioPlayer = "audio_player"
        case search = "search"
        case recommendation = "recommendation"
        case category = "category"
    }
    
    enum FavoritesSortOrder: String, CaseIterable {
        case dateAdded = "date_added"
        case alphabetical = "alphabetical"
        case duration = "duration"
        case category = "category"
        case mostPlayed = "most_played"
    }
    
    enum ShareMethod: String, CaseIterable {
        case social = "social"
        case message = "message"
        case email = "email"
        case copy = "copy"
        case other = "other"
    }
    
    enum RemoveSource: String, CaseIterable {
        case favoritesList = "favorites_list"
        case audioPlayer = "audio_player"
        case contextMenu = "context_menu"
        case swipeAction = "swipe_action"
    }
    
    enum DiscoverySource: String, CaseIterable {
        case category = "category"
        case search = "search"
        case recommendation = "recommendation"
        case shuffle = "shuffle"
        case related = "related"
    }
}

// MARK: - Utility Extensions

private extension Date {
    var iso8601String: String {
        let formatter = ISO8601DateFormatter()
        return formatter.string(from: self)
    }
}
