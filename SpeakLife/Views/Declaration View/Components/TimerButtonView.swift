//
//  TimerButtonView.swift
//  SpeakLife
//
//  Extracted timer button component for DeclarationView
//

import SwiftUI

struct TimerButtonView: View {
    @ObservedObject var timerViewModel: TimerViewModel
    let action: () -> Void
    
    var body: some View {
        VStack(spacing: 4) {
            Button(action: action) {
                ZStack {
                    // Background circle
                    Circle()
                        .fill(Color.black.opacity(0.7))
                        .frame(width: 50, height: 50)
                    
                    // Progress ring
                    Circle()
                        .trim(from: 0, to: timerViewModel.progress(for: timerViewModel.timeRemaining))
                        .stroke(
                            Color.orange,
                            style: StrokeStyle(lineWidth: 3, lineCap: .round)
                        )
                        .frame(width: 50, height: 50)
                        .rotationEffect(Angle(degrees: -90))
                        .animation(.easeInOut(duration: 0.5), value: timerViewModel.timeRemaining)
                    
                    // Timer text or play icon
                    if timerViewModel.timeRemaining > 0 {
                        Text(timerViewModel.timeString(time: timerViewModel.timeRemaining))
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                            .shadow(color: .black, radius: 1, x: 0, y: 1)
                    } else {
                        Image(systemName: "play.fill")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.orange)
                    }
                }
            }
            
            Text("Meditate")
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.white)
                .shadow(color: .black, radius: 1, x: 0, y: 1)
        }
    }
}