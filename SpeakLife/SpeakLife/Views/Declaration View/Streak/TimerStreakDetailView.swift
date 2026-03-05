//
//  TimerStreakDetailView.swift
//  SpeakLife
//
//  Created by SpeakLife Team
//

import SwiftUI

struct TimerStreakDetailView: View {
    @ObservedObject var timerViewModel: TimerViewModel
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Streak Stats
                    VStack(spacing: 16) {
                        HStack(spacing: 30) {
                        StatBox(
                            title: "Current Streak",
                            value: "\(timerViewModel.currentStreak)",
                            icon: "flame.fill",
                            color: .orange
                        )
                        
                        StatBox(
                            title: "Best Streak",
                            value: "\(timerViewModel.longestStreak)",
                            icon: "trophy.fill",
                            color: .yellow
                        )
                    }
                    
                    StatBox(
                        title: "Total Days",
                        value: "\(timerViewModel.totalDaysCompleted)",
                        icon: "calendar",
                        color: .blue
                    )
                    .frame(maxWidth: 150)
                }
                .padding(.top, 10)
                
                Divider()
                
                // Timer Section
                VStack(spacing: 16) {
                    
                    Text("Speak Life Daily")
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)

                    Text("Practice God's presence and speak His Word—He promised to never leave you.")
                        .foregroundColor(.white.opacity(0.85))
                        .font(.system(size: 14, weight: .regular))
                        .multilineTextAlignment(.center)
                        .lineSpacing(2)
                        .padding(.horizontal, 24)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    
                    if timerViewModel.checkIfCompletedToday() {
                        VStack(spacing: 10) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.green)
                            
                            Text("Completed!")
                                .font(.title2.bold())
                                .foregroundColor(.green)
                            
                            Text("Great job! See you tomorrow")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                    } else {
                        ZStack {
                            // Background Circle
                            Circle()
                                .stroke(lineWidth: 8)
                                .opacity(0.1)
                                .foregroundColor(Constants.DAMidBlue)
                            
                            // Progress Circle
                            Circle()
                                .trim(from: 0, to: timerViewModel.progress(for: timerViewModel.timeRemaining))
                                .stroke(style: StrokeStyle(lineWidth: 8, lineCap: .round))
                                .foregroundColor(Constants.DAMidBlue)
                                .rotationEffect(Angle(degrees: -90))
                                .animation(.easeInOut(duration: 0.5), value: timerViewModel.timeRemaining)
                            
                            VStack(spacing: 4) {
                                Text(timerViewModel.timeString(time: timerViewModel.timeRemaining))
                                    .font(.system(size: 32, weight: .bold, design: .monospaced))
                                    .foregroundColor(.primary)
                                
                                Text("minutes remaining")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .frame(width: 180, height: 180)
                        
                        // Auto-start timer if not active
                        .onAppear {
                            if !timerViewModel.isActive {
                                timerViewModel.loadRemainingTime()
                            }
                        }
                    }
                }
                
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            .navigationTitle("Streak Progress")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .navigationViewStyle(.stack)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(UIColor.systemBackground),
                    Constants.DAMidBlue.opacity(0.05)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .onAppear {
            if !timerViewModel.isActive && !timerViewModel.checkIfCompletedToday() {
                timerViewModel.loadRemainingTime()
            }
        }
        // Timer continues when sheet is dismissed - no need to save
    }
}

struct StatBox: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .medium))
                .foregroundColor(color)
            
            Text(value)
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
            
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(UIColor.secondarySystemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        )
    }
}

#Preview {
    TimerStreakDetailView(timerViewModel: TimerViewModel())
}
