//
//  AppleSignInPromptView.swift
//  SpeakLife
//
//  Dark sheet shown when a non-signed-in user tries to post on the Prayer Wall.
//  Matches app visual style: onboardingBGImage background + dark overlay.
//

import SwiftUI
import AuthenticationServices

struct AppleSignInPromptView: View {
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    @ObservedObject var appleSignIn: AppleSignInService
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            // Background — same pattern as onboarding screens
            Image(subscriptionStore.onboardingBGImage)
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()

            Color.black.opacity(0.72)
                .ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer()

                // Icon
                Image(systemName: "hands.and.sparkles.fill")
                    .font(.system(size: 54))
                    .foregroundColor(Color(hex: "A78BFA"))
                    .symbolRenderingMode(.multicolor)

                // Title
                Text("Join the Prayer Wall")
                    .font(Font.custom("AppleSDGothicNeo-Bold", size: 26, relativeTo: .title))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)

                // Subtitle
                Text("Carry each other's burdens,\nand in this way you will fulfill the law of Christ.")
                    .font(Font.custom("AppleSDGothicNeo-Regular", size: 15, relativeTo: .body))
                    .foregroundColor(.white.opacity(0.75))
                    .multilineTextAlignment(.center)
                    .italic()
                    .padding(.horizontal, 32)

                Text("— Galatians 6:2")
                    .font(Font.custom("AppleSDGothicNeo-Regular", size: 13, relativeTo: .caption))
                    .foregroundColor(Color(hex: "A78BFA"))

                // Error
                if let error = appleSignIn.errorMessage {
                    Text(error)
                        .font(Font.custom("AppleSDGothicNeo-Regular", size: 13, relativeTo: .caption))
                        .foregroundColor(.red.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                // Sign In with Apple button
                SignInWithAppleButton(.signIn) { request in
                    request.requestedScopes = [.fullName, .email]
                } onCompletion: { result in
                    switch result {
                    case .success:
                        // ASAuthorizationControllerDelegate on the service handles the rest
                        break
                    case .failure(let error):
                        let asError = error as? ASAuthorizationError
                        if asError?.code != .canceled {
                            appleSignIn.errorMessage = error.localizedDescription
                        }
                    }
                }
                .signInWithAppleButtonStyle(.white)
                .frame(height: 50)
                .cornerRadius(12)
                .padding(.horizontal, 32)
                .disabled(appleSignIn.isLoading)
                .overlay(
                    Group {
                        if appleSignIn.isLoading {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.black.opacity(0.35))
                                .padding(.horizontal, 32)
                                .overlay(ProgressView().tint(.white))
                        }
                    }
                )
                // Tap triggers the full Apple Sign In flow via the service
                .simultaneousGesture(TapGesture().onEnded {
                    appleSignIn.signIn()
                })
                .onChange(of: appleSignIn.isSignedIn) { signedIn in
                    if signedIn { dismiss() }
                }

                // Dismiss without signing in
                Button {
                    dismiss()
                } label: {
                    Text("Maybe Later")
                        .font(Font.custom("AppleSDGothicNeo-Regular", size: 15, relativeTo: .body))
                        .foregroundColor(.white.opacity(0.55))
                }
                .padding(.top, 4)

                Spacer()
            }
            .padding(.vertical, 40)
        }
    }
}
