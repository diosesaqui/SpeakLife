//
//  ChecklistNotificationSettings.swift
//  SpeakLife
//
//  Settings view for the evening check-in push
//

import SwiftUI

/// On/off and time for the one evening push. `EnhancedStreakViewModel`
/// owns the push itself and reschedules it whenever these @AppStorage keys
/// change (it watches UserDefaults), so this view only writes the settings.
///
/// The old "Morning Motivation" row is gone: no notification ever read
/// `morningReminderEnabled`, so it was a switch wired to nothing.
struct ChecklistNotificationSettings: View {
    @EnvironmentObject var appState: AppState
    @Binding var showConfirmation: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Toggle(isOn: $appState.eveningCheckInEnabled) {
                Text("Evening Check-in")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            .toggleStyle(SwitchToggleStyle(tint: Constants.DAMidBlue))
            .onChange(of: appState.eveningCheckInEnabled) { _, enabled in
                // The evening push also requires the old master checklist
                // switch, which has no UI. Turning this on must actually
                // turn the push on.
                if enabled { appState.checklistNotificationsEnabled = true }
                AnalyticsService.shared.track("evening_checkin_toggled", parameters: ["enabled": enabled])
                triggerConfirmation()
            }

            Text("One push each evening. If today's burst isn't done yet, a reminder before your streak breaks. Once it's done, a call-out for your next unfinished task.")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))
                .fixedSize(horizontal: false, vertical: true)

            if appState.eveningCheckInEnabled {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Time:")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))

                    TimePickerCompact(
                        hour: $appState.eveningCheckInHour,
                        minute: $appState.eveningCheckInMinute,
                        onChange: triggerConfirmation
                    )
                }
                .padding(.top, DS.Spacing.xs)
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

    private func triggerConfirmation() {
        withAnimation {
            showConfirmation = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                showConfirmation = false
            }
        }
    }
}

struct TimePickerCompact: View {
    @Binding var hour: Int
    @Binding var minute: Int
    let onChange: () -> Void
    
    // Convert 24-hour to 12-hour format
    private var hour12: Int {
        if hour == 0 { return 12 }
        if hour > 12 { return hour - 12 }
        return hour
    }
    
    private var isAM: Bool {
        hour < 12
    }
    
    private func updateHour12(_ newHour: Int) {
        if isAM {
            hour = newHour == 12 ? 0 : newHour
        } else {
            hour = newHour == 12 ? 12 : newHour + 12
        }
    }
    
    private func updatePeriod(_ newIsAM: Bool) {
        if newIsAM != isAM {
            if newIsAM {
                // Switch to AM
                hour = hour >= 12 ? hour - 12 : hour
            } else {
                // Switch to PM
                hour = hour < 12 ? hour + 12 : hour
            }
        }
    }
    
    var body: some View {
        HStack(spacing: DS.Spacing.xs) {
            // Hour Picker
            VStack(spacing: DS.Spacing.xxs) {
                Text("Hour")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.6))
                
                Picker("Hour", selection: Binding(
                    get: { hour12 },
                    set: { updateHour12($0); onChange() }
                )) {
                    ForEach(1...12, id: \.self) { hour in
                        Text(String(hour))
                            .foregroundColor(.white)
                            .tag(hour)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .frame(width: 70)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.1))
                )
            }
            
            Text(":")
                .foregroundColor(.white)
                .font(.title2)
                .fontWeight(.semibold)
            
            // Minute Picker
            VStack(spacing: DS.Spacing.xxs) {
                Text("Minute")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.6))
                
                Picker("Minute", selection: $minute) {
                    ForEach([0, 15, 30, 45], id: \.self) { minute in
                        Text(String(format: "%02d", minute))
                            .foregroundColor(.white)
                            .tag(minute)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .frame(width: 70)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.1))
                )
                .onChange(of: minute) { onChange() }
            }
            
            // AM/PM Picker
            VStack(spacing: DS.Spacing.xxs) {
                Text("Period")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.6))
                
                Picker("AM/PM", selection: Binding(
                    get: { isAM },
                    set: { updatePeriod($0); onChange() }
                )) {
                    Text("AM")
                        .foregroundColor(.white)
                        .tag(true)
                    Text("PM")
                        .foregroundColor(.white)
                        .tag(false)
                }
                .pickerStyle(MenuPickerStyle())
                .frame(width: 70)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.1))
                )
            }
        }
        .padding(.horizontal, DS.Spacing.xs)
    }
}

#if DEBUG
struct ChecklistNotificationSettings_Previews: PreviewProvider {
    @State static var showConfirmation = false
    
    static var previews: some View {
        ChecklistNotificationSettings(showConfirmation: $showConfirmation)
            .environmentObject(AppState())
            .background(Color.black)
    }
}
#endif