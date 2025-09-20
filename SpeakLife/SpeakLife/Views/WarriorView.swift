//
//  WarriorView.swift
//  SpeakLife
//
//  Created by Riccardo Washington on 12/24/23.
//

import SwiftUI

import FirebaseAnalytics

struct WarriorView: View {
    @Environment(\.presentationMode) var presentationMode
    
    
    var body: some View {
        VStack {
            PrayerView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
