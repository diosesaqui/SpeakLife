//
//  PremiumHaptics.swift
//  SpeakLife
//
//  Premium haptic feedback system for enhanced user experience
//

import UIKit
import Foundation

final class PremiumHaptics {
    
    static let shared = PremiumHaptics()
    private init() {}
    
    // MARK: - Basic Haptics
    
    static func light() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
    
    static func medium() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
    
    static func heavy() {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
    }
    
    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
    
    static func warning() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }
    
    static func error() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }
    
    // MARK: - Custom Haptic Sequences
    
    /// Triple-tap success sequence: light → medium → heavy
    static func successSequence() {
        let light = UIImpactFeedbackGenerator(style: .light)
        let medium = UIImpactFeedbackGenerator(style: .medium)
        let heavy = UIImpactFeedbackGenerator(style: .heavy)
        
        light.impactOccurred()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            medium.impactOccurred()
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            heavy.impactOccurred()
        }
    }
    
    /// Heartbeat pattern: medium → pause → medium
    static func heartbeat() {
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            impact.impactOccurred()
        }
    }
    
    /// Gentle pulse for meditation/prayer
    static func prayerPulse() {
        let light = UIImpactFeedbackGenerator(style: .light)
        light.impactOccurred()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            light.impactOccurred()
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            light.impactOccurred()
        }
    }
    
    /// Building excitement: light → medium → heavy → heavy
    static func buildUp() {
        let generators = [
            UIImpactFeedbackGenerator(style: .light),
            UIImpactFeedbackGenerator(style: .medium),
            UIImpactFeedbackGenerator(style: .heavy),
            UIImpactFeedbackGenerator(style: .heavy)
        ]
        
        for (index, generator) in generators.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.08) {
                generator.impactOccurred()
            }
        }
    }
    
    /// Celebration burst: rapid medium taps
    static func celebrationBurst() {
        let medium = UIImpactFeedbackGenerator(style: .medium)
        
        for i in 0..<5 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.05) {
                medium.impactOccurred()
            }
        }
    }
    
    /// Gentle wave for peaceful moments
    static func peacefulWave() {
        let light = UIImpactFeedbackGenerator(style: .light)
        
        let delays: [Double] = [0, 0.1, 0.15, 0.25, 0.3, 0.4]
        for delay in delays {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                light.impactOccurred()
            }
        }
    }
    
    // MARK: - Streak-Specific Haptics
    
    static func streakHaptic(for day: Int) {
        switch day {
        case 1...6:
            light()
        case 7:
            heartbeat()
        case 14:
            successSequence()
        case 21:
            buildUp()
        case 30:
            celebrationBurst()
        case 50:
            celebrationBurst()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                celebrationBurst()
            }
        case 100:
            // Epic celebration
            celebrationBurst()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                celebrationBurst()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                successSequence()
            }
        default:
            if day % 50 == 0 {
                celebrationBurst()
            } else if day % 10 == 0 {
                successSequence()
            } else {
                medium()
            }
        }
    }
    
    // MARK: - Category-Specific Haptics
    
    static func categoryHaptic(for category: String) {
        switch category.lowercased() {
        case "faith", "grace", "praise":
            prayerPulse()
        case "love", "gratitude", "joy":
            heartbeat()
        case "peace", "rest":
            peacefulWave()
        case "strength", "confidence", "destiny":
            buildUp()
        case "fear", "anxiety":
            light() // Gentle, non-alarming
        default:
            medium()
        }
    }
    
    // MARK: - Action-Specific Haptics
    
    static func favoriteAdded() {
        heartbeat()
    }
    
    static func favoriteRemoved() {
        light()
    }
    
    static func affirmationCompleted() {
        successSequence()
    }
    
    static func dailyGoalCompleted() {
        celebrationBurst()
    }
    
    static func newRecordSet() {
        celebrationBurst()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            celebrationBurst()
        }
    }
    
    static func buttonPress() {
        light()
    }
    
    static func cardTap() {
        medium()
    }
    
    static func swipeAction() {
        light()
    }
    
    static func pullToRefresh() {
        light()
    }
    
    static func shakeGesture() {
        buildUp()
    }
    
    // MARK: - Time-Based Haptics
    
    static func morningGreeting() {
        peacefulWave()
    }
    
    static func eveningReflection() {
        prayerPulse()
    }
    
    static func midnightPrayer() {
        peacefulWave()
    }
    
    // MARK: - Special Occasion Haptics
    
    static func birthday() {
        celebrationBurst()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            celebrationBurst()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            celebrationBurst()
        }
    }
    
    static func holiday() {
        successSequence()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            celebrationBurst()
        }
    }
    
    static func newYear() {
        // Countdown-like haptics
        let heavy = UIImpactFeedbackGenerator(style: .heavy)
        for i in 0..<5 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.5) {
                heavy.impactOccurred()
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            celebrationBurst()
        }
    }
}

// MARK: - Haptic Settings

extension PremiumHaptics {
    
    private static var isHapticsEnabled: Bool {
        return UserDefaults.standard.bool(forKey: "hapticsEnabled") != false // Default to true
    }
    
    static func setHapticsEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: "hapticsEnabled")
    }
    
    /// Safe haptic execution - only fires if haptics are enabled
    private static func executeHaptic(_ hapticBlock: @escaping () -> Void) {
        guard isHapticsEnabled else { return }
        hapticBlock()
    }
    
    // Update all public methods to use safe execution
    static func safeLight() {
        executeHaptic { light() }
    }
    
    static func safeMedium() {
        executeHaptic { medium() }
    }
    
    static func safeHeavy() {
        executeHaptic { heavy() }
    }
    
    static func safeSuccess() {
        executeHaptic { success() }
    }

    static func safeWarning() {
        executeHaptic { warning() }
    }
    
    static func safeSuccessSequence() {
        executeHaptic { successSequence() }
    }
    
    static func safeHeartbeat() {
        executeHaptic { heartbeat() }
    }
    
    static func safeCelebrationBurst() {
        executeHaptic { celebrationBurst() }
    }
}