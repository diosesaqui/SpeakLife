//
//  WhatsNewView.swift
//  SpeakLife
//
//  Created by Riccardo Washington on 12/31/24.
//

import SwiftUI

struct WhatsNewBottomSheet: View {
    @Binding var isPresented: Bool
    let version: String
    let features = [
        "UX fixes"
    ]

    var body: some View {
           VStack(spacing: 20) {
               // Header Section
               VStack(spacing: 10) {
                   Text("What's New in \(version)")
                       .font(.title)
                       .fontWeight(.bold)
                       .multilineTextAlignment(.center)

                   Text("Discover the latest features and enhancements designed to inspire and uplift your experience.")
                       .font(.body)
                       .multilineTextAlignment(.center)
                       .foregroundColor(.secondary)
                       .padding(.horizontal, 20)
               }
               .padding(.top, 20)

               // Features Section
               ScrollView {
                   VStack(alignment: .leading, spacing: 15) {
                       ForEach(features, id: \.self) { feature in
                           HStack(alignment: .top, spacing: 10) {
                               Image(systemName: "checkmark.circle.fill")
                                   .foregroundColor(.blue)
                                   .font(.system(size: 20))

                               Text(feature)
                                   .font(.body)
                                   .foregroundColor(.primary)
                           }
                           .padding(.horizontal, 20)
                       }
                   }
               }

               // Dismiss Button
               Button(action: {
                   isPresented = false
               }) {
                   Text("Get Started")
                       .fontWeight(.bold)
                       .frame(maxWidth: .infinity)
                       .padding()
                       .background(LinearGradient(
                           gradient: Gradient(colors: [Color.blue, Color.purple]),
                           startPoint: .leading,
                           endPoint: .trailing
                       ))
                       .foregroundColor(.white)
                       .cornerRadius(10)
                       .padding(.horizontal, 20)
               }
               .padding(.bottom, 20)
           }
           .background(
               RoundedRectangle(cornerRadius: 20)
                   .fill(Color(.systemBackground))
                   .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: -5)
           )
           .ignoresSafeArea(edges: .bottom)
       }
}
