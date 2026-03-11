//
//  WidgetIntents.swift
//  SpeakLife & PromisesWidget
//
//  Created by Claude on 8/9/25.
//

import AppIntents
import Foundation
import WidgetKit

// MARK: - Shared Declarations Data
struct SharedPromiseData {
//    static let declarations: [String] = [
//        "I tell you, you can pray for anything, and if you believe that you've received it, it will be yours.",
//        "Love is patient and kind. Love is not jealous or boastful or proud or rude. It does not demand its own way. It is not irritable, and it keeps no record of being wronged.",
//        "Always be joyful. Never stop praying. Be thankful in all circumstances, for this is God's will for you who belong to Christ Jesus.",
//        "The Lord is for me, so I will have no fear. What can mere people do to me?",
//        "The Lord keeps watch over you as you come and go, both now and forever.",
//        "You must serve only the Lord your God. If you do, I will bless you with food and water, and I will protect you from illness.",
//        "I am leaving you with a gift—peace of mind and heart. And the peace I give is a gift the world cannot give. So don't be troubled or afraid.",
//        "How much better to get wisdom than gold, and good judgment than silver!",
//        "A fool is quick-tempered, but a wise person stays calm when insulted.",
//        "The light shines in the darkness, and the darkness can never extinguish it.",
//        "For you know that when your faith is tested, your endurance has a chance to grow.",
//        "Three things will last forever—faith, hope, and love—and the greatest of these is love.",
//        "Don't worry about anything; instead, pray about everything. Tell God what you need, and thank him for all he has done.",
//        "For God has not given us a spirit of fear and timidity, but of power, love, and self-discipline.",
//        "\"For I know the plans I have for you,\" says the Lord. \"They are plans for good and not for disaster, to give you a future and a hope.\"",
//        "Kind words are like honey— sweet to the soul and healthy for the body.",
//        "I have told you all this so that you may have peace in me. Here on earth you will have many trials and sorrows. But take heart, because I have overcome the world.",
//        "Trust in the Lord with all your heart; do not depend on your own understanding.",
//        "And it is impossible to please God without faith. Anyone who wants to come to him must believe that God exists and that he rewards those who sincerely seek him.",
//        "This is the day the Lord has made. We will rejoice and be glad in it.",
//        "Don't be afraid, for I am with you. Don't be discouraged, for I am your God. I will strengthen you and help you. I will hold you up with my victorious right hand."
//    ]
}

// MARK: - App Intents for Widget Interactions

@available(iOS 16.0, *)
struct NextPromiseIntent: AppIntent {
    static var title: LocalizedStringResource = "Next Promise"
    static var description = IntentDescription("Show the next Bible promise")
    static var openAppWhenRun: Bool = false
    
    func perform() async throws -> some IntentResult {
        let nextPromise = getNextPromise()
        
        UserDefaults.widgetGroup.set(nextPromise, forKey: "currentWidgetPromise")
        UserDefaults.widgetGroup.set(Date(), forKey: "lastPromiseChangeDate")
        
        WidgetCenter.shared.reloadTimelines(ofKind: "PromisesWidget")
        
        return .result()
    }
    
    private func getNextPromise() -> String {
        // Use synced promises from app
        let syncedPromises = UserDefaults.widgetGroup.stringArray(forKey: "syncedPromises") ?? []
        let currentPromise = UserDefaults.widgetGroup.string(forKey: "currentWidgetPromise")
        
        if !syncedPromises.isEmpty {
            if let current = currentPromise,
               let currentIndex = syncedPromises.firstIndex(of: current) {
                let nextIndex = (currentIndex + 1) % syncedPromises.count
                return syncedPromises[nextIndex]
            }
            
            return syncedPromises.randomElement() ?? "I am blessed!"
        }
        
        return "I am blessed!"
    }
}

@available(iOS 16.0, *)
struct ToggleFavoriteIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle Favorite"
    static var description = IntentDescription("Add or remove promise from favorites")
    static var openAppWhenRun: Bool = false
    
    func perform() async throws -> some IntentResult {
        let currentPromise = getCurrentPromise()
        print("🎯 ToggleFavoriteIntent: Current promise:", currentPromise)
        
        let wasFavorited = toggleFavoriteStatus(for: currentPromise)
        print("❤️ Was favorited:", wasFavorited, "Now:", !wasFavorited)
        
        UserDefaults.widgetGroup.set(Date(), forKey: "needsSyncFavorites")
        UserDefaults.widgetGroup.set(["promise": currentPromise, "isFavorited": !wasFavorited], forKey: "lastFavoriteAction")
        
        // Debug: Check what's saved
        let allFavorites = UserDefaults.widgetGroup.stringArray(forKey: "widgetFavorites") ?? []
        print("📱 Widget favorites after toggle:", allFavorites.count, "items")
        
        WidgetCenter.shared.reloadTimelines(ofKind: "PromisesWidget")
        
        return .result()
    }
    
    private func getCurrentPromise() -> String {
        return UserDefaults.widgetGroup.string(forKey: "currentWidgetPromise") ?? "I am blessed!"
    }
    
    private func toggleFavoriteStatus(for promise: String) -> Bool {
        var favorites = UserDefaults.widgetGroup.stringArray(forKey: "widgetFavorites") ?? []
        let wasFavorited = favorites.contains(promise)
        
        if wasFavorited {
            favorites.removeAll { $0 == promise }
        } else {
            favorites.append(promise)
        }
        
        UserDefaults.widgetGroup.set(favorites, forKey: "widgetFavorites")
        return wasFavorited
    }
}

@available(iOS 16.0, *)
struct MarkAsReadIntent: AppIntent {
    static var title: LocalizedStringResource = "Mark as Read"
    static var description = IntentDescription("Mark current promise as read")
    static var openAppWhenRun: Bool = false
    
    func perform() async throws -> some IntentResult {
        let currentPromise = getCurrentPromise()
        markAsRead(promise: currentPromise)
        
        UserDefaults.widgetGroup.set(Date(), forKey: "needsSyncReadStatus")
        UserDefaults.widgetGroup.set(currentPromise, forKey: "lastReadPromise")
        
        WidgetCenter.shared.reloadTimelines(ofKind: "PromisesWidget")
        
        return .result()
    }
    
    private func getCurrentPromise() -> String {
        return UserDefaults.widgetGroup.string(forKey: "currentWidgetPromise") ?? "I am blessed!"
    }
    
    private func markAsRead(promise: String) {
        var readPromises = UserDefaults.widgetGroup.stringArray(forKey: "readPromises") ?? []
        if !readPromises.contains(promise) {
            readPromises.append(promise)
            UserDefaults.widgetGroup.set(readPromises, forKey: "readPromises")
        }
    }
}

//// MARK: - UserDefaults Extension
extension UserDefaults {
    static let widgetGroup = UserDefaults(suiteName: "group.com.speaklife.widget") ?? UserDefaults.standard
}
