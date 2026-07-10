//
//  NotificationProcessor.swift
//  Dios Es Aqui
//
//  Created by Riccardo Washington on 2/23/22.
//

import Foundation

final class NotificationProcessor {
    
    private let service: APIService
    private var allDeclarations: [Declaration] = []
    private var allDeclarationsDict: [DeclarationCategory: [Declaration]] = [:]
    
    init(service: APIService)  {
        self.service = service
        getDeclarations()
        
    }
    
    struct NotificationData {
        let book: String
        let body: String
        let category: String
    }
    
    func getNotificationData(count: Int,
                             categories: [DeclarationCategory]? = nil,
                             completion: @escaping([NotificationData]) -> Void) {
        
//        DispatchQueue.global(qos: .userInitiated).sync {
//            getDeclarations()
            
            guard allDeclarations.count >= count else { 
                // Warning:  
                print("⚠️ NotificationProcessor: Insufficient declarations. Have: \(allDeclarations.count), Need: \(count)")
                // Try to load declarations synchronously if empty
                if allDeclarations.isEmpty {
                    // Warning: 
                    print("⚠️ NotificationProcessor: Declarations array is empty, attempting to reload")
                    getDeclarations()
                }
                completion([])
                return
            }
            
            print("✅ NotificationProcessor: Using \(allDeclarations.count) declarations for \(count) notifications")
            
            
            // get enough for the week
            //let newCount = count * 7
            
            var data = [NotificationData]()
            var categoryReminders: [Declaration] = []
            
            // Treat nil or empty category list the same — fall back to all declarations.
            let resolvedCategories = categories?.isEmpty == false ? categories : nil

            if resolvedCategories == nil {
                let shuffled = allDeclarations.shuffled()
                guard !shuffled.isEmpty else { return }
                // Use 0-based indexing (was 1...count which caused an off-by-one crash)
                for index in 0..<min(count, shuffled.count) {
                    let declaration = shuffled[index]
                    // Send the declaration text (not the Bible verse) as the notification body.
                    // The scripture reference (book) is kept as the subtitle for context.
                    let body = declaration.text
                    let book = declaration.book ?? ""
                    let notificationData = NotificationData(book: book, body: body, category: declaration.category.rawValue)
                    data.append(notificationData)
                }
            } else {
                let categoryList = resolvedCategories!
                let categoryCount = categoryList.count  // guaranteed > 0 by resolvedCategories check above

                // Distribute `count` slots evenly across categories using proper integer math.
                // baseSlots = floor(count / categoryCount) per category
                // remainder categories each get one extra slot (round-robin top-up).
                // Example: count=5, categories=3 → [2, 2, 1] instead of old [1, 1, 1].
                let baseSlots = count / categoryCount          // integer floor division
                let extraSlots = count % categoryCount         // first N categories get +1

                for (index, category) in categoryList.enumerated() {
                    let slots = baseSlots + (index < extraSlots ? 1 : 0)
                    guard slots > 0 else { continue }

                    let categoryDeclarations = allDeclarations.filter { $0.category == category }
                    guard !categoryDeclarations.isEmpty else { continue }

                    // Pick exactly `slots` items; repeat if the category has fewer.
                    let shuffled = categoryDeclarations.shuffled()
                    var picked: [Declaration] = []
                    while picked.count < slots {
                        let remaining = slots - picked.count
                        picked.append(contentsOf: shuffled.prefix(remaining))
                    }
                    categoryReminders.append(contentsOf: picked)
                }

                // Ensure we have at least some notifications
                if categoryReminders.isEmpty {
                    // Warning:
                    print("⚠️ NotificationProcessor: Selected categories \(categoryList.map { $0.rawValue }) matched no declarations — falling back to all categories")
                    let shuffled = allDeclarations.shuffled()
                    let fallbackCount = min(count, shuffled.count)
                    categoryReminders.append(contentsOf: shuffled.prefix(fallbackCount))
                }

                // Shuffle the assembled list so categories interleave instead of
                // appearing in blocks (fixes "same 1-2 categories every time" bug).
                let finalList = categoryReminders.shuffled()
                data = parse(finalList, count: min(count, finalList.count))
            }
            completion(data)
            return
       // }
        
    }
    
    private func getDeclarations() {
        service.declarations { declarations, error, _ in
            self.allDeclarations = declarations
        }
    }
    
    private func parse(_ categoryReminders: [Declaration], count: Int) -> [NotificationData] {
        var data = [NotificationData]()
        var localCount = 0
        
        while localCount < count  {
            let declaration = categoryReminders[localCount]
            // Send the declaration text (not the Bible verse) as the notification body.
            // The scripture reference (book) is kept as the subtitle for context.
            let body = declaration.text
            let book = declaration.book ?? ""
            let notificationData = NotificationData(book: book, body: body, category: declaration.category.rawValue)
            data.append(notificationData)
            localCount += 1
        }
        
        return data
        
    }
    
    private func fetchDeclarations(for category: DeclarationCategory, completion: @escaping(([Declaration]) -> Void)) {
        if let declarations = allDeclarationsDict[category] {
            completion(declarations)
            
        } else if category == .favorites {
            let faves = allDeclarations.filter { $0.isFavorite == true }
               completion(faves)
        }  else {
            let declarations = allDeclarations.filter { $0.category == category }
            allDeclarationsDict[category] = declarations
            completion(declarations)
        }
    }
}
