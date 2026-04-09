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
            
            if categories == nil  {
                let shuffled = allDeclarations.shuffled()
                guard !shuffled.isEmpty else { return }
                for number in 1...count {
                    let declaration = shuffled[number]
                    // Send the declaration text (not the Bible verse) as the notification body.
                    // The scripture reference (book) is kept as the subtitle for context.
                    let body = declaration.text
                    let book = declaration.book ?? ""
                    let notificationData = NotificationData(book: book, body: body, category: declaration.category.rawValue)
                    data.append(notificationData)
                }
            } else {
                for category in categories! {
                    let categoryDeclarations = allDeclarations.filter { $0.category == category }
                   // fetchDeclarations(for: category) { declarations in
                        // Don't fail if category has fewer declarations, just use what's available
                        guard !categoryDeclarations.isEmpty else { continue }
                        
                        let divisor = max(1, count/categories!.count)
                        // Use all available declarations if needed, allowing repeats
                        let availableCount = categoryDeclarations.count
                        
                        if availableCount >= divisor {
                            // We have enough declarations, pick without replacement
                            let endpoint = min(divisor, categoryDeclarations.count - 1)
                            let notificationCategories = categoryDeclarations.shuffled()[0...endpoint]
                            categoryReminders.append(contentsOf: notificationCategories)
                        } else {
                            // Not enough declarations, use all available and allow repeats if needed
                            let shuffled = categoryDeclarations.shuffled()
                            categoryReminders.append(contentsOf: shuffled)
                            
                            // If we still need more, repeat some declarations
                            var remaining = divisor - availableCount
                            while remaining > 0 && !shuffled.isEmpty {
                                let toAdd = min(remaining, shuffled.count)
                                categoryReminders.append(contentsOf: shuffled.prefix(toAdd))
                                remaining -= toAdd
                            }
                        }
                 //   }
                }
                
                // Ensure we have at least some notifications
                if categoryReminders.isEmpty {
                    // Fall back to using all categories if selected ones are empty
                    let shuffled = allDeclarations.shuffled()
                    let fallbackCount = min(count, shuffled.count)
                    for i in 0..<fallbackCount {
                        categoryReminders.append(shuffled[i])
                    }
                }
                
                if categoryReminders.count >= count {
                    data = parse(categoryReminders, count: count)
                }  else {
                    data = parse(categoryReminders, count: categoryReminders.count)
                }
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
