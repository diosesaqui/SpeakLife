//
//  NotificationObserversModifier.swift
//  SpeakLife
//
//  ViewModifier to handle notification observers for DeclarationView
//

import SwiftUI

struct NotificationObserversModifier: ViewModifier {
    let timerViewModel: TimerViewModel
    
    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willTerminateNotification)) { _ in
                timerViewModel.saveRemainingTime()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                timerViewModel.loadRemainingTime()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
                // Save timer when app goes to background
                timerViewModel.saveRemainingTime()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                // Resume timer when app comes back to foreground
                if !timerViewModel.checkIfCompletedToday() && !timerViewModel.isActive {
                    timerViewModel.loadRemainingTime()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("StreakCompleted"))) { _ in
                // Force UI update when streak completes
                print("RWRW 🎉 Streak completed notification received - Current streak: \(timerViewModel.currentStreak)")
            }
    }
}

extension View {
    func setupNotificationObservers(timerViewModel: TimerViewModel) -> some View {
        modifier(NotificationObserversModifier(timerViewModel: timerViewModel))
    }
}