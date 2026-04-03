//
//  Reminder.swift
//  Dios Es Aqui
//
//  Created by Riccardo Washington on 2/16/22.
//

import Foundation

struct Reminder: Identifiable {
    var category: DeclarationCategory
    var reminderCount = 3
    var startTime: Date
    var endTime: Date
    var repeatDays: [Int] = []
    var sound: String?
    
    let id = UUID()
}
