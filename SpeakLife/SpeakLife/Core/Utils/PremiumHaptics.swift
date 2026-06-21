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

    // Persistent, reusable generators. Creating a fresh generator per call and
    // firing immediately leaves the Taptic Engine cold, so single taps are
    // routinely dropped or feel weak (only multi-impact patterns registered).
    // Keeping prepared instances alive makes every impact land.
    private static let lightGen = UIImpactFeedbackGenerator(style: .light)
    private static let mediumGen = UIImpactFeedbackGenerator(style: .medium)
    private static let heavyGen = UIImpactFeedbackGenerator(style: .heavy)
    private static let notificationGen = UINotificationFeedbackGenerator()

    /// Warm the Taptic Engine ahead of interactions. Safe to call often
    /// (e.g. once on app launch and on tab changes).
    static func prepare() {
        lightGen.prepare()
        mediumGen.prepare()
        heavyGen.prepare()
        notificationGen.prepare()
    }

    // MARK: - Basic Haptics

    static func light() {
        lightGen.prepare()
        lightGen.impactOccurred()
    }

    static func medium() {
        mediumGen.prepare()
        mediumGen.impactOccurred()
    }

    static func heavy() {
        heavyGen.prepare()
        heavyGen.impactOccurred()
    }

    static func success() {
        notificationGen.prepare()
        notificationGen.notificationOccurred(.success)
    }

    static func warning() {
        notificationGen.prepare()
        notificationGen.notificationOccurred(.warning)
    }

    static func error() {
        notificationGen.prepare()
        notificationGen.notificationOccurred(.error)
    }
    
    // MARK: - Custom Haptic Sequences
    
    /// Triple-tap success sequence: light → medium → heavy
    static func successSequence() {
        light()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { medium() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { heavy() }
    }

    /// Heartbeat pattern: medium → pause → medium
    static func heartbeat() {
        medium()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { medium() }
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
        for i in 0..<5 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.05) {
                medium()
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
        // Default to true when the key was never set. `bool(forKey:)` returns
        // false for a missing key, so the old `!= false` check wrongly disabled
        // haptics for everyone (no setting ever writes this key). Read the raw
        // object instead so an unset key means "on".
        UserDefaults.standard.object(forKey: "hapticsEnabled") as? Bool ?? true
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