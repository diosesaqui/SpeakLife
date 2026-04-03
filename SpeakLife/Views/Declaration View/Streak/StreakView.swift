//
//  StreakView.swift
//  SpeakLife
//
//  Created by Riccardo Washington on 3/17/24.
//

import SwiftUI
import Combine 

struct GoldBadgeView: View {
    @State private var animate = false
    @State private var isVisible = true

    var body: some View {
        ZStack {
            // Sparkle effect
            ForEach(0..<8) { i in
                Image(systemName: "star.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 10, height: 10)
                    .foregroundColor(.yellow)
                    .opacity(animate ? 0 : 1) // Start fully visible and fade out
                    .offset(y: animate ? -30 : -20) // Move the stars outward as they fade
                    .rotationEffect(Angle(degrees: Double(i) * 45))
                    .animation(.easeOut(duration: 1.0).delay(Double(i) * 0.1), value: animate) // Staggered animation for each star
            }

            Circle()
                .fill(LinearGradient(gradient: Gradient(colors: [Color.yellow, Color.orange]), startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 50, height: 50)
                .scaleEffect(animate ? 1 : 0)

            Image(systemName: "star.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 25, height: 25)
                .foregroundColor(.white)
        }
        .opacity(isVisible ? 1 : 0)
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) {
                animate = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                withAnimation {
                    isVisible = false
                }
            }
        }
    }
}

struct CountdownTimerView: View {
    var action: (() -> Void)?
    
    @ObservedObject var viewModel: TimerViewModel
    @EnvironmentObject var streakViewModel: StreakViewModel

    init(viewModel: TimerViewModel, action: (() -> Void)?) {
        self.viewModel = viewModel
        self.action = action
    }
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(lineWidth: 5)
                .opacity(0.3)
                .foregroundColor(Constants.DAMidBlue)
            
            Circle()
                .trim(from: 0, to: viewModel.progress(for: viewModel.timeRemaining))
                .stroke(style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .foregroundColor(Constants.DAMidBlue)
                .rotationEffect(Angle(degrees: -90))
                .animation(.easeInOut(duration: 2), value: viewModel.timeRemaining)
            
            Text(viewModel.timeString(time: viewModel.timeRemaining))
                .font(.caption)
                .foregroundColor(Color.white)
        }
        .frame(width: 50, height: 50)
        
       
        .onTapGesture {
            action?()
        }
    }
}


