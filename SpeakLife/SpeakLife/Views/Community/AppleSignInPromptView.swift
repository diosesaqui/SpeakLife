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
                    .dsAppear(0)

                // Title
                Text("Join the Warrior Room")
                    .font(Font.custom("AppleSDGothicNeo-Bold", size: 26, relativeTo: .title))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .dsAppear(0.06)

                // Subtitle
                Text("Carry each other's burdens,\nand in this way you will fulfill the law of Christ.")
                    .font(Font.custom("AppleSDGothicNeo-Regular", size: 15, relativeTo: .body))
                    .foregroundColor(.white.opacity(0.75))
                    .multilineTextAlignment(.center)
                    .italic()
                    .padding(.horizontal, DS.Spacing.xl)
<<<<<<< HEAD
                    .dsAppear(0.12)
=======
>>>>>>> origin/main

                Text("— Galatians 6:2")
                    .font(Font.custom("AppleSDGothicNeo-Regular", size: 13, relativeTo: .caption))
                    .foregroundColor(Color(hex: "A78BFA"))

                // Error
                if let error = appleSignIn.errorMessage {
                    Text(error)
                        .font(Font.custom("AppleSDGothicNeo-Regular", size: 13, relativeTo: .caption))
                        .foregroundColor(.red.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, DS.Spacing.xl)
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
                        // Ignore cancellation + error 1000 (Apple Sign In unsupported in simulator)
                        let ignored: [ASAuthorizationError.Code] = [.canceled, .unknown]
                        if let code = asError?.code, ignored.contains(code) { break }
                        appleSignIn.errorMessage = error.localizedDescription
                    }
                }
                .signInWithAppleButtonStyle(.white)
                .frame(width: 280, height: 56)
                .clipShape(Capsule())
                .cornerRadius(12)
                .padding(.horizontal, DS.Spacing.xl)
                .disabled(appleSignIn.isLoading)
                .overlay(
                    Group {
                        if appleSignIn.isLoading {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.black.opacity(0.35))
                                .padding(.horizontal, DS.Spacing.xl)
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
                .buttonStyle(.dsPressable(feel: .tapSolid))
                .padding(.top, DS.Spacing.xxs)

                Spacer()
            }
            .padding(.vertical, 40)
        }
    }
}
