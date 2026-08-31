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
        VStack(alignment: .center, spacing: DS.Spacing.md) {
            Toggle(isOn: appState.$notificationEnabled) {
                Text("Daily Declaration Reminder")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            .toggleStyle(SwitchToggleStyle(tint: Constants.DAMidBlue))
            .onChange(of: appState.notificationEnabled) { enabled in
                DailyDeclarationReminderService.shared.isEnabled = enabled
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
                // Keep the personal declaration push aligned with the user's
                // window setting. The next app foreground re-schedules it via
                // rescheduleActivePersonalDeclarationIfNeeded using this value.
                appState.personalDeclarationTimeIndex = index
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
            RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                .fill(Color.white.opacity(0.05))
                .background(.ultraThinMaterial)
                .dsShadow(DS.Elevation.low)
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

// MARK: - Daily Burst

/// The Daily Burst rhythm control.
///
/// The burst is seven declarations spoken out loud, and it used to be invited
/// once a day. It is a habit, not an event — the more you speak, the more you
/// reap — so this is where the user sets how often they want to be called in:
/// three times a day out of the box, anywhere from one to four.
struct DailyBurstReminderSettings: View {
    @Binding var showConfirmation: Bool
    @ObservedObject private var burstService = DailyDeclarationReminderService.shared

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text("Daily Burst")
                        .font(.headline)
                        .foregroundColor(.white)

                    Text("We'll invite you in to speak your seven. The more you speak, the more you reap.")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()

                Toggle("", isOn: $burstService.isEnabled)
                    .labelsHidden()
                    .toggleStyle(SwitchToggleStyle(tint: Constants.DAMidBlue))
                    .onChange(of: burstService.isEnabled) { enabled in
                        AnalyticsService.shared.track("daily_burst_reminders_toggled", parameters: [
                            "enabled": enabled,
                            "bursts_per_day": burstService.burstsPerDay
                        ])
                        showToast()
                    }
            }

            if burstService.isEnabled {
                Divider()
                    .background(Color.white.opacity(0.2))

                BurstsPerDayStepper(value: burstService.burstsPerDay) { newValue in
                    burstService.burstsPerDay = newValue
                    // Tracked here rather than in the service's setter: the
                    // setter also runs when a count chosen on another device
                    // syncs down, and that is not a second user choosing.
                    AnalyticsService.shared.track("daily_burst_reminder_count_changed", parameters: [
                        "bursts_per_day": newValue
                    ])
                    showToast()
                }

                // The times are worth showing: they are not simply the hours the
                // user might expect, because each slot is nudged clear of their
                // own declaration reminders before it is scheduled.
                Text(scheduleSummary)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                .fill(Color.white.opacity(0.05))
                .background(.ultraThinMaterial)
                .dsShadow(DS.Elevation.low)
        )
    }

    private var scheduleSummary: String {
        let times = burstService.scheduledTimes.map(Self.format).joined(separator: " · ")
        return times.isEmpty ? "" : "Invitations at \(times)"
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter
    }()

    private static func format(_ time: (hour: Int, minute: Int)) -> String {
        var components = DateComponents()
        components.hour = time.hour
        components.minute = time.minute
        guard let date = Calendar.current.date(from: components) else {
            return String(format: "%02d:%02d", time.hour, time.minute)
        }
        return timeFormatter.string(from: date)
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

/// Stepper for bursts per day. Deliberately its own type rather than a reuse of
/// `StepperNotificationCountView`: that one is bound to a 1...30 range and reads
/// "Alerts per day", which is the content reminder batch, not this.
struct BurstsPerDayStepper: View {
    @State private var value: Int
    private let range = BurstReminderPlanner.allowedBurstsPerDay
    private let valueCount: (Int) -> Void

    init(value: Int, valueCount: @escaping (Int) -> Void) {
        self._value = State(initialValue: value)
        self.valueCount = valueCount
    }

    var body: some View {
        Stepper {
            HStack {
                Text("Bursts per day")
                    .foregroundColor(.white)
                Spacer()
                Text("\(value)X")
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                Spacer()
                    .frame(width: 5, height: 1)
            }
        } onIncrement: {
            guard value < range.upperBound else { return }
            value += 1
            valueCount(value)
        } onDecrement: {
            guard value > range.lowerBound else { return }
            value -= 1
            valueCount(value)
        }
        .accentColor(Constants.DALightBlue)
        .padding()
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Constants.DAMidBlue, lineWidth: 1)
        )
    }
}
