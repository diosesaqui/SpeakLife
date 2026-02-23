//
//  AudioFavoriteEntry+CoreDataProperties.swift
//  SpeakLife
//
//  Generated automatically for Core Data
//

import Foundation
import CoreData

extension AudioFavoriteEntry {
    
    @nonobjc public class func fetchRequest() -> NSFetchRequest<AudioFavoriteEntry> {
        return NSFetchRequest<AudioFavoriteEntry>(entityName: "AudioFavoriteEntry")
    }
    
    @NSManaged public var id: UUID?
    @NSManaged public var audioId: String
    @NSManaged public var title: String
    @NSManaged public var subtitle: String
    @NSManaged public var duration: String
    @NSManaged public var imageUrl: String
    @NSManaged public var isPremium: Bool
    @NSManaged public var tag: String?
    @NSManaged public var season: Int32
    @NSManaged public var episode: Int32
    @NSManaged public var createdAt: Date?
    @NSManaged public var lastModified: Date?
}

extension AudioFavoriteEntry: Identifiable {
    
}