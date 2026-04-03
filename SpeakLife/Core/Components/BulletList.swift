//
//  BulletList.swift
//  SpeakLife
//
//  Created by Riccardo Washington on 4/30/23.
//

import SwiftUI

struct BulletList: View {
    let items: [String]
    
    var body: some View {
        VStack {
            ForEach(items, id: \.self) { item in
                HStack(spacing: 10) {
                    Image(systemName: "circle.fill")
                        .resizable()
                        .frame(width: 12, height: 12)
                        .foregroundColor(.blue)
                    Text(item)
                        .font(.body)
                        .foregroundColor(.black)
                    Spacer()
                }
                .padding()
            }
        }
    }
}

struct Bulletlist_Previews: PreviewProvider {
    
    static var previews: some View {
        BulletList(items: ["Hey",  "Bye", "Hmm"])
    }
    
    
}
