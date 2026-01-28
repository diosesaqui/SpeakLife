//
//  BiblePresenter.swift
//  SpeakLife
//
//  Created by SpeakLife Team on 1/28/26.
//

import Foundation
import SwiftUI

protocol BiblePresenterProtocol {
    func formatBookForDisplay(_ book: BibleBook) -> BookDisplayModel
    func formatChapterForDisplay(_ chapter: BibleChapter, highlights: [BibleHighlight], bookmarks: [BibleBookmark]) -> ChapterDisplayModel
    func formatSearchResults(_ results: BibleSearchResponse, searchTerm: String) -> [SearchResultDisplayModel]
    func formatVerseReference(book: String, chapter: Int, verse: Int) -> String
    func formatBooksByTestament(_ books: [BibleBook]) -> [TestamentSection]
    func formatReadingHistory(_ history: [(book: String, chapter: Int, date: Date)], books: [BibleBook]) -> [ReadingHistoryDisplayModel]
}

// MARK: - Display Models
struct BookDisplayModel: Identifiable {
    let id: String
    let name: String
    let abbreviation: String
    let author: String
    let chapters: Int
    let testament: String
    let testamentColor: Color
    let groupName: String
    let icon: String
    
    var chapterRange: String {
        chapters == 1 ? "1 chapter" : "\(chapters) chapters"
    }
}

struct ChapterDisplayModel {
    let bookName: String
    let chapterNumber: Int
    let verses: [VerseDisplayModel]
    let nextChapter: (book: String, chapter: Int)?
    let previousChapter: (book: String, chapter: Int)?
    let totalVerses: Int
}

struct VerseDisplayModel: Identifiable {
    let id: String
    let number: Int
    let text: String
    let isBookmarked: Bool
    let highlightColor: Color?
    let reference: String
}

struct SearchResultDisplayModel: Identifiable {
    let id: String
    let bookName: String
    let chapter: Int
    let verseNumber: Int
    let text: AttributedString
    let reference: String
    let bookAbbrev: String
}

struct TestamentSection: Identifiable {
    let id: String
    let name: String
    let books: [BookDisplayModel]
    let color: Color
    let totalBooks: Int
    let totalChapters: Int
}

struct ReadingHistoryDisplayModel: Identifiable {
    let id = UUID()
    let bookName: String
    let bookAbbrev: String
    let chapter: Int
    let date: Date
    let timeAgo: String
    let reference: String
}

// MARK: - Presenter Implementation
final class BiblePresenter: BiblePresenterProtocol {
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
    
    private let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter
    }()
    
    func formatBookForDisplay(_ book: BibleBook) -> BookDisplayModel {
        let testamentColor = book.testament == .old ? Color.purple.opacity(0.8) : Color.blue.opacity(0.8)
        let icon = getBookIcon(for: book.group)
        
        return BookDisplayModel(
            id: book.id,
            name: book.name,
            abbreviation: book.abbrev.en.uppercased(),
            author: book.author,
            chapters: book.chapters,
            testament: book.testament.displayName,
            testamentColor: testamentColor,
            groupName: book.group,
            icon: icon
        )
    }
    
    func formatChapterForDisplay(_ chapter: BibleChapter, highlights: [BibleHighlight], bookmarks: [BibleBookmark]) -> ChapterDisplayModel {
        let verses = chapter.verses.map { verse in
            let highlight = highlights.first { $0.verseNumber == verse.number }
            let isBookmarked = bookmarks.contains { 
                $0.chapter == chapter.chapter.number && 
                $0.verseNumber == verse.number 
            }
            
            return VerseDisplayModel(
                id: "\(chapter.id)_\(verse.number)",
                number: verse.number,
                text: verse.text,
                isBookmarked: isBookmarked,
                highlightColor: highlight.map { getHighlightColor($0.color) },
                reference: "\(chapter.book.name) \(chapter.chapter.number):\(verse.number)"
            )
        }
        
        // Determine navigation
        let totalChapters = getTotalChapters(for: chapter.book.abbrev.en)
        let nextChapter: (book: String, chapter: Int)? = 
            chapter.chapter.number < totalChapters ? (chapter.book.abbrev.en, chapter.chapter.number + 1) : nil
        let previousChapter: (book: String, chapter: Int)? = 
            chapter.chapter.number > 1 ? (chapter.book.abbrev.en, chapter.chapter.number - 1) : nil
        
        return ChapterDisplayModel(
            bookName: chapter.book.name,
            chapterNumber: chapter.chapter.number,
            verses: verses,
            nextChapter: nextChapter,
            previousChapter: previousChapter,
            totalVerses: chapter.chapter.verses
        )
    }
    
    func formatSearchResults(_ results: BibleSearchResponse, searchTerm: String) -> [SearchResultDisplayModel] {
        return results.verses.map { verse in
            let highlightedText = highlightSearchTerm(in: verse.text, searchTerm: searchTerm)
            
            return SearchResultDisplayModel(
                id: "\(verse.book.abbrev.en)_\(verse.chapter)_\(verse.number)",
                bookName: verse.book.name,
                chapter: verse.chapter,
                verseNumber: verse.number,
                text: highlightedText,
                reference: "\(verse.book.name) \(verse.chapter):\(verse.number)",
                bookAbbrev: verse.book.abbrev.en
            )
        }
    }
    
    func formatVerseReference(book: String, chapter: Int, verse: Int) -> String {
        return "\(book) \(chapter):\(verse)"
    }
    
    func formatBooksByTestament(_ books: [BibleBook]) -> [TestamentSection] {
        let oldTestamentBooks = books.filter { $0.testament == .old}
        let newTestamentBooks = books.filter { $0.testament == .new }
        
        var sections: [TestamentSection] = []
        
        if !oldTestamentBooks.isEmpty {
            let oldTestamentDisplay = oldTestamentBooks.map { formatBookForDisplay($0) }
            let totalChapters = oldTestamentBooks.reduce(0) { $0 + $1.chapters }
            sections.append(TestamentSection(
                id: "old",
                name: "Old Testament",
                books: oldTestamentDisplay,
                color: Color.purple.opacity(0.8),
                totalBooks: oldTestamentBooks.count,
                totalChapters: totalChapters
            ))
        }
        
        if !newTestamentBooks.isEmpty {
            let newTestamentDisplay = newTestamentBooks.map { formatBookForDisplay($0) }
            let totalChapters = newTestamentBooks.reduce(0) { $0 + $1.chapters }
            sections.append(TestamentSection(
                id: "new",
                name: "New Testament",
                books: newTestamentDisplay,
                color: Color.blue.opacity(0.8),
                totalBooks: newTestamentBooks.count,
                totalChapters: totalChapters
            ))
        }
        
        return sections
    }
    
    func formatReadingHistory(_ history: [(book: String, chapter: Int, date: Date)], books: [BibleBook]) -> [ReadingHistoryDisplayModel] {
        return history.compactMap { entry in
            guard let book = books.first(where: { $0.abbrev.en == entry.book }) else { return nil }
            
            return ReadingHistoryDisplayModel(
                bookName: book.name,
                bookAbbrev: entry.book,
                chapter: entry.chapter,
                date: entry.date,
                timeAgo: relativeFormatter.localizedString(for: entry.date, relativeTo: Date()),
                reference: "\(book.name) \(entry.chapter)"
            )
        }
    }
    
    // MARK: - Private Helpers
    private func getBookIcon(for group: String) -> String {
        switch group.lowercased() {
        case "pentateuco", "pentateuch":
            return "scroll.fill"  // Torah/Law scrolls
        case "históricos", "historical", "history":
            return "building.columns.fill"  // Ancient temples/historical buildings
        case "poéticos", "poetry", "wisdom":
            return "lightbulb.fill"  // Wisdom and insight
        case "profetas maiores", "major prophets":
            return "megaphone.fill"  // Major prophetic voice
        case "profetas menores", "minor prophets":
            return "speaker.wave.2.fill"  // Minor prophetic voice
        case "evangelhos", "gospels":
            return "heart.fill"  // Good news/love of Christ
        case "cartas", "epistles", "letters", "pauline epistles", "pastoral epistles", "general epistles":
            return "envelope.fill"  // Letters/correspondence
        case "revelação", "revelation", "apocalypse", "prophecy":
            return "eye.fill"  // Vision/revelation
        default:
            return "book.fill"
        }
    }
    
    private func getHighlightColor(_ color: BibleHighlight.HighlightColor) -> Color {
        switch color {
        case .yellow:
            return Color.yellow.opacity(0.3)
        case .blue:
            return Color.blue.opacity(0.3)
        case .green:
            return Color.green.opacity(0.3)
        case .pink:
            return Color.pink.opacity(0.3)
        case .purple:
            return Color.purple.opacity(0.3)
        }
    }
    
    private func highlightSearchTerm(in text: String, searchTerm: String) -> AttributedString {
        var attributedString = AttributedString(text)
        let searchTermLowercased = searchTerm.lowercased()
        let textLowercased = text.lowercased()
        
        var searchRange = textLowercased.startIndex..<textLowercased.endIndex
        while let range = textLowercased.range(of: searchTermLowercased, options: .caseInsensitive, range: searchRange) {
            // Convert the String range to the AttributedString's index range
            if let attributedRange = Range(
                NSRange(range, in: text),
                in: attributedString
            ) {
                attributedString[attributedRange].backgroundColor = Color.yellow.opacity(0.3)
                attributedString[attributedRange].font = .body.bold()
            }
            searchRange = range.upperBound..<textLowercased.endIndex
        }
        
        return attributedString
    }
    
    private func getTotalChapters(for bookAbbrev: String) -> Int {
        // This would ideally come from the book data
        // For now, returning a default value
        return 50
    }
}
