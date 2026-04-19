//
//  SmartContentProvider.swift
//  SpeakLife
//
//  Created by Claude on 8/9/25.
//

import Foundation

/// Provides smart, contextual Bible promises based on time, user behavior, and categories
class SmartContentProvider {
    static let shared = SmartContentProvider()
    
    private init() {}
    
    /// Get contextually appropriate promise based on time of day, user preferences, and behavior
    func getSmartPromise() -> String {
        let userPreferences = getUserPreferences()
        let timeContext = getTimeContext()
        let userBehavior = getUserBehaviorContext()
        
        // Try to get a contextual promise first
        if let contextualPromise = getContextualPromise(
            preferences: userPreferences,
            timeContext: timeContext,
            behavior: userBehavior
        ) {
            return contextualPromise
        }
        
        // Fallback to standard time-based selection
        return getTimeBasedPromise()
    }
    
    /// Get promise based on specific category preference
    func getPromiseForCategory(_ category: String) -> String {
        let promises = UserDefaults.widgetGroup.stringArray(forKey: "syncedPromises") ?? []
        let filtered = filterPromisesByCategory(promises, category: category)
        
        if !filtered.isEmpty {
            // Prefer unread promises from this category
            let unreadFiltered = filtered.filter { !isPromiseRead($0) }
            return unreadFiltered.randomElement() ?? filtered.randomElement() ?? promises.randomElement() ?? "I am blessed!"
        }
        
        return promises.randomElement() ?? "I am blessed!"
    }
    
    /// Get promise optimized for current emotional/spiritual state
    func getPromiseForMood(_ mood: UserMood) -> String {
        let promises = UserDefaults.widgetGroup.stringArray(forKey: "syncedPromises") ?? []
        let filtered = filterPromisesByMood(promises, mood: mood)
        
        return filtered.randomElement() ?? promises.randomElement() ?? "I am blessed!"
    }
    
    // MARK: - Private Helper Methods
    
    private func getUserPreferences() -> UserPreferences {
        let favoriteCategories = UserDefaults.standard.stringArray(forKey: "favoriteCategories") ?? []
        let preferredTimes = UserDefaults.standard.stringArray(forKey: "preferredPromiseTimes") ?? []
        let readingHistory = UserDefaults.widgetGroup.stringArray(forKey: "readPromises") ?? []
        
        return UserPreferences(
            favoriteCategories: favoriteCategories,
            preferredTimes: preferredTimes,
            readingHistory: readingHistory
        )
    }
    
    private func getTimeContext() -> TimeContext {
        let now = Date()
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: now)
        let dayOfWeek = calendar.component(.weekday, from: now)
        
        let timeOfDay: TimeOfDay
        switch hour {
        case 5...11: timeOfDay = .morning
        case 12...17: timeOfDay = .afternoon
        case 18...21: timeOfDay = .evening
        default: timeOfDay = .night
        }
        
        let dayType: DayType
        if dayOfWeek == 1 { // Sunday
            dayType = .sunday
        } else if dayOfWeek == 7 { // Saturday
            dayType = .saturday
        } else {
            dayType = .weekday
        }
        
        return TimeContext(
            timeOfDay: timeOfDay,
            dayType: dayType,
            hour: hour,
            date: now
        )
    }
    
    private func getUserBehaviorContext() -> UserBehaviorContext {
        let lastReadTime = UserDefaults.widgetGroup.object(forKey: "lastReadTime") as? Date
        let readStreak = UserDefaults.widgetGroup.integer(forKey: "dailyReadStreak")
        let favoriteCount = UserDefaults.widgetGroup.stringArray(forKey: "widgetFavorites")?.count ?? 0
        let lastFavoriteTime = UserDefaults.widgetGroup.object(forKey: "lastFavoriteTime") as? Date
        
        return UserBehaviorContext(
            lastReadTime: lastReadTime,
            readStreak: readStreak,
            favoriteCount: favoriteCount,
            lastFavoriteTime: lastFavoriteTime
        )
    }
    
    private func getContextualPromise(
        preferences: UserPreferences,
        timeContext: TimeContext,
        behavior: UserBehaviorContext
    ) -> String? {
        let promises = UserDefaults.widgetGroup.stringArray(forKey: "syncedPromises") ?? []
        var candidates: [String] = []
        
        // Priority 1: Time-appropriate promises
        let timeAppropriate = filterPromisesByTimeContext(promises, context: timeContext)
        candidates.append(contentsOf: timeAppropriate)
        
        // Priority 2: Category preferences
        for category in preferences.favoriteCategories {
            let categoryPromises = filterPromisesByCategory(promises, category: category)
            candidates.append(contentsOf: categoryPromises)
        }
        
        // Priority 3: Unread promises (encourage variety)
        let unread = promises.filter { !preferences.readingHistory.contains($0) }
        if !unread.isEmpty {
            candidates.append(contentsOf: Array(unread.prefix(10))) // Add top 10 unread
        }
        
        // Remove duplicates and pick randomly
        let uniqueCandidates = Array(Set(candidates))
        return uniqueCandidates.randomElement()
    }
    
    private func getTimeBasedPromise() -> String {
        let promises = UserDefaults.widgetGroup.stringArray(forKey: "syncedPromises") ?? []
        if promises.isEmpty {
            return "I am blessed!"
        }
        let hour = Calendar.current.component(.hour, from: Date())
        let index = hour % promises.count
        return promises[index]
    }
    
    private func filterPromisesByCategory(_ promises: [String], category: String) -> [String] {
        let keywords = getCategoryKeywords(category)
        return promises.filter { promise in
            let lowercasePromise = promise.lowercased()
            return keywords.contains { keyword in
                lowercasePromise.contains(keyword.lowercased())
            }
        }
    }
    
    private func filterPromisesByTimeContext(_ promises: [String], context: TimeContext) -> [String] {
        var keywords: [String]
        
        switch context.timeOfDay {
        case .morning:
            keywords = ["morning", "dawn", "new", "start", "begin", "awake", "arise"]
        case .afternoon:
            keywords = ["work", "labor", "strength", "persevere", "continue", "midday"]
        case .evening:
            keywords = ["evening", "reflect", "thank", "grateful", "bless", "twilight"]
        case .night:
            keywords = ["night", "rest", "sleep", "peace", "calm", "comfort", "quiet"]
        }
        
        // Special handling for Sunday
        if context.dayType == .sunday {
            keywords.append(contentsOf: ["worship", "praise", "holy", "sabbath", "rest"])
        }
        
        return promises.filter { promise in
            let lowercasePromise = promise.lowercased()
            return keywords.contains { keyword in
                lowercasePromise.contains(keyword.lowercased())
            }
        }
    }
    
    private func filterPromisesByMood(_ promises: [String], mood: UserMood) -> [String] {
        let keywords: [String]
        
        switch mood {
        case .anxious:
            keywords = ["peace", "calm", "worry", "anxiety", "fear not", "troubled", "comfort"]
        case .sad:
            keywords = ["comfort", "heal", "sorrow", "joy", "hope", "tears", "mourning"]
        case .grateful:
            keywords = ["thank", "grateful", "bless", "praise", "rejoice", "joy"]
        case .seeking:
            keywords = ["wisdom", "guidance", "path", "way", "seek", "find", "truth"]
        case .celebrating:
            keywords = ["joy", "celebrate", "victory", "triumph", "rejoice", "glad"]
        case .struggling:
            keywords = ["strength", "endure", "persevere", "overcome", "struggle", "burden"]
        }
        
        return promises.filter { promise in
            let lowercasePromise = promise.lowercased()
            return keywords.contains { keyword in
                lowercasePromise.contains(keyword.lowercased())
            }
        }
    }
    
    private func getCategoryKeywords(_ category: String) -> [String] {
        switch category.lowercased() {
        case "faith":
            return ["faith", "believe", "trust", "belief", "faithful"]
        case "hope":
            return ["hope", "future", "tomorrow", "plans", "promise", "eternal"]
        case "love":
            return ["love", "loved", "beloved", "heart", "care", "compassion"]
        case "peace":
            return ["peace", "calm", "rest", "quiet", "still", "tranquil"]
        case "strength":
            return ["strength", "strong", "power", "mighty", "courage", "brave"]
        case "wisdom":
            return ["wisdom", "wise", "understanding", "knowledge", "discern"]
        case "joy":
            return ["joy", "joyful", "happiness", "glad", "rejoice", "delight"]
        case "grace":
            return ["grace", "mercy", "forgiveness", "forgive", "pardon"]
        case "protection":
            return ["protect", "shield", "guard", "safe", "refuge", "fortress"]
        case "provision":
            return ["provide", "supply", "need", "blessing", "abundance"]
        default:
            return [category]
        }
    }
    
    private func isPromiseRead(_ promise: String) -> Bool {
        let readPromises = UserDefaults.widgetGroup.stringArray(forKey: "readPromises") ?? []
        return readPromises.contains(promise)
    }
}

// MARK: - Supporting Types

struct UserPreferences {
    let favoriteCategories: [String]
    let preferredTimes: [String]
    let readingHistory: [String]
}

struct TimeContext {
    let timeOfDay: TimeOfDay
    let dayType: DayType
    let hour: Int
    let date: Date
}

struct UserBehaviorContext {
    let lastReadTime: Date?
    let readStreak: Int
    let favoriteCount: Int
    let lastFavoriteTime: Date?
}

enum TimeOfDay {
    case morning, afternoon, evening, night
}

enum DayType {
    case weekday, saturday, sunday
}

enum UserMood {
    case anxious, sad, grateful, seeking, celebrating, struggling
}