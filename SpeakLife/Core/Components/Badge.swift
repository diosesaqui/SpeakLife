//
//  Badge.swift
//  SpeakLife
//
//  Created by Riccardo Washington on 4/29/23.
//

import SwiftUI

struct NewCategoriesBadge: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.red)
                .frame(width: 35, height: 35)
            Text("New")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
        }
    }
}

struct Badge_Previews: PreviewProvider {
    static var previews: some View {
        NewCategoriesBadge()
    }
}
