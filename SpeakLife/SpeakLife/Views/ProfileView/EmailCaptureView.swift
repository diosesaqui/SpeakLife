//
//  EmailCaptureView.swift
//  SpeakLife
//
//  Created by Riccardo Washington on 6/27/25.
//

import SwiftUI
import FirebaseFirestore
import FirebaseAnalytics

struct EmailCaptureView: View {
    @EnvironmentObject var appState: AppState
    @State private var email: String = ""
    @State private var message: String?
    @State private var isSubmitting: Bool = false
    @State private var showSuccess: Bool = false
    @State private var showAdvancedOptions: Bool = false
    @State private var messageType: MessageType = .info
    
    private let emailService = EmailMarketingService.shared
    private let submissionTimeout: TimeInterval = 10.0
    
    enum MessageType {
        case info, success, error
    }
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Join Our Weekly Emails")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Be the first to receive weekly encouragement, Scripture insights, and app updates.")
                .font(.body)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            TextField("Enter your email", text: $email)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(10)
                .autocapitalization(.none)
            
            Button(action: submitEmail) {
                if isSubmitting {
                    ProgressView()
                } else {
                    Text("Subscribe")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isFormValid ? Color.blue : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
            }
            .disabled(isSubmitting || email.isEmpty)
            
            
            if let message = message {
                HStack {
                    Image(systemName: messageIcon)
                        .foregroundColor(messageColor)
                    Text(message)
                        .foregroundColor(messageColor)
                }
                .font(.footnote)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(messageColor.opacity(0.1))
                .cornerRadius(8)
            }
            if showSuccess {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.green)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .padding()
        .animation(.easeInOut, value: showSuccess)
    }
    
    private var isFormValid: Bool {
        !email.isEmpty && isValidEmail(email)
    }
    
    private var messageColor: Color {
        switch messageType {
        case .info: return .blue
        case .success: return .green
        case .error: return .red
        }
    }
    
    private var messageIcon: String {
        switch messageType {
        case .info: return "info.circle.fill"
        case .success: return "checkmark.circle.fill"
        case .error: return "exclamationmark.triangle.fill"
        }
    }
    
    private func submitEmail() {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Provide specific error messages
        if trimmedEmail.isEmpty {
            showMessage("Please enter your email address", type: .error)
            return
        }
        
        if !trimmedEmail.contains("@") {
            showMessage("Email must include @ symbol", type: .error)
            return
        }
        
        if trimmedEmail.filter({ $0 == "@" }).count > 1 {
            showMessage("Email can only have one @ symbol", type: .error)
            return
        }
        
        if !trimmedEmail.contains(".") || trimmedEmail.hasSuffix(".") {
            showMessage("Please include a valid domain (e.g., gmail.com)", type: .error)
            return
        }
        
        guard isValidEmail(trimmedEmail) else {
            showMessage("Please enter a valid email address (e.g., name@example.com)", type: .error)
            Analytics.logEvent("email_signup_invalid", parameters: [
                "source": "ios_app_profile"
            ])
            return
        }
        
        isSubmitting = true
        message = nil
        showSuccess = false
        
        // Log attempt
        Analytics.logEvent("email_signup_attempt", parameters: [
            "source": "ios_app_profile"
        ])
        
        // Set a timeout timer
        let timeoutTask = DispatchWorkItem {
            if self.isSubmitting {
                self.showMessage("Taking too long... Please check your connection and try again.", type: .error)
                self.isSubmitting = false
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + submissionTimeout, execute: timeoutTask)
        
        Task {
            do {
                // Add timeout to the network call
                try await withThrowingTaskGroup(of: Void.self) { group in
                    group.addTask {
                        try await self.emailService.addSubscriber(
                            email: trimmedEmail,
                            firstName: nil,
                            source: "ios_app_profile"
                        )
                    }
                    
                    group.addTask {
                        try await Task.sleep(nanoseconds: UInt64(self.submissionTimeout * 1_000_000_000))
                        throw EmailMarketingError.timeout
                    }
                    
                    try await group.next()
                    group.cancelAll()
                }
                
                // Cancel timeout timer since we succeeded
                timeoutTask.cancel()
                
                // Log success
                Analytics.logEvent("email_signup_success", parameters: [
                    "source": "ios_app_profile"
                ])
                
                await MainActor.run {
                    self.showMessage("You're subscribed! 🎉 Welcome to the community!", type: .success)
                    self.showSuccess = true
                    self.appState.email = trimmedEmail
                    self.appState.needEmail = false
                    self.isSubmitting = false
                    
                    // Clear form after successful submission
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        self.email = ""
                        self.message = nil
                    }
                }
            } catch {
                // Cancel timeout timer
                timeoutTask.cancel()
                
                // Log failure
                Analytics.logEvent("email_signup_failed", parameters: [
                    "source": "ios_app_profile",
                    "error": error.localizedDescription
                ])
                
                await MainActor.run {
                    self.isSubmitting = false
                    
                    // Specific error handling
                    if case EmailMarketingError.timeout = error {
                        self.showMessage("Request timed out. Please check your internet connection.", type: .error)
                    } else if error.localizedDescription.contains("already") {
                        self.showMessage("You're already subscribed! ✅", type: .success)
                        self.showSuccess = true
                    } else if error.localizedDescription.contains("database") || error.localizedDescription.contains("does not exist") {
                        self.showMessage("Service temporarily unavailable. Please try again later or contact support.", type: .error)
                    } else if error.localizedDescription.contains("network") || error.localizedDescription.contains("connection") {
                        self.showMessage("Network error. Please check your connection.", type: .error)
                    } else {
                        self.showMessage("Unable to subscribe. Please try again.", type: .error)
                    }
                }
                
                print("❌ Error subscribing email: \(error)")
                print("Error details: \(error.localizedDescription)")
            }
        }
    }
    
    private func showMessage(_ text: String, type: MessageType) {
        withAnimation {
            message = text
            messageType = type
            showSuccess = (type == .success)
        }
    }
        
        private func isValidEmail(_ email: String) -> Bool {
            // More robust email validation
            let pattern = #"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$"#
            let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Check basic requirements
            guard !trimmed.isEmpty,
                  trimmed.count >= 5, // Minimum: a@b.c
                  trimmed.count <= 254, // RFC 5321 max email length
                  !trimmed.hasPrefix("."),
                  !trimmed.hasSuffix("."),
                  !trimmed.contains(".."),
                  trimmed.filter({ $0 == "@" }).count == 1 else {
                return false
            }
            
            return trimmed.range(of: pattern, options: .regularExpression) != nil
        }
    }
