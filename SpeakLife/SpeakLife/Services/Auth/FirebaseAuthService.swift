//
//  FirebaseAuthService.swift
//  SpeakLife
//
//  Created by SpeakLife Team on 1/28/26.
//

import Foundation
import FirebaseAuth
import FirebaseFirestore

protocol FirebaseAuthServiceProtocol {
    func createUser(email: String, password: String, name: String) async throws -> FirebaseUserResult
    func signIn(email: String, password: String) async throws -> FirebaseUserResult
    func signOut() throws
    func getCurrentUser() -> FirebaseUserResult?
}

struct FirebaseUserResult {
    let uid: String
    let email: String
    let displayName: String?
}

enum FirebaseAuthError: LocalizedError {
    case invalidEmail
    case weakPassword
    case emailAlreadyInUse
    case userNotFound
    case wrongPassword
    case networkError
    case userCreationFailed
    case unknown(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidEmail:
            return "Please enter a valid email address"
        case .weakPassword:
            return "Password should be at least 6 characters"
        case .emailAlreadyInUse:
            return "An account with this email already exists"
        case .userNotFound:
            return "No account found with this email"
        case .wrongPassword:
            return "Incorrect password"
        case .networkError:
            return "Network error. Please check your connection"
        case .userCreationFailed:
            return "Failed to create user profile"
        case .unknown(let error):
            return "An unexpected error occurred: \(error.localizedDescription)"
        }
    }
}

final class FirebaseAuthService: FirebaseAuthServiceProtocol {
    static let shared = FirebaseAuthService()
    
    private let auth = Auth.auth()
    private let firestore = Firestore.firestore()
    
    private init() {}
    
    // MARK: - User Creation
    func createUser(email: String, password: String, name: String) async throws -> FirebaseUserResult {
        do {
            print("🔥 Creating Firebase user with email: \(email)")
            
            // Create the authentication user
            let authResult = try await auth.createUser(withEmail: email, password: password)
            let user = authResult.user
            
            print("🔥 Firebase user created with UID: \(user.uid)")
            
            // Update the user's display name
            let changeRequest = user.createProfileChangeRequest()
            changeRequest.displayName = name
            try await changeRequest.commitChanges()
            
            print("🔥 Display name updated to: \(name)")
            
            // Create user document in Firestore
            let userData: [String: Any] = [
                "uid": user.uid,
                "email": email,
                "displayName": name,
                "createdAt": FieldValue.serverTimestamp(),
                "updatedAt": FieldValue.serverTimestamp(),
                "source": "bible_authentication"
            ]
            
            try await firestore.collection("users").document(user.uid).setData(userData)
            
            print("🔥 User document created in Firestore")
            
            return FirebaseUserResult(
                uid: user.uid,
                email: email,
                displayName: name
            )
            
        } catch {
            print("🔥❌ Firebase user creation failed: \(error)")
            throw mapFirebaseError(error)
        }
    }
    
    // MARK: - Sign In
    func signIn(email: String, password: String) async throws -> FirebaseUserResult {
        do {
            print("🔥 Signing in Firebase user with email: \(email)")
            
            let authResult = try await auth.signIn(withEmail: email, password: password)
            let user = authResult.user
            
            print("🔥 Firebase sign in successful for UID: \(user.uid)")
            
            // Update last login timestamp
            try await firestore.collection("users").document(user.uid).updateData([
                "lastLoginAt": FieldValue.serverTimestamp()
            ])
            
            return FirebaseUserResult(
                uid: user.uid,
                email: user.email ?? email,
                displayName: user.displayName
            )
            
        } catch {
            print("🔥❌ Firebase sign in failed: \(error)")
            throw mapFirebaseError(error)
        }
    }
    
    // MARK: - Sign Out
    func signOut() throws {
        do {
            try auth.signOut()
            print("🔥 Firebase user signed out successfully")
        } catch {
            print("🔥❌ Firebase sign out failed: \(error)")
            throw FirebaseAuthError.unknown(error)
        }
    }
    
    // MARK: - Current User
    func getCurrentUser() -> FirebaseUserResult? {
        guard let user = auth.currentUser else { return nil }
        return FirebaseUserResult(
            uid: user.uid,
            email: user.email ?? "",
            displayName: user.displayName
        )
    }
    
    // MARK: - Error Mapping
    private func mapFirebaseError(_ error: Error) -> FirebaseAuthError {
        guard let authError = error as NSError? else {
            return .unknown(error)
        }
        
        let errorCode = AuthErrorCode(rawValue: authError.code)
        
        switch errorCode {
        case .invalidEmail:
            return .invalidEmail
        case .weakPassword:
            return .weakPassword
        case .emailAlreadyInUse:
            return .emailAlreadyInUse
        case .userNotFound:
            return .userNotFound
        case .wrongPassword:
            return .wrongPassword
        case .networkError:
            return .networkError
        default:
            return .unknown(error)
        }
    }
}
