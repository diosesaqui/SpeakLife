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
    }
    
    func getNotificationData(count: Int,
                             categories: [DeclarationCategory]? = nil,
                             completion: @escaping([NotificationData]) -> Void) {
        
//        DispatchQueue.global(qos: .userInitiated).sync {
//            getDeclarations()
            
            guard allDeclarations.count >= count else { 
                completion([])
                return
            }
            
            
            // get enough for the week
            //let newCount = count * 7
            
            var data = [NotificationData]()
            var categoryReminders: [Declaration] = []
            
            if categories == nil  {
                let shuffled = allDeclarations.shuffled()
                guard !shuffled.isEmpty else { return }
                for number in 1...count {
                    let declaration = shuffled[number]
                    let notificationData = NotificationData(book: declaration.book ?? "", body: declaration.text)
                    data.append(notificationData)
                }
            } else {
                for category in categories! {
                    let categoryDeclarations = allDeclarations.filter { $0.category == category }
                   // fetchDeclarations(for: category) { declarations in
                        guard categoryDeclarations.count >= count else { completion([]); return }
                        let divisor = (count/categories!.count)
                        let endpoint = min(divisor, categoryDeclarations.count - 1)
                        let notificationCategories = categoryDeclarations.shuffled()[0...endpoint]
                        categoryReminders.append(contentsOf: notificationCategories)
                 //   }
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
            let notificationData = NotificationData(book: declaration.book ?? "", body: declaration.text)
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
