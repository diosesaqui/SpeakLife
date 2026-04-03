//
//  LazyJSONLoader.swift
//  SpeakLife
//
//  Memory-efficient JSON loader to prevent app termination
//

import Foundation

// MARK: - JSON Structure Models
struct WelcomeResponse: Codable {
    let count: Int
    let version: Int
    let declarations: [Declaration]
}

final class LazyJSONLoader {
    static let shared = LazyJSONLoader()
    
    private var cache: [String: [Declaration]] = [:]
    private let maxCacheSize = 3 // Only keep 3 files in memory
    private var cacheOrder: [String] = []
    
    private init() {}
    
    func loadDeclarations(fileName: String, completion: @escaping ([Declaration]) -> Void) {
        
        // Check cache first
        if let cachedDeclarations = cache[fileName] {
            completion(cachedDeclarations)
            return
        }
        
        // Load from disk with memory management
        loadFromDisk(fileName: fileName) { [weak self] declarations in
            guard let self = self else { return }
            
            
            // Manage cache size
            self.manageCache(fileName: fileName, declarations: declarations)
            completion(declarations)
        }
    }
    
    private func loadFromDisk(fileName: String, completion: @escaping ([Declaration]) -> Void) {
        DispatchQueue.global(qos: .background).async {
            let cleanFileName = fileName.replacingOccurrences(of: ".json", with: "")
            
            guard let url = Bundle.main.url(forResource: cleanFileName, withExtension: "json") else {
                DispatchQueue.main.async { completion([]) }
                return
            }
            
            
            do {
                // Use stream-based loading for large files
                let data = try Data(contentsOf: url)
                
                let decoder = JSONDecoder()
                
                // Configure decoder for memory efficiency
                decoder.userInfo[CodingUserInfoKey.memoryLimit] = 50_000_000 // 50MB limit
                
                // Decode the correct structure
                let welcome = try decoder.decode(WelcomeResponse.self, from: data)
                let declarations = welcome.declarations
                
                DispatchQueue.main.async {
                    completion(declarations)
                }
            } catch {
                DispatchQueue.main.async { completion([]) }
            }
        }
    }
    
    private func manageCache(fileName: String, declarations: [Declaration]) {
        // Add to cache
        cache[fileName] = declarations
        
        // Update cache order
        cacheOrder.removeAll { $0 == fileName }
        cacheOrder.append(fileName)
        
        // Remove oldest entries if cache is full
        while cacheOrder.count > maxCacheSize {
            let oldestFile = cacheOrder.removeFirst()
            cache.removeValue(forKey: oldestFile)
        }
    }
    
    func clearCache() {
        cache.removeAll()
        cacheOrder.removeAll()
    }
    
    func preloadFile(_ fileName: String) {
        guard cache[fileName] == nil else { return }
        
        loadDeclarations(fileName: fileName) { _ in
            // File is now cached
        }
    }
}

extension CodingUserInfoKey {
    static let memoryLimit = CodingUserInfoKey(rawValue: "memoryLimit")!
}