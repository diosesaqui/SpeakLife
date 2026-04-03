//
//  AudioSectionModel.swift
//  SpeakLife
//
//  Created by Claude on 12/26/24.
//

import Foundation

struct AudioSectionModel: Identifiable {
    let id: String
    let title: String
    let subtitle: String?
    let items: [AudioDeclaration]
    let configuration: SectionConfiguration
    let sectionType: SectionType
    
    init(
        id: String,
        title: String,
        subtitle: String? = nil,
        items: [AudioDeclaration],
        configuration: SectionConfiguration = .default,
        sectionType: SectionType = .standard
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.items = items
        self.configuration = configuration
        self.sectionType = sectionType
    }
}

struct SectionConfiguration {
    let showSeeAll: Bool
    let maxVisibleItems: Int
    let itemWidth: CGFloat
    let itemHeight: CGFloat
    let horizontalSpacing: CGFloat
    let showPlayCount: Bool
    
    static let `default` = SectionConfiguration(
        showSeeAll: true,
        maxVisibleItems: 10,
        itemWidth: 160,
        itemHeight: 200,
        horizontalSpacing: 12,
        showPlayCount: false
    )
    
    static let compact = SectionConfiguration(
        showSeeAll: true,
        maxVisibleItems: 10,
        itemWidth: 140,
        itemHeight: 180,
        horizontalSpacing: 10,
        showPlayCount: false
    )
    
    static let featured = SectionConfiguration(
        showSeeAll: false,
        maxVisibleItems: 5,
        itemWidth: 280,
        itemHeight: 160,
        horizontalSpacing: 16,
        showPlayCount: true
    )
}

enum SectionType {
    case featured
    case favorites
    case recent
    case standard
    case continueListening
}

// Topic categories for SpeakLife content
// SpeakLife Episode Information
struct SpeakLifeEpisodeInfo {
    let season: Int
    let episode: Int
    let seasonKey: String // "s1", "s2", etc.
    let displayName: String // "Season 1", "Season 2", etc.
    
    static func parse(from subtitle: String, id: String) -> SpeakLifeEpisodeInfo? {
        // Parse from subtitle like "S3 Episode 1" or "S2 Episode 12"
        let seasonPattern = #"S(\d+) Episode (\d+)"#
        let seasonRegex = try? NSRegularExpression(pattern: seasonPattern)
        let nsString = subtitle as NSString
        let range = NSRange(location: 0, length: nsString.length)
        
        if let match = seasonRegex?.firstMatch(in: subtitle, options: [], range: range) {
            let seasonRange = match.range(at: 1)
            let episodeRange = match.range(at: 2)
            
            if let season = Int(nsString.substring(with: seasonRange)),
               let episode = Int(nsString.substring(with: episodeRange)) {
                return SpeakLifeEpisodeInfo(
                    season: season,
                    episode: episode,
                    seasonKey: "s\(season)",
                    displayName: "Season \(season)"
                )
            }
        }
        
        // Parse Season 1 format from subtitle like "Episode 1" or "Episode 2"
        let episode1Pattern = #"Episode (\d+)$"#
        let episode1Regex = try? NSRegularExpression(pattern: episode1Pattern)
        
        if let match = episode1Regex?.firstMatch(in: subtitle, options: [], range: range) {
            let episodeRange = match.range(at: 1)
            
            if let episode = Int(nsString.substring(with: episodeRange)) {
                return SpeakLifeEpisodeInfo(
                    season: 1,
                    episode: episode,
                    seasonKey: "s1",
                    displayName: "Season 1"
                )
            }
        }
        
        // Fallback: try to parse from ID like "speaklife-s3ep1.mp3"
        let idSeasonPattern = #"speaklife-s(\d+)ep(\d+)"#
        let idSeasonRegex = try? NSRegularExpression(pattern: idSeasonPattern)
        let idRange = NSRange(location: 0, length: id.count)
        
        if let match = idSeasonRegex?.firstMatch(in: id, options: [], range: idRange) {
            let idNSString = id as NSString
            let seasonRange = match.range(at: 1)
            let episodeRange = match.range(at: 2)
            
            if let season = Int(idNSString.substring(with: seasonRange)),
               let episode = Int(idNSString.substring(with: episodeRange)) {
                return SpeakLifeEpisodeInfo(
                    season: season,
                    episode: episode,
                    seasonKey: "s\(season)",
                    displayName: "Season \(season)"
                )
            }
        }
        
        // Fallback: try to parse Season 1 from ID like "speaklife-ep1.mp3"
        let idEpisodePattern = #"speaklife-ep(\d+)"#
        let idEpisodeRegex = try? NSRegularExpression(pattern: idEpisodePattern)
        
        if let match = idEpisodeRegex?.firstMatch(in: id, options: [], range: idRange) {
            let idNSString = id as NSString
            let episodeRange = match.range(at: 1)
            
            if let episode = Int(idNSString.substring(with: episodeRange)) {
                return SpeakLifeEpisodeInfo(
                    season: 1,
                    episode: episode,
                    seasonKey: "s1",
                    displayName: "Season 1"
                )
            }
        }
        
        return nil
    }
}

enum AudioTopicCategory: String, CaseIterable {
    case dailyEssentials = "daily"
    case morningMotivation = "morning"
    case peaceAndCalm = "peace"
    case confidenceBuilders = "confidence"
    case sleepAndRest = "sleep"
    case gratitude = "gratitude"
    case healing = "healing"
    case abundance = "abundance"
    case relationships = "relationships"
    case faith = "faith"
    
    var displayName: String {
        switch self {
        case .dailyEssentials: return "Daily Essentials"
        case .morningMotivation: return "Morning Motivation"
        case .peaceAndCalm: return "Peace & Calm"
        case .confidenceBuilders: return "Confidence Builders"
        case .sleepAndRest: return "Sleep & Rest"
        case .gratitude: return "Gratitude & Joy"
        case .healing: return "Healing & Restoration"
        case .abundance: return "Abundance & Success"
        case .relationships: return "Love & Relationships"
        case .faith: return "Faith & Spirituality"
        }
    }
    
    var keywords: [String] {
        switch self {
        case .dailyEssentials:
            return ["daily", "essential", "foundation", "core", "basics"]
        case .morningMotivation:
            return ["morning", "wake", "energy", "start", "motivation", "productive", "focus"]
        case .peaceAndCalm:
            return ["peace", "calm", "relax", "stress", "anxiety", "serene", "tranquil"]
        case .confidenceBuilders:
            return ["confidence", "strength", "power", "bold", "courage", "self", "esteem"]
        case .sleepAndRest:
            return ["sleep", "rest", "night", "bedtime", "dream", "restore", "recovery"]
        case .gratitude:
            return ["gratitude", "thankful", "grateful", "joy", "appreciate", "blessing"]
        case .healing:
            return ["healing", "health", "restore", "recover", "whole", "well", "cure"]
        case .abundance:
            return ["abundance", "prosperity", "wealth", "success", "achieve", "goal", "manifest"]
        case .relationships:
            return ["love", "relationship", "family", "friend", "connect", "bond", "unity"]
        case .faith:
            return ["faith", "god", "jesus", "spirit", "divine", "holy", "pray", "worship"]
        }
    }
}