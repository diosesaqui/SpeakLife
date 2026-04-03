//
//  ReminderEditView.swift
//  Dios Es Aqui
//
//  Created by Riccardo Washington on 2/16/22.
//

import SwiftUI


struct ReminderEditView: View {
    
    var reminder: Reminder
    
    var body: some View {
        Text("\(reminder.reminderCount)")
    }
}
