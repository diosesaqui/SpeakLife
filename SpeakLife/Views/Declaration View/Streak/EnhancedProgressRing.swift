//
//  EnhancedProgressRing.swift
//  SpeakLife
//
//  Enhanced progress ring that shows milestone progress clearly
//

import SwiftUI

struct EnhancedProgressRing: View {
    let progress: Double
    let currentStreak: Int
    let nextMilestone: Int
    let showSparkles: Bool
    
    private var previousMilestone: Int {
        let milestones = [0, 7, 14, 30, 50, 100, 200, 365]
        return milestones.last { $0 <= currentStreak } ?? 0
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Progress ring with center content
            ZStack {
                // Background circle
                Circle()
                    .stroke(lineWidth: 12)
                    .opacity(0.2)
                    .foregroundColor(.white)
                    .frame(width: 120, height: 120)

                // Progress circle
                Circle()
                    .trim(from: 0.0, to: progress)
                    .stroke(style: StrokeStyle(lineWidth: 12, lineCap: .round, lineJoin: .round))
                    .foregroundColor(.green)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 1.0), value: progress)
                    .frame(width: 120, height: 120)

                // Center content
                VStack(spacing: 2) {
                    if currentStreak == 0 {
                        // No streak yet
                        VStack(spacing: 4) {
                            Text("Start Your")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.8))
                            Text("Journey!")
                                .font(.caption.bold())
                                .foregroundColor(.white)
                        }
                    } else if currentStreak >= nextMilestone {
                        // Reached milestone
                        VStack(spacing: 4) {
                            Text("🏆")
                                .font(.title2)
                            Text("Milestone!")
                                .font(.caption.bold())
                                .foregroundColor(.white)
                        }
                    } else {
                        // Progress toward next milestone
                        VStack(spacing: 2) {
                            Text("\(currentStreak)")
                                .font(.title2.bold())
                                .foregroundColor(.white)
                            
                            Text("of \(nextMilestone)")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.8))
                            
                            Text("days")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                }

                // Sparkles for high progress
                if showSparkles {
                    Sparkles()
                }
            }
            
            // Milestone label properly positioned below ring
            if currentStreak > 0 && currentStreak < nextMilestone {
                Text("Next: \(getMilestoneName(nextMilestone))")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.7))
            } else if currentStreak >= nextMilestone {
                Text("\(getMilestoneName(currentStreak)) Achieved!")
                    .font(.caption2.bold())
                    .foregroundColor(.green)
            }
        }
    }
    
    private func getMilestoneName(_ days: Int) -> String {
        switch days {
        case 7:
            return "Faith Builder"
        case 14:
            return "Word Warrior"
        case 30:
            return "Faith Overcomer"
        case 50:
            return "Kingdom Heir"
        case 100:
            return "Covenant Keeper"
        case 200:
            return "Spiritual Giant"
        case 365:
            return "Destiny Carrier"
        default:
            return "\(days) Days"
        }
    }
}

struct Sparkles: View {
    var body: some View {
        ForEach(0..<10, id: \.self) { _ in
            Circle()
                .fill(Color.white.opacity(0.6))
                .frame(width: CGFloat.random(in: 2...5), height: CGFloat.random(in: 2...5))
                .position(x: CGFloat.random(in: 20...100), y: CGFloat.random(in: 20...100))
                .opacity(Double.random(in: 0.5...1.0))
                .animation(Animation.easeInOut(duration: Double.random(in: 0.6...1.2)).repeatForever(), value: UUID())
        }
    }
}

#if DEBUG
struct EnhancedProgressRing_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 40) {
            // No streak
            EnhancedProgressRing(progress: 0.0, currentStreak: 0, nextMilestone: 7, showSparkles: false)
                .previewDisplayName("No Streak")
            
            // Progress toward first week
            EnhancedProgressRing(progress: 0.57, currentStreak: 4, nextMilestone: 7, showSparkles: false)
                .previewDisplayName("4 of 7 Days")
            
            // High progress with sparkles
            EnhancedProgressRing(progress: 0.86, currentStreak: 6, nextMilestone: 7, showSparkles: true)
                .previewDisplayName("6 of 7 Days")
            
            // Milestone reached
            EnhancedProgressRing(progress: 1.0, currentStreak: 7, nextMilestone: 14, showSparkles: true)
                .previewDisplayName("Week Complete")
        }
        .padding()
        .background(Color.black)
    }
}
#endif