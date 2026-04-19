//
//  DeclarationFavoriteEntry+CoreDataProperties.swift
//  SpeakLife
//
//  Generated automatically for Core Data
//

import Foundation
import CoreData

extension DeclarationFavoriteEntry {
    
    @nonobjc public class func fetchRequest() -> NSFetchRequest<DeclarationFavoriteEntry> {
        return NSFetchRequest<DeclarationFavoriteEntry>(entityName: "DeclarationFavoriteEntry")
    }
    
    @NSManaged public var id: UUID?
    @NSManaged public var declarationId: String
    @NSManaged public var text: String
    @NSManaged public var category: String
    @NSManaged public var contentType: String?
    @NSManaged public var book: String?
    @NSManaged public var bibleVerseText: String?
    @NSManaged public var createdAt: Date?
    @NSManaged public var lastModified: Date?
}

extension DeclarationFavoriteEntry: Identifiable {
    
}