//
//  AppleSignInService.swift
//  SpeakLife
//
//  Singleton service for Sign In with Apple + Firebase Auth.
//  Handles nonce generation, SHA-256 hashing, Firebase credential
//  creation, and Firestore user upsert.
//

import SwiftUI
import AuthenticationServices
import FirebaseAuth
import FirebaseFirestore
import CryptoKit

@MainActor
final class AppleSignInService: NSObject, ObservableObject {

    // MARK: - Singleton
    static let shared = AppleSignInService()

    // MARK: - Published State
    @Published var isSignedIn: Bool = false
    @Published var displayName: String = ""
    @Published var uid: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    // MARK: - Private
    private nonisolated(unsafe) var currentNonce: String?
    private var presentationWindow: ASPresentationAnchor?
    private let db = Firestore.firestore()

    private override init() {
        super.init()
        checkCurrentUser()
    }

    // MARK: - Check Current User

    func checkCurrentUser() {
        if let user = Auth.auth().currentUser {
            isSignedIn = true
            uid = user.uid
            displayName = user.displayName ?? ""
        } else {
            isSignedIn = false
            uid = ""
            displayName = ""
        }
    }

    // MARK: - Sign In

    func signIn(presentationAnchor: ASPresentationAnchor? = nil) {
        self.presentationWindow = presentationAnchor
        errorMessage = nil
        isLoading = true

        let nonce = randomNonceString()
        currentNonce = nonce

        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
    }

    // MARK: - Sign Out

    func signOut() {
        do {
            try Auth.auth().signOut()
            isSignedIn = false
            uid = ""
            displayName = ""
        } catch {
            errorMessage = "Sign out failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Firestore Upsert

    private func upsertUserDocument(uid: String, displayName: String, email: String?) {
        var data: [String: Any] = [
            "uid": uid,
            "displayName": displayName,
            "updatedAt": FieldValue.serverTimestamp(),
            "source": "apple_sign_in"
        ]
        if let email = email {
            data["email"] = email
        }

        db.collection("users").document(uid).setData(data, merge: true) { error in
            if let error = error {
                print("⚠️ AppleSignInService: Firestore upsert failed: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Nonce Helpers

    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if errorCode != errSecSuccess {
            fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
        }
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        let nonce = randomBytes.map { byte in
            charset[Int(byte) % charset.count]
        }
        return String(nonce)
    }

    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashed = SHA256.hash(data: inputData)
        return hashed.compactMap { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - ASAuthorizationControllerDelegate

extension AppleSignInService: ASAuthorizationControllerDelegate {

    nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        guard let appleCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let appleIDToken = appleCredential.identityToken,
              let idTokenString = String(data: appleIDToken, encoding: .utf8),
              let nonce = currentNonce else {
            Task { @MainActor in
                self.isLoading = false
                self.errorMessage = "Apple Sign In failed: invalid credential."
            }
            return
        }

        let credential = OAuthProvider.appleCredential(
            withIDToken: idTokenString,
            rawNonce: nonce,
            fullName: appleCredential.fullName
        )

        Task { @MainActor in
            do {
                let result = try await Auth.auth().signIn(with: credential)
                let user = result.user

                // Build display name from Apple credential (only provided on first sign-in)
                let name: String
                if let fullName = appleCredential.fullName,
                   let given = fullName.givenName, !given.isEmpty {
                    name = [given, fullName.familyName].compactMap { $0 }.joined(separator: " ")
                    // Persist to Firebase profile
                    let changeRequest = user.createProfileChangeRequest()
                    changeRequest.displayName = name
                    try? await changeRequest.commitChanges()
                } else {
                    name = user.displayName ?? "Prayer Warrior"
                }

                self.uid = user.uid
                self.displayName = name
                self.isSignedIn = true
                self.isLoading = false

                self.upsertUserDocument(uid: user.uid, displayName: name, email: appleCredential.email ?? user.email)
            } catch {
                self.isLoading = false
                self.errorMessage = "Sign in failed: \(error.localizedDescription)"
            }
        }
    }

    nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        Task { @MainActor in
            self.isLoading = false
            // Cancelled by user — not an error we surface
            let asError = error as? ASAuthorizationError
            if asError?.code != .canceled {
                self.errorMessage = "Apple Sign In failed: \(error.localizedDescription)"
            }
        }
    }
}

// MARK: - ASAuthorizationControllerPresentationContextProviding

extension AppleSignInService: ASAuthorizationControllerPresentationContextProviding {
    nonisolated func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        // Find key window from connected scenes
        if let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }),
           let window = scene.windows.first(where: { $0.isKeyWindow }) {
            return window
        }
        return UIWindow()
    }
}
