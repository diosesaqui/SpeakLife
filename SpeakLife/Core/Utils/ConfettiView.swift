//
//  ConfettiView.swift
//  SpeakLife
//
//  Created by Riccardo Washington on 3/12/24.
//

import SwiftUI

struct ConfettiView: View {
    @State private var animate = false
    
    var body: some View {
        ZStack {
            // Modern particle system using SwiftUI
            ForEach(0..<50, id: \.self) { index in
                ConfettiParticleConfetti(delay: Double(index) * 0.02)
            }
        }
        .onAppear {
            animate = true
        }
    }
}

struct ConfettiParticleConfetti: View {
    let delay: Double
    @State private var yPosition: CGFloat = -100
    @State private var xOffset: CGFloat = 0
    @State private var rotation: Double = 0
    @State private var opacity: Double = 1
    @State private var scale: CGFloat = 1
    
    private let colors: [Color] = [.blue, .purple, .pink, .orange, .yellow, .green]
    private let shapes: [String] = ["circle.fill", "diamond.fill", "star.fill", "heart.fill"]
    private let randomColor: Color
    private let randomShape: String
    private let randomXStart: CGFloat
    private let randomDuration: Double
    
    init(delay: Double) {
        self.delay = delay
        self.randomColor = colors.randomElement() ?? .blue
        self.randomShape = shapes.randomElement() ?? "circle.fill"
        self.randomXStart = CGFloat.random(in: -200...200)
        self.randomDuration = Double.random(in: 2.5...4.0)
    }
    
    var body: some View {
        Image(systemName: randomShape)
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(randomColor)
            .scaleEffect(scale)
            .rotationEffect(.degrees(rotation))
            .opacity(opacity)
            .offset(x: xOffset + randomXStart, y: yPosition)
            .onAppear {
                withAnimation(
                    .easeOut(duration: randomDuration)
                    .delay(delay)
                ) {
                    yPosition = UIScreen.main.bounds.height + 100
                    xOffset = CGFloat.random(in: -100...100)
                }
                
                withAnimation(
                    .linear(duration: randomDuration)
                    .delay(delay)
                ) {
                    rotation = Double.random(in: 360...720)
                }
                
                withAnimation(
                    .easeIn(duration: 0.5)
                    .delay(delay + randomDuration - 0.5)
                ) {
                    opacity = 0
                    scale = 0.5
                }
            }
    }
}

extension String {
    func image() -> UIImage {
         let size = CGSize(width: 40, height: 40) // Increase the size to ensure the emoji isn't cut off
         UIGraphicsBeginImageContextWithOptions(size, false, 0)
         UIColor.clear.set()
         let rect = CGRect(x: 5, y: 5, width: 30, height: 30) // Adjust drawing area within the context
         (self as NSString).draw(in: rect, withAttributes: [.font: UIFont.systemFont(ofSize: 30)]) // Ensure the emoji fits within the adjusted rect
         let image = UIGraphicsGetImageFromCurrentImageContext()!
         UIGraphicsEndImageContext()
         return image
     }
}
