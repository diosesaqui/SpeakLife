//
//  WhatsNewView.swift
//  SpeakLife
//
//  Created by Riccardo Washington on 12/31/24.
//

import SwiftUI

struct WhatsNewBottomSheet: View {
    @Binding var isPresented: Bool
    let version: String
    let features = [
        "UX fixes",
       // "NEW Audio AutoPlay"
    ]

    var body: some View {
           VStack(spacing: 20) {
               // Header Section
               VStack(spacing: 10) {
                   Text("What's New in \(version)")
                       .font(.title)
                       .fontWeight(.bold)
                       .multilineTextAlignment(.center)

                   Text("Discover the latest features and enhancements designed to inspire and uplift your experience.")
                       .font(.body)
                       .multilineTextAlignment(.center)
                       .foregroundColor(.secondary)
                       .padding(.horizontal, 20)
               }
               .padding(.top, 20)

               // Features Section
               ScrollView {
                   VStack(alignment: .leading, spacing: 15) {
                       ForEach(features, id: \.self) { feature in
                           HStack(alignment: .top, spacing: 10) {
                               Image(systemName: "checkmark.circle.fill")
                                   .foregroundColor(.blue)
                                   .font(.system(size: 20))

                               Text(feature)
                                   .font(.body)
                                   .foregroundColor(.primary)
                           }
                           .padding(.horizontal, 20)
                       }
                   }
               }

               // Dismiss Button
               Button(action: {
                   isPresented = false
               }) {
                   Text("Get Started")
                       .fontWeight(.bold)
                       .frame(maxWidth: .infinity)
                       .padding()
                       .background(LinearGradient(
                           gradient: Gradient(colors: [Color.blue, Color.purple]),
                           startPoint: .leading,
                           endPoint: .trailing
                       ))
                       .foregroundColor(.white)
                       .cornerRadius(10)
                       .padding(.horizontal, 20)
               }
               .padding(.bottom, 20)
           }
           .background(
               RoundedRectangle(cornerRadius: 20)
                   .fill(Color(.systemBackground))
                   .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: -5)
           )
           .ignoresSafeArea(edges: .bottom)
       }
}

//
//struct EmailBottomSheet: View {
//    @EnvironmentObject var appState: AppState
//    @Binding var isPresented: Bool
//    @State private var email: String = ""
//    @State private var isOptedIn: Bool = false
//    @State private var showConfirmation: Bool = false
//
//    var body: some View {
//           VStack(spacing: 20) {
//               // Title
//               Text("Stay Connected")
//                   .font(.title2)
//                   .fontWeight(.bold)
//
//               // Subtitle
//               Text("Enter your email to receive updates, encouragement, and offers.")
//                   .font(.body)
//                   .multilineTextAlignment(.center)
//                   .foregroundColor(.secondary)
//
//               // Email Input
//               TextField("Enter your email", text: $email)
//                   .textFieldStyle(RoundedBorderTextFieldStyle())
//                   .keyboardType(.emailAddress)
//                   .autocapitalization(.none)
//                   .padding(.horizontal)
//
//               // Opt-In Toggle
//               Toggle(isOn: $isOptedIn) {
//                   Text("I agree to receive emails and updates.")
//                       .font(.footnote)
//                       .foregroundColor(.secondary)
//               }
//               .padding(.horizontal)
//
//               // Submit Button
//               Button(action: handleEmailSubmit) {
//                   Text("Confirm & Opt-In")
//                       .font(.headline)
//                       .padding()
//                       .frame(maxWidth: .infinity)
//                       .background(isFormValid ? Color.blue : Color.gray)
//                       .foregroundColor(.white)
//                       .cornerRadius(10)
//               }
//               .disabled(!isFormValid)
//               .padding(.horizontal)
//
//               // Close Button
//               Button(action: { appState.needEmail = false }) {
//                   Text("Cancel")
//                       .foregroundColor(.red)
//               }
//           }
//           .padding()
//           .background(
//               RoundedRectangle(cornerRadius: 20)
//                   .fill(Color(.systemBackground))
//                   .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: -5)
//           )
//           .ignoresSafeArea(edges: .bottom)
//           .cornerRadius(20)
//           .shadow(radius: 10)
//           .padding(.horizontal)
//       }
//
//       private var isFormValid: Bool {
//           !email.isEmpty && isOptedIn && isValidEmail(email)
//       }
//
//       private func isValidEmail(_ email: String) -> Bool {
//           let emailRegex = ".+@.+\\..+"
//           return NSPredicate(format: "SELF MATCHES %@", emailRegex).evaluate(with: email)
//       }
//
//       private func handleEmailSubmit() {
//           // Simulate confirmation or further handling (e.g., API call)
//           appState.needEmail = false
//       }
//         
//}
