//
//  Gradients.swift
//  SpeakLife
//
//  Created by Riccardo Washington on 4/30/23.
//

import SwiftUI

struct Gradients {
    
    let colors: [Color] = [.cyan, .purple,.pink, .indigo, .teal, Constants.DAMidBlue]
    
    func randomColors() -> [Color] {
            let shuffledColors = colors.shuffled()
            let array = Array(shuffledColors.prefix(3))
            return array
        }
    
    func randomColor() -> Color {
        let shuffledColors = colors.shuffled()
        return shuffledColors.first!
    }
    
    var purple: some View {
        LinearGradient(gradient: Gradient(colors: [.purple, .cyan]), startPoint: .topLeading, endPoint: .bottomTrailing)
            .edgesIgnoringSafeArea(.all)
    }
    var midBlue: some View {
        LinearGradient(gradient: Gradient(colors: [Constants.DAMidBlue, .black]), startPoint: .top, endPoint: .bottom)
            .edgesIgnoringSafeArea(.all)
    }
    var cyanBlue: some View {
        LinearGradient(gradient: Gradient(colors: [.cyan, .black]), startPoint: .top, endPoint: .bottom)
            .edgesIgnoringSafeArea(.all)
    }
    var cyanWhite: some View {
        LinearGradient(gradient: Gradient(colors: [.cyan, .white]), startPoint: .top, endPoint: .bottom)
            .edgesIgnoringSafeArea(.all)
    }
    
    var trio: some View {
        LinearGradient(gradient: Gradient(colors: [.purple, .cyan, .red]), startPoint: .topLeading, endPoint: .bottomTrailing)
            .edgesIgnoringSafeArea(.all)
    }
    
    var redPurple: some View {
        LinearGradient(gradient: Gradient(colors: [.purple, .red]), startPoint: .topLeading, endPoint: .bottomTrailing)
            .edgesIgnoringSafeArea(.all)
    }
    
    var redCyan: some View {
        LinearGradient(gradient: Gradient(colors: [ .cyan, .red]), startPoint: .topLeading, endPoint: .bottomTrailing)
            .edgesIgnoringSafeArea(.all)
    }
    
    var cyan: some View { LinearGradient(gradient: Gradient(colors: [.cyan, .white]), startPoint: .topLeading, endPoint: .bottomTrailing)
            .edgesIgnoringSafeArea(.all)
    }
    
    var cyanPurple: some View { LinearGradient(gradient: Gradient(colors: [.cyan, .purple, .cyan]), startPoint: .topLeading, endPoint: .bottomTrailing)
            .edgesIgnoringSafeArea(.all)
    }
    
    var cyanGold: some View { LinearGradient(gradient: Gradient(colors: [.cyan, Constants.gold]), startPoint: .topLeading, endPoint: .bottomTrailing)
            .edgesIgnoringSafeArea(.all)
    }
    
    var goldCyan: some View { LinearGradient(gradient: Gradient(colors: [Constants.gold, .cyan]), startPoint: .topLeading, endPoint: .bottomTrailing)
            .edgesIgnoringSafeArea(.all)
    }
    
    var randomGradient: some View { LinearGradient(gradient: Gradient(colors: [randomColor(), .black]), startPoint: .top, endPoint: .bottom)
            .edgesIgnoringSafeArea(.all)
    }
    
    var clearGradient: some View { LinearGradient(gradient: Gradient(colors: [.clear, .black]), startPoint: .top, endPoint: .bottom)
            .edgesIgnoringSafeArea(.all)
    }
    
    
    
    var random: some View { LinearGradient(gradient: Gradient(colors: randomColors()), startPoint: .topLeading, endPoint: .bottomTrailing)
            .edgesIgnoringSafeArea(.all)
    }
    
    var speakLifeBlueCell: some View { LinearGradient(colors: [Color(hex: "#1A264D").opacity(0.5), Color(hex: "#1e3c72").opacity(0.5)],
                                                      startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    
    var speakLifeBlackCell: some View { LinearGradient(colors: [Color.black.opacity(0.4), Color(hex: "#1c1c1e").opacity(0.4)],
                                                       startPoint: .topLeading, endPoint: .bottomTrailing).edgesIgnoringSafeArea(.all)
    }
    
    var speakLifeCYOCell: some View { LinearGradient(colors: [Color(#colorLiteral(red: 0.1, green: 0.15, blue: 0.3, alpha: 1)), Color(#colorLiteral(red: 0.02, green: 0.07, blue: 0.15, alpha: 1))],
                                                       startPoint: .top, endPoint: .bottom).edgesIgnoringSafeArea(.all)
    }
}
extension Gradients {
    var speakLifeFrostyCell: some View {
        LinearGradient(
            colors: [
                Color(hex: "#0B0F1A"), // deep navy
                Color(hex: "#1A2B3C"),
                Color(hex: "#1e3c72")  // frosted blue tone
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
}


