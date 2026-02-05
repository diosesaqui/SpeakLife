//
//  BibleModels.swift
//  SpeakLife
//
//  Created by SpeakLife Team on 1/28/26.
//

import Foundation

// MARK: - Bible Book
struct BibleBook: Codable, Identifiable, Equatable {
    let abbrev: BibleBookAbbrev
    let author: String
    let chapters: Int
    let group: String
    let name: String
    let testament: Testament
    
    var id: String { abbrev.en }
    
    enum Testament: String, Codable {
        case old = "VT"
        case new = "NT"
        
        var displayName: String {
            switch self {
            case .old: return "Old Testament"
            case .new: return "New Testament"
            }
        }
    }
}

struct BibleBookAbbrev: Codable, Equatable {
    let pt: String
    let en: String
}

// MARK: - Bible Chapter
struct BibleChapter: Codable, Identifiable {
    let book: BibleBookInfo
    let chapter: ChapterInfo
    let verses: [BibleVerse]
    
    var id: String { "\(book.abbrev.en)_\(chapter.number)" }
}

struct BibleBookInfo: Codable {
    let abbrev: BibleBookAbbrev
    let name: String
    let author: String
    let group: String
    let version: String
}

struct ChapterInfo: Codable {
    let number: Int
    let verses: Int
}

// MARK: - Bible Verse
struct BibleVerse: Codable, Identifiable, Equatable {
    let number: Int
    let text: String
    
    var id: Int { number }
}

// MARK: - Bible Version
struct BibleVersion: Codable, Identifiable {
    let version: String
    let verses: Int
    
    var id: String { version }
    
    var displayName: String {
        switch version.lowercased() {
        case "asv": return "American Standard Version"
        case "kjv": return "King James Version"
        case "web": return "World English Bible"
        case "nlt": return "New Living Translation"
        case "niv": return "New International Version"
        case "esv": return "English Standard Version"
        case "msg": return "The Message"
        case "amp": return "Amplified Bible"
        case "nkjv": return "New King James Version"
        default: return version.uppercased()
        }
    }
}

// MARK: - Search Models
struct BibleSearchRequest: Codable {
    let version: String
    let search: String
}

struct BibleSearchResponse: Codable {
    let occurrence: Int
    let version: String
    let verses: [SearchedVerse]
}

struct SearchedVerse: Codable, Identifiable {
    let book: BibleBookInfo
    let chapter: Int
    let number: Int
    let text: String
    
    var id: String { "\(book.abbrev.en)_\(chapter)_\(number)" }
}

// MARK: - Random Verse
struct RandomVerse: Codable {
    let book: BibleBookInfo
    let chapter: Int
    let number: Int
    let text: String
}

// MARK: - User Data Models
struct BibleBookmark: Codable, Identifiable {
    let id: UUID
    let bookAbbrev: String
    let bookName: String
    let chapter: Int
    let verseNumber: Int
    let verseText: String
    let version: String
    let dateAdded: Date
    let note: String?
    
    init(bookAbbrev: String, bookName: String, chapter: Int, verseNumber: Int, verseText: String, version: String, note: String? = nil) {
        self.id = UUID()
        self.bookAbbrev = bookAbbrev
        self.bookName = bookName
        self.chapter = chapter
        self.verseNumber = verseNumber
        self.verseText = verseText
        self.version = version
        self.dateAdded = Date()
        self.note = note
    }
}

struct BibleHighlight: Codable, Identifiable {
    let id: UUID
    let bookAbbrev: String
    let chapter: Int
    let verseNumber: Int
    let color: HighlightColor
    let dateAdded: Date
    
    enum HighlightColor: String, Codable, CaseIterable {
        case yellow, blue, green, pink, purple
        
        var hexValue: String {
            switch self {
            case .yellow: return "#FFF59D"
            case .blue: return "#90CAF9"
            case .green: return "#A5D6A7"
            case .pink: return "#F48FB1"
            case .purple: return "#CE93D8"
            }
        }
    }
}

// MARK: - Reading Plan
struct ReadingPlan: Codable, Identifiable {
    let id: UUID
    let name: String
    let description: String
    let totalDays: Int
    let currentDay: Int
    let startDate: Date
    let readings: [DailyReading]
    
    var progress: Double {
        Double(currentDay) / Double(totalDays)
    }
    
    var isCompleted: Bool {
        currentDay >= totalDays
    }
}

struct DailyReading: Codable, Identifiable {
    let id: UUID
    let day: Int
    let passages: [ReadingPassage]
    let isCompleted: Bool
    let completedDate: Date?
}

struct ReadingPassage: Codable {
    let bookAbbrev: String
    let bookName: String
    let startChapter: Int
    let endChapter: Int?
    let startVerse: Int?
    let endVerse: Int?
    
    var reference: String {
        var ref = "\(bookName) \(startChapter)"
        if let startVerse = startVerse {
            ref += ":\(startVerse)"
            if let endVerse = endVerse {
                ref += "-\(endVerse)"
            }
        } else if let endChapter = endChapter {
            ref += "-\(endChapter)"
        }
        return ref
    }
}
