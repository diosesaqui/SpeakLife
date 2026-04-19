//
//  HelloAOBibleAPIServiceTest.swift
//  SpeakLife
//
//  Test file for validating HelloAO API integration
//

import Foundation

// Quick test function to validate the models work with real data
func testHelloAOBibleAPI() async {
    let service = HelloAOBibleAPIService.shared
    
    do {
        // Test the problematic endpoint that was failing
        print("RWRW 🧪 Testing BSB/DEU/13.json endpoint...")
        let chapter = try await service.fetchChapter(translation: "BSB", book: "DEU", chapter: 13)
        
        print("RWRW ✅ Successfully decoded chapter:")
        print("  - Translation: \(chapter.translation.name)")
        print("  - Book: \(chapter.book.name)")
        print("  - Chapter: \(chapter.chapter.number)")
        print("  - Verses: \(chapter.numberOfVerses)")
        print("  - Content items: \(chapter.chapter.content.count)")
        
        // Test adapter
        let bibleChapter = service.adaptChapterToBibleChapter(chapter, bookAbbrev: "deu")
        print("RWRW ✅ Adapter successful: \(bibleChapter.verses.count) verses converted")
        
        // Print first few verses
        for (index, verse) in bibleChapter.verses.prefix(3).enumerated() {
            print("  Verse \(verse.number): \(verse.text)")
        }
        
    } catch {
        print("RWRW ❌ Test failed: \(error)")
    }
}

// Test runner - call this immediately when app starts
func runHelloAOTest() {
    Task {
        await testHelloAOBibleAPI()
    }
}