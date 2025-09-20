//
//  DirectEmailCaptureView.swift
//  SpeakLife
//
//  Fallback email capture that saves directly to Firebase
//

import SwiftUI
import FirebaseFirestore
import FirebaseAnalytics

struct DirectEmailCaptureView: View {
    @EnvironmentObject var appState: AppState
    @State private var email: String = ""
    @State private var message: String?
    @State private var isSubmitting: Bool = false
    @State private var showSuccess: Bool = false
    
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
            
            Button(action: submitEmailDirectly) {
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
                Text(message)
                    .foregroundColor(showSuccess ? .green : .red)
                    .font(.footnote)
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
    
    private func submitEmailDirectly() {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Provide specific error messages
        if trimmedEmail.isEmpty {
            withAnimation {
                message = "Please enter your email address"
                showSuccess = false
            }
            return
        }
        
        if !trimmedEmail.contains("@") {
            withAnimation {
                message = "Email must include @ symbol"
                showSuccess = false
            }
            return
        }
        
        guard isValidEmail(trimmedEmail) else {
            withAnimation {
                message = "Please enter a valid email address (e.g., name@example.com)"
                showSuccess = false
            }
            return
        }
        
        isSubmitting = true
        message = nil
        
        print("🔵 Starting DIRECT Firebase email save...")
        
        // Use the specific 'speaklife' database instead of default
        let db = Firestore.firestore(database: "speaklife")
        let collection = db.collection("email_list")
        
        // First check for duplicate
        collection.whereField("email", isEqualTo: trimmedEmail.lowercased())
            .getDocuments { snapshot, error in
                DispatchQueue.main.async {
                    if let error = error {
                        print("❌ Error checking duplicates: \(error.localizedDescription)")
                        withAnimation {
                            message = "Error checking: \(error.localizedDescription)"
                            showSuccess = false
                            isSubmitting = false
                        }
                        
                        Analytics.logEvent("direct_email_check_failed", parameters: [
                            "error": error.localizedDescription
                        ])
                        return
                    }
                    
                    if let docs = snapshot?.documents, !docs.isEmpty {
                        print("ℹ️ Email already exists in Firebase")
                        withAnimation {
                            message = "You're already subscribed! ✅"
                            showSuccess = true
                            isSubmitting = false
                        }
                        
                        Analytics.logEvent("direct_email_duplicate", parameters: [:])
                        return
                    }
                    
                    // No duplicate, add email
                    let data: [String: Any] = [
                        "email": trimmedEmail.lowercased(),
                        "timestamp": Timestamp(date: Date()),
                        "source": "ios_app_direct",
                        "platform": "iOS",
                        "app_version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
                    ]
                    
                    print("📝 Adding document to Firebase...")
                    print("  Collection: email_list")
                    print("  Data: \(data)")
                    
                    collection.addDocument(data: data) { error in
                        DispatchQueue.main.async {
                            isSubmitting = false
                            if let error = error {
                                print("❌ Error saving email: \(error.localizedDescription)")
                                withAnimation {
                                    message = "Error: \(error.localizedDescription)"
                                    showSuccess = false
                                }
                                
                                Analytics.logEvent("direct_email_save_failed", parameters: [
                                    "error": error.localizedDescription
                                ])
                            } else {
                                print("✅ Email saved successfully to Firebase!")
                                withAnimation {
                                    showSuccess = true
                                    message = "You're subscribed! 🎉"
                                    appState.email = email
                                    appState.needEmail = false
                                }
                                
                                Analytics.logEvent("direct_email_save_success", parameters: [:])
                                
                                // Clear form after success
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                    email = ""
                                }
                            }
                        }
                    }
                }
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