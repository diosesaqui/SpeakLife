//
//  ShimmerButton.swift
//  SpeakLife
//
//  Created by Riccardo Washington on 4/29/23.
//

import SwiftUI

//struct ShimmerButton: View {
//    let colors: [Color]
//    let buttonTitle: String
//    var textColor: Color = .white
//    let action: () -> Void
//    
//    @State private var animationOffset: CGFloat = -UIScreen.main.bounds.width
//    @State private var pulsate = false
//   
//
//    var body: some View {
//        Button(action: action) {
//            Text(buttonTitle)
//                .font(.system(size: 18, weight: .semibold, design: .rounded))
//                .foregroundColor(textColor)
//                .frame(maxWidth: .infinity, minHeight: 60) // Ensures the button takes up the entire width and has a minimum height of 50
//                .background(LinearGradient(gradient: Gradient(colors: colors), startPoint: .leading, endPoint: .trailing))
//                .cornerRadius(30)
//                .shadow(color: textColor.opacity(0.5),
//                        radius: pulsate ? 14 : 6)
//                .scaleEffect(pulsate ? 1.03 : 1.0)
//
//        }
//        .onAppear {
//                    // Start the breathing pulse immediately
//                    pulsate = true
//                }
//    }
//}

struct ShimmerButton: View {
    let colors: [Color]
    let buttonTitle: String
    var textColor: Color = .white
    let action: () -> Void
    
    @State private var animateRings = false
    
    var body: some View {
        ZStack {
            // 🔵 Pulsing Rounded Rectangle Rings
            ForEach(0..<3) { i in
                RoundedRectangle(cornerRadius: 30)
                    .stroke(colors.last!.opacity(0.4), lineWidth: 3)
                    .frame(height: 50) // Match button height
                    .padding(.horizontal) // Match button width
                    .scaleEffect(animateRings ? 1.4 : 1) // Expand outward
                    .opacity(animateRings ? 0 : 1)       // Fade as it grows
                    .animation(
                        Animation.easeOut(duration: 2)
                            .repeatForever()
                            .delay(Double(i) * 0.6),
                        value: animateRings
                    )
            }
            
            // 🎯 Main Button
            Button(action: {
                // Quick tap effect (optional)
                withAnimation(.easeOut(duration: 0.15)) {
                    animateRings = false
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    withAnimation {
                        animateRings = true
                    }
                }
                action()
            }) {
                Text(buttonTitle)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(textColor)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(
                        LinearGradient(gradient: Gradient(colors: colors),
                                       startPoint: .leading,
                                       endPoint: .trailing)
                    )
                    .cornerRadius(30)
                    .shadow(color: colors.last!.opacity(0.6), radius: 8)
            }
        }
        .onAppear {
            animateRings = true
        }
    }
}
