//
//  DeclarationMenuButton.swift
//  SpeakLife
//
//  Created by Riccardo Washington on 9/18/24.
//

import SwiftUI

struct DeclarationMenuButton: View {
    var iconName: String
    var label: String
    var action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(alignment: .center) {
                Image(systemName: iconName)
                    .frame(width: 30, height: 30)
                    .foregroundStyle(.white.opacity(0.9))

                Text(label)
                    .font(Font.custom("AppleSDGothicNeo-Bold", size: 16, relativeTo: .title))
                    .foregroundStyle(.white)
            
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .cornerRadius(8)
        }
    }
}
