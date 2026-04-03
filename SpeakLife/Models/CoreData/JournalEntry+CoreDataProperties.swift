//
//  JournalEntry+CoreDataProperties.swift
//  SpeakLife
//
//  Generated automatically for Core Data
//

import Foundation
import CoreData

extension JournalEntry {
    
    @nonobjc public class func fetchRequest() -> NSFetchRequest<JournalEntry> {
        return NSFetchRequest<JournalEntry>(entityName: "JournalEntry")
    }
    
    @NSManaged public var id: UUID?
    @NSManaged public var text: String?
    @NSManaged public var book: String?
    @NSManaged public var bibleVerseText: String?
    @NSManaged public var category: String?
    @NSManaged public var isFavorite: Bool
    @NSManaged public var createdAt: Date?
    @NSManaged public var lastModified: Date?
}

extension JournalEntry: Identifiable {
    
}