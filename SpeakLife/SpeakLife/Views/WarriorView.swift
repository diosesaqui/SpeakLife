//
//  WarriorView.swift
//  SpeakLife
//
//  Created by Riccardo Washington on 12/24/23.
//

import SwiftUI

import FirebaseAnalytics

struct WarriorView: View {
    @Environment(\.dismiss) private var dismiss
    
    
    var body: some View {
        VStack {
            PrayerView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear {
            Event.trackScreen("warrior_screen", metadata: ["content": "prayer_view"])
        }
    }
}
