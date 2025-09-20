//
//  CompactStreakButton.swift
//  SpeakLife
//
//  Compact circular button that shows checklist progress
//

import SwiftUI

struct CompactStreakButton: View {
    @ObservedObject var viewModel: EnhancedStreakViewModel
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            ZStack {
                // Background circle with gradient
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 0.1, green: 0.15, blue: 0.3), Color(red: 0.02, green: 0.07, blue: 0.15)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 60, height: 60)
                
                // Progress ring
                Circle()
                    .stroke(Color.white.opacity(0.3), lineWidth: 3)
                    .frame(width: 52, height: 52)
                
                Circle()
                    .trim(from: 0, to: viewModel.todayChecklist.completionProgress)
                    .stroke(Color.white, lineWidth: 3)
                    .frame(width: 52, height: 52)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.5), value: viewModel.todayChecklist.completionProgress)
                
                // Center content
                if viewModel.todayChecklist.isCompleted {
                    // Fire icon with streak number
                    VStack(spacing: -2) {
                        Text("🔥")
                            .font(.system(size: 16))
                        Text("\(viewModel.streakStats.currentStreak)")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                    }
                } else {
                    // Sexy task count with dots indicator
                    VStack(spacing: 4) {
                        // Main count number
                        Text("\(viewModel.todayChecklist.completedTasksCount)")
                            .font(.system(size: 20, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                        
                        // Dots indicator instead of fraction
                        HStack(spacing: 3) {
                            ForEach(0..<viewModel.todayChecklist.tasks.count, id: \.self) { index in
                                Circle()
                                    .fill(index < viewModel.todayChecklist.completedTasksCount ? Color.white : Color.white.opacity(0.3))
                                    .frame(width: 4, height: 4)
                            }
                        }
                    }
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}