//
//  ListenerMetricsService.swift
//  SpeakLife
//
//  Service for tracking and displaying listener/engagement metrics
//

import Foundation
import FirebaseFirestore
import FirebaseAnalytics

final class ListenerMetricsService: ObservableObject {
    static let shared = ListenerMetricsService()
    private let db = Firestore.firestore()
    
    @Published private(set) var cachedMetrics: [String: Int] = [:]
    private var pendingWrites: [String: Date] = [:]
    private var lastBulkFetch: Date?
    
    // Performance settings
    private let cacheExpiry: TimeInterval = 24 * 60 * 60 // 24 hours
    private let bulkFetchInterval: TimeInterval = 6 * 60 * 60 // 6 hours
    private let writeDebounceInterval: TimeInterval = 30 // 30 seconds
    
    private init() {
        loadCachedMetrics()
        loadLastBulkFetch()
    }
    
    // MARK: - Track Listen Event
    func trackListen(contentId: String, contentType: ContentMetricType) {
        // Track in Firebase Analytics (free)
        Analytics.logEvent("content_listened", parameters: [
            "content_id": contentId,
            "content_type": contentType.rawValue,
            "timestamp": Date().timeIntervalSince1970
        ])
        
        // Debounce Firestore writes to reduce cost
        let now = Date()
        if let lastWrite = pendingWrites[contentId],
           now.timeIntervalSince(lastWrite) < writeDebounceInterval {
            return // Skip if written recently
        }
        
        pendingWrites[contentId] = now
        
        // Batch writes for efficiency (update local cache immediately)
        updateLocalCount(contentId: contentId)
        
        // Schedule background write
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + writeDebounceInterval) {
            self.batchWriteMetrics()
        }
    }
    
    // MARK: - Efficient Updates
    private func updateLocalCount(contentId: String) {
        DispatchQueue.main.async {
            let current = self.cachedMetrics[contentId] ?? 0
            self.cachedMetrics[contentId] = current + 1
            self.saveCacheToUserDefaults()
        }
    }
    
    private func batchWriteMetrics() {
        // Batch update multiple metrics at once to reduce writes
        let userId = UserDefaults.standard.string(forKey: "userId") ?? UUID().uuidString
        
        // Group pending writes by content type
        var audioWrites: [String] = []
        var devotionalWrites: [String] = []
        
        for (contentId, _) in pendingWrites {
            if contentId.hasPrefix("devotional_") {
                devotionalWrites.append(contentId)
            } else {
                audioWrites.append(contentId)
            }
        }
        
        // Update audio content
        for contentId in audioWrites {
            let docRef = db.collection("listenMetrics")
                .document("audio")
                .collection("content")
                .document(contentId)
            
            docRef.setData([
                "contentId": contentId,
                "contentType": "audio",
                "listenCount": FieldValue.increment(Int64(1)),
                "uniqueListenerCount": FieldValue.increment(Int64(1)),
                "lastUpdated": FieldValue.serverTimestamp(),
                "lastListener": userId
            ], merge: true) { error in
                if let error = error {
                    print("Error updating audio \(contentId): \(error)")
                }
            }
        }
        
        // Update devotional content
        for contentId in devotionalWrites {
            let docRef = db.collection("listenMetrics")
                .document("devotional")
                .collection("content")
                .document(contentId)
            
            docRef.setData([
                "contentId": contentId,
                "contentType": "devotional",
                "uniqueListenerCount": FieldValue.increment(Int64(1)),
                "lastUpdated": FieldValue.serverTimestamp(),
                "lastReader": userId
            ], merge: true) { error in
                if let error = error {
                    print("Error updating devotional \(contentId): \(error)")
                }
            }
        }
        
        pendingWrites.removeAll()
    }
    
    // MARK: - Fetch Metrics (Optimized)
    func fetchMetrics(for contentIds: [String], contentType: ContentMetricType) async -> [String: Int] {
        // Return cached data immediately for UI responsiveness
        var results: [String: Int] = [:]
        
        for contentId in contentIds {
            if let cachedCount = cachedMetrics[contentId] {
                results[contentId] = cachedCount
            }
        }
        
        // If we have fresh cache and all requested data, return immediately
        if !results.isEmpty && shouldUseCachedData() {
            print("📦 Using cached metrics for: \(contentIds)")
            return results
        }
        
        // Background refresh if needed (don't block UI)
        if shouldFetchFromFirestore() {
            Task.detached(priority: .utility) {
                await self.bulkFetchAllMetrics(contentType: contentType)
            }
        }
        
        return results
    }
    
    // Efficient bulk fetch (called periodically, not per view)
    private func bulkFetchAllMetrics(contentType: ContentMetricType) async {
        print("🔄 Background bulk fetch starting...")
        
        do {
            // Fetch ALL metrics at once (more efficient than individual calls)
            let snapshot = try await db.collection("listenMetrics")
                .document(contentType.rawValue)
                .collection("content")
                .whereField("uniqueListenerCount", isGreaterThan: 999) // Only fetch 1K+
                .getDocuments()
            
            var bulkMetrics: [String: Int] = [:]
            
            for document in snapshot.documents {
                if let contentId = document.data()["contentId"] as? String,
                   let count = document.data()["uniqueListenerCount"] as? Int {
                    bulkMetrics[contentId] = count
                }
            }
            
            // Update cache with all fetched data
            DispatchQueue.main.async {
                for (id, count) in bulkMetrics {
                    self.cachedMetrics[id] = count
                }
                self.saveCacheToUserDefaults()
                self.lastBulkFetch = Date()
                self.saveLastBulkFetch()
            }
            
            print("✅ Bulk fetched \(bulkMetrics.count) metrics")
            
        } catch {
            print("❌ Error in bulk fetch: \(error)")
        }
    }
    
    private func shouldUseCachedData() -> Bool {
        guard let lastFetch = lastBulkFetch else { return false }
        return Date().timeIntervalSince(lastFetch) < cacheExpiry
    }
    
    private func shouldFetchFromFirestore() -> Bool {
        guard let lastFetch = lastBulkFetch else { return true }
        return Date().timeIntervalSince(lastFetch) > bulkFetchInterval
    }
    
    // MARK: - Cache Management
    private func updateCache(contentId: String, count: Int) {
        DispatchQueue.main.async {
            self.cachedMetrics[contentId] = count
            self.saveCacheToUserDefaults()
        }
    }
    
    private func saveCacheToUserDefaults() {
        UserDefaults.standard.set(cachedMetrics, forKey: "ListenerMetricsCache")
    }
    
    private func loadCachedMetrics() {
        if let cached = UserDefaults.standard.dictionary(forKey: "ListenerMetricsCache") as? [String: Int] {
            cachedMetrics = cached
        }
    }
    
    private func loadLastBulkFetch() {
        if let timestamp = UserDefaults.standard.object(forKey: "LastBulkFetchDate") as? Date {
            lastBulkFetch = timestamp
        }
    }
    
    private func saveLastBulkFetch() {
        UserDefaults.standard.set(lastBulkFetch, forKey: "LastBulkFetchDate")
    }
    
    // MARK: - Formatting
    static func formatListenerCount(_ count: Int) -> String? {
        print("🔢 Formatting count: \(count)")
        guard count >= 1000 else { 
            print("❌ Count below 1000 threshold")
            return nil 
        }
        
        var result: String?
        if count >= 1_000_000 {
            let millions = Double(count) / 1_000_000
            result = String(format: "%.1fM", millions)
        } else if count >= 1000 {
            let thousands = Double(count) / 1000
            if count % 1000 == 0 {
                result = String(format: "%.0fK", thousands)
            } else {
                result = String(format: "%.1fK", thousands)
            }
        }
        
        print("✅ Formatted as: \(result ?? "nil")")
        return result
    }
}

// MARK: - Supporting Types
enum ContentMetricType: String {
    case devotional = "devotional"
    case audio = "audio"
    case declaration = "declaration"
}

// MARK: - View Extension for Easy Access
extension ListenerMetricsService {
    func getFormattedCount(for contentId: String) -> String? {
        guard let count = cachedMetrics[contentId] else { return nil }
        return Self.formatListenerCount(count)
    }
    
    // Call this on app startup to pre-populate cache
    func warmUpCache() {
        guard shouldFetchFromFirestore() else { return }
        
        Task.detached(priority: .utility) {
            await self.bulkFetchAllMetrics(contentType: .audio)
            await self.bulkFetchAllMetrics(contentType: .devotional)
        }
    }
}