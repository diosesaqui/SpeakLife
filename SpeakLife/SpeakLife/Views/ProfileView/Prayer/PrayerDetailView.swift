//
//  PrayerDetailView.swift
//  SpeakLife
//
//  Created by Riccardo Washington on 4/10/23.
//

import SwiftUI

struct PrayerDetailView<InjectedView: View>: View {
    
    @Environment(\.colorScheme) var colorScheme
    let prayer: String
    var gradient: InjectedView
    let createYourOwn: Declaration?
    var isCreatedOwn = false
    var showConfetti = false

    init(prayer: String, showConfetti: Bool, @ViewBuilder content: () -> InjectedView) {
        self.prayer = prayer
        self.showConfetti = showConfetti
        self.gradient = content()
        self.createYourOwn = nil
    }
    
    init(declaration: Declaration, isCreatedOwn: Bool = false, @ViewBuilder content: () -> InjectedView) {
        self.createYourOwn = declaration
        self.isCreatedOwn = isCreatedOwn
        self.gradient = content()
        self.prayer = ""
    }
    
    var body: some View {
        content
            .background(gradient)
    }
    
    @ViewBuilder
    var content: some View {
        if isCreatedOwn {
            isCreatedOwnView
        } else {
            prayerView
        }
    }
    
    var isCreatedOwnView: some View {
        ScrollView {
            VStack {
                HStack {
                    Spacer()
                    Text(createYourOwn?.lastEdit?.toPrettyString() ?? "")
                        .font(Font.custom("AppleSDGothicNeo-Regular", size: 16, relativeTo: .caption))
                        .lineSpacing(4)
                        .padding(.horizontal, 32)
                        .foregroundColor(.white)
                }
                
                Spacer().frame(height: 20)
                
                Text(createYourOwn?.text ?? "")
                    .font(.system(size: 20, weight: .medium, design: .rounded))
                    .lineSpacing(4)
                    .padding(.horizontal, 32)
                    .foregroundColor(.white)
                    .frame(width: UIScreen.main.bounds.width)
                
                Spacer()
            }
        }
    }
    
    var prayerView: some View {
        
        ZStack {
            ScrollView {
                
                Text(prayer)
                    .font(Font.custom("AppleSDGothicNeo-Regular", size: 20, relativeTo: .body))
                    .lineSpacing(4)
                    .padding(.horizontal, 32)
                    .foregroundColor(.white)
                    .frame(width: UIScreen.main.bounds.width)
                
                Spacer()
            }
            if showConfetti {
                ConfettiView()
                    .edgesIgnoringSafeArea(.all)
            }
        }
    }
}

