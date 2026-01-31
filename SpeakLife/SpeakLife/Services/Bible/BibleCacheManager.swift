//
//  BibleCacheManager.swift
//  SpeakLife
//
//  Created by SpeakLife Team on 1/28/26.
//

import Foundation

final class BibleCacheManager {
    private let cacheDirectory: URL
    private let maxCacheAge: TimeInterval = 7 * 24 * 60 * 60 // 7 days
    private let fileManager = FileManager.default
    
    init() {
        // Create cache directory
        guard let documentsPath = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            fatalError("Unable to access cache directory")
        }
        cacheDirectory = documentsPath.appendingPathComponent("BibleCache")
        
        // Ensure directory exists
        do {
            try fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        } catch {
            print("Error creating cache directory: \(error)")
        }
    }
    
    // MARK: - Books Cache
    func cacheBooks(_ books: [BibleBook]) {
        let url = cacheDirectory.appendingPathComponent("books.json")
        if let data = try? JSONEncoder().encode(books) {
            try? data.write(to: url)
        }
    }
    
    func getCachedBooks() -> [BibleBook]? {
        let url = cacheDirectory.appendingPathComponent("books.json")
        
        guard fileManager.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              !isCacheExpired(url: url) else {
            return nil
        }
        
        return try? JSONDecoder().decode([BibleBook].self, from: data)
    }
    
    // MARK: - Chapters Cache
    func cacheChapter(_ chapter: BibleChapter, bookAbbrev: String, chapter chapterNum: Int, version: String) {
        let filename = "\(version)_\(bookAbbrev)_\(chapterNum).json"
        let url = cacheDirectory.appendingPathComponent(filename)
        
        if let data = try? JSONEncoder().encode(chapter) {
            try? data.write(to: url)
        }
    }
    
    func getCachedChapter(bookAbbrev: String, chapter: Int, version: String) -> BibleChapter? {
        let filename = "\(version)_\(bookAbbrev)_\(chapter).json"
        let url = cacheDirectory.appendingPathComponent(filename)
        
        guard fileManager.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              !isCacheExpired(url: url) else {
            return nil
        }
        
        return try? JSONDecoder().decode(BibleChapter.self, from: data)
    }
    
    // MARK: - Versions Cache
    func cacheVersions(_ versions: [BibleVersion]) {
        let url = cacheDirectory.appendingPathComponent("versions.json")
        if let data = try? JSONEncoder().encode(versions) {
            try? data.write(to: url)
        }
    }
    
    func getCachedVersions() -> [BibleVersion]? {
        let url = cacheDirectory.appendingPathComponent("versions.json")
        
        guard fileManager.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              !isCacheExpired(url: url) else {
            return nil
        }
        
        return try? JSONDecoder().decode([BibleVersion].self, from: data)
    }
    
    // MARK: - Cache Management
    func clearAllCache() {
        try? fileManager.removeItem(at: cacheDirectory)
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }
    
    func clearVersionsCache() {
        let url = cacheDirectory.appendingPathComponent("versions.json")
        try? fileManager.removeItem(at: url)
    }
    
    func getCacheSize() async -> Int64 {
        return await Task {
            var size: Int64 = 0
            
            if let enumerator = fileManager.enumerator(at: cacheDirectory, includingPropertiesForKeys: [.fileSizeKey]) {
                for case let fileURL as URL in enumerator {
                    if let fileSize = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                        size += Int64(fileSize)
                    }
                }
            }
            
            return size
        }.value
    }
    
    private func isCacheExpired(url: URL) -> Bool {
        guard let attributes = try? fileManager.attributesOfItem(atPath: url.path),
              let modificationDate = attributes[.modificationDate] as? Date else {
            return true
        }
        
        return Date().timeIntervalSince(modificationDate) > maxCacheAge
    }
    
    // MARK: - Offline Support
    func preloadEssentialData() async {
        // This method can be called to preload popular books/chapters for offline use
        // Implementation would fetch and cache commonly read books like John, Psalms, etc.
    }
}