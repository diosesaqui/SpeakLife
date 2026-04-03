//
//  ReminderCell.swift
//  Dios Es Aqui
//
//  Created by Riccardo Washington on 2/16/22.
//

import SwiftUI

final class ReminderCellViewModel: ObservableObject,  Identifiable {
    let reminder: Reminder
    
    
    init(_ reminder: Reminder) {
        self.reminder = reminder
    }
}


struct ReminderCell: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appState: AppState
    @Binding var showConfirmation: Bool

    private let reminderVM: ReminderCellViewModel

    init(_ reminderVM: ReminderCellViewModel, showConfirmation: Binding<Bool>) {
        self.reminderVM = reminderVM
        self._showConfirmation = showConfirmation
    }

    var body: some View {
        VStack(alignment: .center, spacing: 16) {
            Toggle(isOn: appState.$notificationEnabled) {
                Text("Daily Declaration Reminder")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            .toggleStyle(SwitchToggleStyle(tint: Constants.DAMidBlue))
            .onChange(of: appState.notificationEnabled) { _ in
                showToast()
            }

            StepperNotificationCountView(appState.notificationCount) { newValue in
                appState.notificationCount = newValue
                showToast()
            }

            TimeNotificationCountView(value: appState.startTimeIndex) {
                Text("Start Time")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.9))
            } valueTime: { newTime in
                appState.startTimeNotification = newTime
                showToast()
            } valueIndex: { index in
                appState.startTimeIndex = index
                showToast()
            }

            TimeNotificationCountView(value: appState.endTimeIndex) {
                Text("End Time")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.9))
            } valueTime: { newTime in
                appState.endTimeNotification = newTime
                showToast()
            } valueIndex: { index in
                appState.endTimeIndex = index
                showToast()
            }

            CategoryButtonRow(showConfirmation: $showConfirmation)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.05))
                .background(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 6)
        )
    }

    private func showToast() {
        withAnimation {
            showConfirmation = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation {
                showConfirmation = false
            }
        }
    }
}
