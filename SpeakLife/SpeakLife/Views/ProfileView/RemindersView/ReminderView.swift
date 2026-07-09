//
//  ReminderView.swift
//  Dios Es Aqui
//
//  Created by Riccardo Washington on 2/3/22.
//

import SwiftUI
import BackgroundTasks
import FirebaseAnalytics

final class ReminderViewModel: ObservableObject {
    private let reminders: [Reminder] = [
        Reminder(category: .faith, reminderCount: 4, startTime: Date(), endTime: Date(), repeatDays: [], sound: nil)]
    var notificationsIsEnabled: Bool = false
    
    var reminderCellViewModel: [ReminderCellViewModel] {
        reminders.map { ReminderCellViewModel($0) }
    }
    
}
struct ReminderView: View {
    
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var declarationViewModel: DeclarationViewModel
    @State private var showAlert = false
    @State private var showConfirmation = false
   // @State private var showConfirmationToast = false
    
    let reminderViewModel: ReminderViewModel
    
    var body: some View {
            NavigationView {
                GeometryReader { geometry in
                    ScrollView {
                        VStack(alignment: .center, spacing: DS.Spacing.md) {
                            Text("Set up your daily reminders to make your declarations fit your daily routine")
                                .foregroundColor(.white.opacity(0.8))
                                .font(.callout)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                                .padding(.top)

                            ForEach(reminderViewModel.reminderCellViewModel) { reminderVM in
                                ReminderCell(reminderVM, showConfirmation: $showConfirmation)
                                    .cornerRadius(DS.Radius.md)
                                    .padding(.horizontal)
                            }
                            
//                            // Checklist Notifications Section
//                            ChecklistNotificationSettings(showConfirmation: $showConfirmation)
//                                .cornerRadius(16)
//                                .padding(.horizontal)
//                                .padding(.top, 8)
                        }
                        .padding(.bottom)
                    }
                    .navigationTitle("Reminders")
                    .background(Gradients().speakLifeCYOCell)
                }
            }
            .navigationViewStyle(.stack)
            .alert(isPresented: $showAlert) {
                Alert(
                    title: Text("Notifications are not enabled on this device"),
                    message: Text("Go to Settings"),
                    dismissButton: .default(Text("Settings"), action: goToSettings)
                )
            }
            .overlay(
                Group {
                    if showConfirmation {
                        VStack {
                            Spacer()
                                ToastView(message: "✅ Preferences saved")
                            }
                            .transition(.opacity)
                            .animation(.easeInOut(duration: 0.3), value: showConfirmation)
        
                        .padding()
                    }
                }
            )
            .onDisappear {
                registerNotifications()
            }
            .onAppear {
                Analytics.logEvent(Event.remindersTapped, parameters: nil)
                askNotificationPermission { showAlert in
                    self.showAlert = showAlert
                }
            }
        }

    
    private func registerNotifications() {
        if appState.notificationEnabled {
            // Source the topic selection from appState.selectedNotificationCategories —
            // the store that onboarding and the Notification Topics screen write.
            // declarationViewModel.selectedCategories is the FEED/widget selection:
            // onboarding never fills it and WidgetPreferencesView overwrites it, so
            // reading it here re-registered reminders with the generic 7-topic mix
            // (or widget picks) every time this screen closed, clobbering the
            // user's chosen notification topics.
            let parsed = Set(
                appState.selectedNotificationCategories
                    .components(separatedBy: ",")
                    .compactMap { DeclarationCategory($0) }
            )
            let categories: Set<DeclarationCategory>? = parsed.isEmpty ? nil : parsed
            NotificationManager.shared.registerNotifications(count: appState.notificationCount,
                                                             startTime: appState.startTimeIndex,
                                                             endTime: appState.endTimeIndex,
                                                             categories: categories)
            appState.lastNotificationSetDate = Date()
        }
    }
    private func scheduleNotificationRequest() {

        let eighteenHours = TimeInterval(18 * 60  * 60)

        let request = BGAppRefreshTaskRequest(identifier: "com.speaklife.updateNotificationContent")
        request.earliestBeginDate = Date(timeIntervalSinceNow: eighteenHours)
        
        
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("Could not schedule notification cleaning: \(error)")
        }
        
    }
    
    private func goToSettings(){
            DispatchQueue.main.async {
                UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!, options: [:],
                completionHandler: nil)
            }
    }
    
    private func askNotificationPermission(completion: @escaping(Bool) -> Void) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                let authorized = settings.authorizationStatus == .authorized
                    || settings.authorizationStatus == .provisional
                if authorized {
                    // OS permission is live — make sure the toggle reflects it
                    if !appState.notificationEnabled {
                        appState.notificationEnabled = true
                        DailyDeclarationReminderService.shared.isEnabled = true
                    }
                    completion(false) // no alert needed
                } else {
                    completion(true) // show "go to Settings" alert
                }
            }
        }
    }
}


struct ToastView: View {
    var message: String
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Text(message)
            .font(.system(size: 14, weight: .semibold, design: .rounded))
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, DS.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                    .fill(Color.black.opacity(colorScheme == .dark ? 0.7 : 0.85))
                    .dsShadow(DS.Elevation.low)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                    .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
            )
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .padding(.bottom, 40)
    }
}
