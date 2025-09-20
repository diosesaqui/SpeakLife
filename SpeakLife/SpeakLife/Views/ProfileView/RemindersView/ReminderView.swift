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
                        VStack(alignment: .center, spacing: 16) {
                            Text("Set up your daily reminders to make your declarations fit your daily routine")
                                .foregroundColor(.white.opacity(0.8))
                                .font(.callout)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                                .padding(.top)

                            ForEach(reminderViewModel.reminderCellViewModel) { reminderVM in
                                ReminderCell(reminderVM, showConfirmation: $showConfirmation)
                                    .cornerRadius(16)
                                    .padding(.horizontal)
                            }
                            
                            // Checklist Notifications Section
                            ChecklistNotificationSettings(showConfirmation: $showConfirmation)
                                .cornerRadius(16)
                                .padding(.horizontal)
                                .padding(.top, 8)
                        }
                        .padding(.bottom)
                    }
                    .navigationTitle("Reminders")
                    .background(Gradients().speakLifeCYOCell)
                }
            }
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
            if declarationViewModel.selectedCategories.count == 0 {
                NotificationManager.shared.registerNotifications(count: appState.notificationCount,
                                                                 startTime: appState.startTimeIndex,
                                                                 endTime: appState.endTimeIndex,
                                                                 categories: nil)
                
            } else {
                NotificationManager.shared.registerNotifications(count: appState.notificationCount,
                                                                 startTime: appState.startTimeIndex,
                                                                 endTime: appState.endTimeIndex,
                                                                 categories: declarationViewModel.selectedCategories) {
            
                }
            }
            appState.lastNotificationSetDate = Date()
        } else {
            declarationViewModel.errorAlert.toggle()
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
        
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            guard (settings.authorizationStatus == .authorized) ||
                    (settings.authorizationStatus == .provisional) else {
                DispatchQueue.main.async {
                    appState.notificationEnabled = true
                    completion(true)
                }
                return
            }
            completion(false)
            return
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
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.black.opacity(colorScheme == .dark ? 0.7 : 0.85))
                    .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
            )
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .padding(.bottom, 40)
    }
}
