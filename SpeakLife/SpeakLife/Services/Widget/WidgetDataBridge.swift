//
//  WidgetDataBridge.swift
//  SpeakLife
//
//  Created by Claude on 8/9/25.
//

import Foundation
import CoreData
import WidgetKit

/// Bridge between widget UserDefaults and main app CoreData
class WidgetDataBridge: ObservableObject {
    static let shared = WidgetDataBridge()
    
    private init() {}
    
    /// Sync favorites from app to widget UserDefaults
    func syncFavoritesToWidget() {
        // For now, we'll need to get favorites from the Declaration model
        // This will be called from DeclarationViewModel when favorites change
        // The DeclarationViewModel will pass the favorite texts
        
        // Just refresh widgets to pick up any changes
        WidgetCenter.shared.reloadTimelines(ofKind: "PromisesWidget")
    }
    
    /// Direct sync method for Declaration favorites
    func syncDeclarationFavorites(_ favoriteTexts: [String]) {
        print("🔄 WidgetDataBridge: Syncing \(favoriteTexts.count) favorites to widget")
        print("📝 Favorite texts:", favoriteTexts)
        
        // Update widget UserDefaults with favorite texts
        UserDefaults.widgetGroup.set(favoriteTexts, forKey: "widgetFavorites")
        
        // Verify the save
        let saved = UserDefaults.widgetGroup.stringArray(forKey: "widgetFavorites") ?? []
        print("✅ Verified saved favorites:", saved.count)
        print("🔍 App Group available:", UserDefaults.widgetGroup != UserDefaults.standard)
        
        // Refresh widgets
        WidgetCenter.shared.reloadTimelines(ofKind: "PromisesWidget")
        print("🔄 Widget refresh triggered")
    }
    
    /// Sync optimized set of declarations to widget
    func syncAllDeclarationsToWidget(_ declarations: [String]) {
        // Validate input
        guard !declarations.isEmpty else { return }
        
        // Optimize: Only sync a subset for better performance and storage efficiency
        let optimizedDeclarations = Array(declarations.shuffled().prefix(100))
        
        // Update widget UserDefaults with optimized declaration texts
        UserDefaults.widgetGroup.set(optimizedDeclarations, forKey: "syncedPromises")
        
        // Store timestamp for sync tracking
        UserDefaults.widgetGroup.set(Date(), forKey: "lastSyncDate")
        
        // Refresh widgets
        WidgetCenter.shared.reloadTimelines(ofKind: "PromisesWidget")
    }
    
    /// Sync declarations organized by categories for smart filtering
    func syncCategorizedDeclarations(_ declarationsByCategory: [String: [String]]) {
        guard !declarationsByCategory.isEmpty else { return }
        
        // Store each category's declarations separately for smart filtering
        for (category, declarations) in declarationsByCategory {
            let categoryKey = "category_\(category)"
            let optimizedDeclarations = Array(declarations.prefix(50)) // Limit per category
            UserDefaults.widgetGroup.set(optimizedDeclarations, forKey: categoryKey)
        }
        
        // Store category list for reference
        let availableCategories = Array(declarationsByCategory.keys)
        UserDefaults.widgetGroup.set(availableCategories, forKey: "availableCategories")
        
        // Update sync timestamp
        UserDefaults.widgetGroup.set(Date(), forKey: "lastCategorySyncDate")
        
        // Refresh widgets
        WidgetCenter.shared.reloadTimelines(ofKind: "PromisesWidget")
    }
    
    /// Update user's selected categories for widget filtering
    func updateSelectedCategories(_ categories: [String]) {
        UserDefaults.widgetGroup.set(categories, forKey: "selectedCategories")
        UserDefaults.widgetGroup.set(Date(), forKey: "lastCategoryUpdate")
        
        // Refresh widgets immediately to reflect new category preferences
        WidgetCenter.shared.reloadTimelines(ofKind: "PromisesWidget")
    }
    
    /// Track category usage for intelligent recommendations
    func trackCategoryUsage(_ category: String) {
        let usageKey = "categoryUsage"
        var usage = UserDefaults.widgetGroup.dictionary(forKey: usageKey) as? [String: Int] ?? [:]
        usage[category] = (usage[category] ?? 0) + 1
        UserDefaults.widgetGroup.set(usage, forKey: usageKey)
    }
    
    /// Sync widget favorites back to CoreData
    func syncFavoritesFromWidget() {
        let widgetFavorites = UserDefaults.widgetGroup.stringArray(forKey: "widgetFavorites") ?? []
        let context = PersistenceController.shared.container.viewContext
        
        for favoriteText in widgetFavorites {
            // Check if this affirmation already exists in CoreData
            let request: NSFetchRequest<AffirmationEntry> = AffirmationEntry.fetchRequest()
            request.predicate = NSPredicate(format: "text == %@", favoriteText)
            
            do {
                let existingEntries = try context.fetch(request)
                
                if let existingEntry = existingEntries.first {
                    // Update existing entry
                    existingEntry.isFavorite = true
                    existingEntry.lastModified = Date()
                } else {
                    // Create new entry
                    let newEntry = AffirmationEntry(context: context)
                    newEntry.text = favoriteText
                    newEntry.isFavorite = true
                    newEntry.createdAt = Date()
                    newEntry.lastModified = Date()
                }
            } catch {
                print("Failed to sync favorite from widget: \(error)")
            }
        }
        
        // Save context
        do {
            try context.save()
        } catch {
            print("Failed to save favorites from widget: \(error)")
        }
    }
    
    /// Sync read status to widget
    func syncReadStatusToWidget() {
        let context = PersistenceController.shared.container.viewContext
        let request: NSFetchRequest<AffirmationEntry> = AffirmationEntry.fetchRequest()
        // Simplified - just use UserDefaults for now
        // request.predicate = NSPredicate(format: "createdAt != nil")
        
        // Simplified - read status is already managed in UserDefaults
        // Just refresh widgets
        WidgetCenter.shared.reloadTimelines(ofKind: "PromisesWidget")
    }
    
    /// Sync read status from widget to CoreData
    func syncReadStatusFromWidget() {
        let readPromises = UserDefaults.widgetGroup.stringArray(forKey: "readPromises") ?? []
        let context = PersistenceController.shared.container.viewContext
        
        for readPromise in readPromises {
            let request: NSFetchRequest<AffirmationEntry> = AffirmationEntry.fetchRequest()
            request.predicate = NSPredicate(format: "text == %@", readPromise)
            
            do {
                let existingEntries = try context.fetch(request)
                
                // Simplified - just track in UserDefaults for now
                // Would need to add read tracking properties to CoreData model
                print("Syncing read promise from widget: \(readPromise)")
            } catch {
                print("Failed to sync read status from widget: \(error)")
            }
        }
        
        do {
            try context.save()
        } catch {
            print("Failed to save read status from widget: \(error)")
        }
    }
    
    /// Process pending widget actions
    func processPendingWidgetActions() {
        print("🔍 WidgetDataBridge: Checking for pending widget actions...")
        
        // Check for pending favorite actions
        if let lastFavoriteChange = UserDefaults.widgetGroup.object(forKey: "needsSyncFavorites") as? Date,
           lastFavoriteChange.timeIntervalSinceNow > -300, // Within last 5 minutes
           let favoriteAction = UserDefaults.widgetGroup.dictionary(forKey: "lastFavoriteAction"),
           let promise = favoriteAction["promise"] as? String,
           let isFavorited = favoriteAction["isFavorited"] as? Bool {
            
            print("✅ Found pending favorite action:")
            print("   Promise:", promise)
            print("   Should be favorited:", isFavorited)
            print("   Time since action:", -lastFavoriteChange.timeIntervalSinceNow, "seconds ago")
            
            updateFavoriteInCoreData(promise: promise, isFavorited: isFavorited)
            UserDefaults.widgetGroup.removeObject(forKey: "needsSyncFavorites")
            UserDefaults.widgetGroup.removeObject(forKey: "lastFavoriteAction")
        } else {
            print("❌ No pending favorite actions found")
            print("   Checking UserDefaults.widgetGroup availability:", UserDefaults.widgetGroup != UserDefaults.standard)
            
            if let lastChange = UserDefaults.widgetGroup.object(forKey: "needsSyncFavorites") as? Date {
                print("   Last change was:", -lastChange.timeIntervalSinceNow, "seconds ago (too old)")
            } else {
                print("   No 'needsSyncFavorites' timestamp found")
            }
            
            if let favoriteAction = UserDefaults.widgetGroup.dictionary(forKey: "lastFavoriteAction") {
                print("   Found action dict but timestamp issue:", favoriteAction)
            } else {
                print("   No 'lastFavoriteAction' dictionary found")
            }
            
            // Debug: Check all keys
            print("   All UserDefaults keys:", UserDefaults.widgetGroup.dictionaryRepresentation().keys.sorted())
        }
        
        // Check for pending read status actions
        if let lastReadChange = UserDefaults.widgetGroup.object(forKey: "needsSyncReadStatus") as? Date,
           lastReadChange.timeIntervalSinceNow > -300, // Within last 5 minutes
           let readPromise = UserDefaults.widgetGroup.string(forKey: "lastReadPromise") {
            
            markAsReadInCoreData(promise: readPromise)
            UserDefaults.widgetGroup.removeObject(forKey: "needsSyncReadStatus")
            UserDefaults.widgetGroup.removeObject(forKey: "lastReadPromise")
        }
    }
    
    private func updateFavoriteInCoreData(promise: String, isFavorited: Bool) {
        let context = PersistenceController.shared.container.viewContext
        let request: NSFetchRequest<AffirmationEntry> = AffirmationEntry.fetchRequest()
        request.predicate = NSPredicate(format: "text == %@", promise)
        
        do {
            let existingEntries = try context.fetch(request)
            
            if let existingEntry = existingEntries.first {
                existingEntry.isFavorite = isFavorited
                existingEntry.lastModified = Date()
                print("✅ Updated existing entry favorite status to:", isFavorited)
            } else if isFavorited {
                // Check if this promise exists in our full declaration set
                let allDeclarations = UserDefaults.widgetGroup.stringArray(forKey: "allDeclarations") ?? []
                if allDeclarations.contains(promise) {
                    // Only create new entry if marking as favorite and it's a valid declaration
                    let newEntry = AffirmationEntry(context: context)
                    newEntry.text = promise
                    newEntry.isFavorite = true
                    newEntry.createdAt = Date()
                    newEntry.lastModified = Date()
                    print("✅ Created new favorite entry for:", promise)
                } else {
                    print("⚠️ Promise not found in valid declarations, skipping:", promise)
                }
            }
            
            try context.save()
        } catch {
            print("Failed to update favorite in CoreData: \(error)")
        }
    }
    
    private func markAsReadInCoreData(promise: String) {
        let context = PersistenceController.shared.container.viewContext
        let request: NSFetchRequest<AffirmationEntry> = AffirmationEntry.fetchRequest()
        request.predicate = NSPredicate(format: "text == %@", promise)
        
        do {
            let existingEntries = try context.fetch(request)
            
            // Simplified - just track in UserDefaults for now
            // Would need to add read tracking properties to CoreData model
            print("Marking promise as read: \(promise)")
            
            try context.save()
        } catch {
            print("Failed to mark as read in CoreData: \(error)")
        }
    }
    
    /// Sync all data between widget and CoreData
    func syncAllData() {
        processPendingWidgetActions()
        syncFavoritesToWidget()
        syncReadStatusToWidget()
        
        // Ensure widget has some declarations to display
        syncFallbackDeclarations()
    }
    
    /// Sync basic declarations if none exist yet
    private func syncFallbackDeclarations() {
        // First test if App Groups is working
        let testKey = "appGroupsTest"
        let testValue = "test-\(Date().timeIntervalSince1970)"
        UserDefaults.widgetGroup.set(testValue, forKey: testKey)
        
        let readBack = UserDefaults.widgetGroup.string(forKey: testKey)
        print("RWRW- app: 🧪 App Groups Test - Wrote: \(testValue), Read back: \(readBack ?? "nil")")
        print("RWRW- app: 🧪 App Groups Suite Name: \(UserDefaults.widgetGroup)")
        
        let existingDeclarations = UserDefaults.widgetGroup.stringArray(forKey: "syncedPromises") ?? []
        
        // If no declarations are synced yet, provide a basic set
        if existingDeclarations.isEmpty {
            let fallbackDeclarations = [
                "Trust in the Lord with all your heart; do not depend on your own understanding.",
                "For I know the plans I have for you, says the Lord. They are plans for good and not for disaster, to give you a future and a hope.",
                "Don't worry about anything; instead, pray about everything. Tell God what you need, and thank him for all he has done.",
                "The Lord is for me, so I will have no fear. What can mere people do to me?",
                "I am leaving you with a gift—peace of mind and heart. And the peace I give is a gift the world cannot give. So don't be troubled or afraid.",
                "For God has not given us a spirit of fear and timidity, but of power, love, and self-discipline.",
                "Always be joyful. Never stop praying. Be thankful in all circumstances, for this is God's will for you who belong to Christ Jesus.",
                "Three things will last forever—faith, hope, and love—and the greatest of these is love.",
                "This is the day the Lord has made. We will rejoice and be glad in it.",
                "Don't be afraid, for I am with you. Don't be discouraged, for I am your God. I will strengthen you and help you. I will hold you up with my victorious right hand."
            ]
            
            print("RWRW- app: 🔄 WidgetDataBridge: Syncing fallback declarations to widget")
            UserDefaults.widgetGroup.set(fallbackDeclarations, forKey: "syncedPromises")
            UserDefaults.widgetGroup.set(fallbackDeclarations, forKey: "allDeclarations")
            
            // Refresh widgets
            WidgetCenter.shared.reloadTimelines(ofKind: "PromisesWidget")
            WidgetCenter.shared.reloadAllTimelines() // Force refresh all widgets
            print("RWRW- app: ✅ Fallback declarations synced and widget refreshed")
        } else {
            print("RWRW- app: ✅ Widget already has \(existingDeclarations.count) declarations")
        }
        
        // Debug: Also set a current promise to ensure widget shows something
        let testPromise = "Trust in the Lord with all your heart; do not depend on your own understanding."
        UserDefaults.widgetGroup.set(testPromise, forKey: "currentWidgetPromise")
        UserDefaults.widgetGroup.set(Date(), forKey: "lastWidgetUpdate")
        print("RWRW- app: 🔧 Debug: Force set test promise for widget at \(Date())")
        
        // Debug: Check what widgets are available
        WidgetCenter.shared.getCurrentConfigurations { result in
            switch result {
            case .success(let widgets):
                print("RWRW- app: 🔧 Available widgets: \(widgets.count)")
                for widget in widgets {
                    print("RWRW- app:    - Widget: \(widget.kind), family: \(widget.family)")
                }
            case .failure(let error):
                print("RWRW- app: 🔧 Error getting widgets: \(error)")
            }
        }
    }
}

