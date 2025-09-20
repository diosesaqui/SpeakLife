//
//  CoreDataExtensions.swift
//  SpeakLife
//
//  Extensions for converting between Core Data entities and Declaration objects
//

import Foundation
import CoreData

// MARK: - Declaration Extensions
extension Declaration {
    
    init(from journalEntry: JournalEntry) {
        self.init(
            text: journalEntry.text ?? "",
            book: journalEntry.book,
            bibleVerseText: journalEntry.bibleVerseText,
            category: DeclarationCategory(rawValue: journalEntry.category ?? "myOwn") ?? .myOwn,
            categories: [],
            isFavorite: journalEntry.isFavorite,
            contentType: .journal,
            lastEdit: journalEntry.lastModified
        )
    }
    
    init(from affirmationEntry: AffirmationEntry) {
        self.init(
            text: affirmationEntry.text ?? "",
            book: affirmationEntry.book,
            bibleVerseText: affirmationEntry.bibleVerseText,
            category: DeclarationCategory(rawValue: affirmationEntry.category ?? "myOwn") ?? .myOwn,
            categories: [],
            isFavorite: affirmationEntry.isFavorite,
            contentType: .affirmation,
            lastEdit: affirmationEntry.lastModified
        )
    }
}

// MARK: - JournalEntry Extensions
extension JournalEntry {
    
    convenience init(from declaration: Declaration, context: NSManagedObjectContext) {
        self.init(context: context)
        self.id = UUID()
        self.text = declaration.text
        self.book = declaration.book
        self.bibleVerseText = declaration.bibleVerseText
        self.category = declaration.category.rawValue
        self.isFavorite = declaration.isFavorite ?? false
        self.createdAt = Date()
        self.lastModified = declaration.lastEdit ?? Date()
    }
    
    func updateFrom(declaration: Declaration) {
        self.text = declaration.text
        self.book = declaration.book
        self.bibleVerseText = declaration.bibleVerseText
        self.category = declaration.category.rawValue
        self.isFavorite = declaration.isFavorite ?? false
        self.lastModified = Date()
    }
}

// MARK: - AffirmationEntry Extensions
extension AffirmationEntry {
    
    convenience init(from declaration: Declaration, context: NSManagedObjectContext) {
        self.init(context: context)
        self.id = UUID()
        self.text = declaration.text
        self.book = declaration.book
        self.bibleVerseText = declaration.bibleVerseText
        self.category = declaration.category.rawValue
        self.isFavorite = declaration.isFavorite ?? false
        self.createdAt = Date()
        self.lastModified = declaration.lastEdit ?? Date()
    }
    
    func updateFrom(declaration: Declaration) {
        self.text = declaration.text
        self.book = declaration.book
        self.bibleVerseText = declaration.bibleVerseText
        self.category = declaration.category.rawValue
        self.isFavorite = declaration.isFavorite ?? false
        self.lastModified = Date()
    }
}

// MARK: - Collection Extensions
extension Array where Element == JournalEntry {
    
    func toDeclarations() -> [Declaration] {
        return self.map { Declaration(from: $0) }
    }
}

extension Array where Element == AffirmationEntry {
    
    func toDeclarations() -> [Declaration] {
        return self.map { Declaration(from: $0) }
    }
}

extension Array where Element == Declaration {
    
    func toJournalEntries(context: NSManagedObjectContext) -> [JournalEntry] {
        return self.compactMap { declaration in
            guard declaration.contentType == .journal else { return nil }
            return JournalEntry(from: declaration, context: context)
        }
    }
    
    func toAffirmationEntries(context: NSManagedObjectContext) -> [AffirmationEntry] {
        return self.compactMap { declaration in
            guard declaration.contentType == .affirmation else { return nil }
            return AffirmationEntry(from: declaration, context: context)
        }
    }
}