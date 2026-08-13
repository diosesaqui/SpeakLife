//
//  NotificationManager.swift
//  SpeakLife (app target)
//
//  The `NotificationManager` class itself moved into SpeakLifeServices
//  so the scheduling logic can build in the Foundation-only package.
//  What stayed here is `UpdateNotificationsOperation`, because it
//  reaches straight into the app's `AppState` and there was no reason
//  to route that through a seam.
//

import Foundation

final class UpdateNotificationsOperation: Operation {

    private let appState: AppState

    init(appState: AppState) {
        self.appState = appState
    }

    override func start() {
        let categories = appState.selectedNotificationCategories.components(separatedBy: ",").compactMap({ DeclarationCategory($0) })
        let setCategories = Set(categories)
        // Respect the user's saved selection exactly — no implicit widening.
        let selectedCategories = setCategories.isEmpty ? nil : setCategories

        NotificationManager.shared.notificationsPending { [weak self] pending, count in

            guard let self = self else { return }

            if self.appState.notificationEnabled {
                self.appState.lastNotificationSetDate = Date()
                NotificationManager.shared.registerNotifications(count: self.appState.notificationCount,
                                                                 startTime: self.appState.startTimeIndex,
                                                                 endTime: self.appState.endTimeIndex,
                                                                 categories: selectedCategories)
                self.completionBlock?()

            }

        }
    }
}
