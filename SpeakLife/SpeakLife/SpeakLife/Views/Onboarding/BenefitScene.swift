//
//  BenefitScene.swift
//  SpeakLife
//
//  Created by Riccardo Washington on 12/15/23.
//

import SwiftUI

struct TipSL: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let text: String
}

let onboardingTips = [
    TipSL(title: "", text: "Through our devotionals, we constantly tap into Jesus' grace, equipping us with a formidable strength that turns every challenge into a testimony of His victorious power in our lives.")]

struct BenefitScene: View {
    
    
    let size: CGSize
    let tips: [TipSL]
    var callBack: (() -> Void)
    
    
    var body: some View {
        
        ZStack {
            Image("declarationBackground")
                .resizable()
                .aspectRatio(contentMode: .fit)
            
            
            VStack {
                
                Image("bible")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                
                
                Text("Grow with Jesus")
                    .font(Font.custom("AppleSDGothicNeo-Regular", size: 40, relativeTo: .title))
                    .fontWeight(.semibold)
                    .foregroundColor(.black)
                
                Spacer().frame(height: 45)
                
                ForEach(Array(tips.enumerated()), id: \.element.id) { index, tip in
                    HStack(alignment: .center, spacing: 16) {
                        Image(systemName: "bolt.shield.fill")
                            .resizable()
                            .frame(width: 25, height: 30)
                            .foregroundColor(Constants.DAMidBlue)
                            .scaledToFill()
                        
                        Text(tip.text)
                            .font(Font.custom("AppleSDGothicNeo-Regular", size: 18, relativeTo: .body))
                            .foregroundColor(.black)
                        
                        Spacer()
                    }.padding(.horizontal)
                }
                
                Spacer()
                
                Button(action: callBack) {
                    HStack {
                        Text("Let's go!")
                            .font(.body)
                            .fontWeight(.medium)
                            .frame(width: size.width * 0.91 ,height: 50)
                    }.padding()
                }
                .frame(width: size.width * 0.87 ,height: 50)
                .background(Constants.DAMidBlue)
                
                .foregroundColor(.white)
                .cornerRadius(8)
                .shadow(color: Constants.DAMidBlue, radius: 8, x: 0, y: 10)
                
                Spacer()
                    .frame(width: 5, height: size.height * 0.07)
                
            }
        }
    }
}
