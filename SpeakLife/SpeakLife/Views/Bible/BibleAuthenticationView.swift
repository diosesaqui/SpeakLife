//
//  BibleAuthenticationView.swift
//  SpeakLife
//
//  Created by SpeakLife Team
//

import SwiftUI
import AuthenticationServices

struct BibleAuthenticationView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var authManager = BibleAuthManager()
    @State private var showEmailForm = false
    @State private var email = ""
    @State private var name = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var authMode: AuthMode = .signIn
    
    enum AuthMode {
        case signIn, signUp
    }
    
    let onSuccess: () -> Void
    let onDismiss: () -> Void
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(UIColor.systemBackground),
                        Color.blue.opacity(0.05)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        VStack(spacing: 16) {
                            Image(systemName: "book.closed.fill")
                                .font(.system(size: 60))
                                .foregroundColor(Constants.DAMidBlue)
                                .padding(.top, 20)
                            
                            Text("Unlock Unlimited Bible Access")
                                .font(.title2.bold())
                                .foregroundColor(.primary)
                                .multilineTextAlignment(.center)
                            
                            Text("Sign in to remove the 20 requests per hour limit and access the Bible freely")
                                .font(.subheadline)
                                .foregroundColor(.primary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        
                        // Benefits list
                        VStack(alignment: .leading, spacing: 12) {
                            BibleBenefitRow(icon: "infinity", text: "Unlimited Bible reading")
                            BibleBenefitRow(icon: "magnifyingglass", text: "Unlimited verse searches")
                            BibleBenefitRow(icon: "bookmark.fill", text: "Sync bookmarks across devices")
                            BibleBenefitRow(icon: "lock.open.fill", text: "No hourly limits")
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(UIColor.secondarySystemBackground))
                        )
                        .padding(.horizontal)
                        
                        if !showEmailForm {
                            // Sign in options
                            VStack(spacing: 16) {
                                // Apple Sign In
                                SignInWithAppleButton(
                                    .signIn,
                                    onRequest: { request in
                                        request.requestedScopes = [.fullName, .email]
                                    },
                                    onCompletion: { result in
                                        handleAppleSignIn(result)
                                    }
                                )
                                .signInWithAppleButtonStyle(.black)
                                .frame(height: 50)
                                .cornerRadius(12)
                                
                                // Divider
                                HStack {
                                    Rectangle()
                                        .fill(Color.gray.opacity(0.3))
                                        .frame(height: 1)
                                    Text("or")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Rectangle()
                                        .fill(Color.gray.opacity(0.3))
                                        .frame(height: 1)
                                }
                                
                                // Email Sign In
                                Button(action: {
                                    withAnimation {
                                        showEmailForm = true
                                    }
                                }) {
                                    HStack {
                                        Image(systemName: "envelope.fill")
                                        Text("Sign in with Email")
                                    }
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 50)
                                    .background(Color.blue)
                                    .cornerRadius(12)
                                }
                            }
                            .padding(.horizontal)
                        } else {
                            // Email form
                            emailFormView
                        }
                        
                        // Skip option
                        Button(action: {
                            onDismiss()
                        }) {
                            Text("Maybe Later")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.bottom, 20)
                    }
                }
                
                if isLoading {
                    loadingOverlay
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        onDismiss()
                    }
                }
            }
            .alert("Authentication Error", isPresented: $showError) {
                Button("OK") {
                    showError = false
                }
            } message: {
                Text(errorMessage ?? "An error occurred during authentication")
            }
        }
    }
    
    @ViewBuilder
    private var emailFormView: some View {
        VStack(spacing: 16) {
            // Toggle between Sign In and Sign Up
            Picker("Mode", selection: $authMode) {
                Text("Sign In").tag(AuthMode.signIn)
                Text("Sign Up").tag(AuthMode.signUp)
            }
            .pickerStyle(SegmentedPickerStyle())
            
            VStack(spacing: 12) {
                // Email field
                VStack(alignment: .leading, spacing: 4) {
                    TextField("Email", text: $email)
                        .textFieldStyle(RoundedTextFieldStyle())
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    
                    if !email.isEmpty && !isValidEmail(email.trimmingCharacters(in: .whitespacesAndNewlines)) {
                        Text("Please enter a valid email address")
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(.leading, 4)
                    }
                }
                
                if authMode == .signUp {
                    // Name field (only for sign up)
                    TextField("Name", text: $name)
                        .textFieldStyle(RoundedTextFieldStyle())
                        .autocapitalization(.words)
                }
                
                // Password field
                VStack(alignment: .leading, spacing: 4) {
                    SecureField("Password", text: $password)
                        .textFieldStyle(RoundedTextFieldStyle())
                    
                    if authMode == .signUp && !password.isEmpty && password.count < 6 {
                        Text("Password must be at least 6 characters")
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(.leading, 4)
                    }
                }
            }
            
            HStack(spacing: 12) {
                // Back button
                Button(action: {
                    withAnimation {
                        showEmailForm = false
                        clearForm()
                    }
                }) {
                    Text("Back")
                        .font(.headline)
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(Color(UIColor.tertiarySystemFill))
                        .cornerRadius(10)
                }
                
                // Submit button
                Button(action: {
                    if authMode == .signIn {
                        signInWithEmail()
                    } else {
                        signUpWithEmail()
                    }
                }) {
                    Text(authMode == .signIn ? "Sign In" : "Create Account")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(formIsValid ? Color.blue : Color.gray)
                        .cornerRadius(10)
                }
                .disabled(!formIsValid)
            }
        }
        .padding(.horizontal)
    }
    
    @ViewBuilder
    private var loadingOverlay: some View {
        Color.black.opacity(0.4)
            .ignoresSafeArea()
            .overlay(
                VStack(spacing: 16) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)
                    Text("Authenticating...")
                        .foregroundColor(.white)
                        .font(.headline)
                }
                .padding(32)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(UIColor.systemBackground))
                )
            )
    }
    
    private var formIsValid: Bool {
        if authMode == .signIn {
            return !email.isEmpty && !password.isEmpty && email.contains("@")
        } else {
            return !email.isEmpty && !name.isEmpty && !password.isEmpty && email.contains("@") && password.count >= 6
        }
    }
    
    private func validateForm() -> Bool {
        // Reset any existing error
        errorMessage = nil
        showError = false
        
        // Validate email
        let emailTrimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        if emailTrimmed.isEmpty {
            errorMessage = "Please enter your email address"
            showError = true
            return false
        }
        
        if !isValidEmail(emailTrimmed) {
            errorMessage = "Please enter a valid email address"
            showError = true
            return false
        }
        
        // Validate name (for sign up only)
        if authMode == .signUp {
            let nameTrimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            if nameTrimmed.isEmpty {
                errorMessage = "Please enter your name"
                showError = true
                return false
            }
            
            if nameTrimmed.count < 2 {
                errorMessage = "Name must be at least 2 characters long"
                showError = true
                return false
            }
        }
        
        // Validate password
        if password.isEmpty {
            errorMessage = "Please enter your password"
            showError = true
            return false
        }
        
        if password.count < 6 {
            errorMessage = "Password must be at least 6 characters long"
            showError = true
            return false
        }
        
        return true
    }
    
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = #"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$"#
        return email.range(of: emailRegex, options: .regularExpression) != nil
    }
    
    // MARK: - Authentication Methods
    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        isLoading = true
        
        switch result {
        case .success(let authorization):
            if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
                let userIdentifier = appleIDCredential.user
                let fullName = appleIDCredential.fullName
                let email = appleIDCredential.email ?? "\(userIdentifier)@privaterelay.appleid.com"
                
                let name = [fullName?.givenName, fullName?.familyName]
                    .compactMap { $0 }
                    .joined(separator: " ")
                    .isEmpty ? "Apple User" : [fullName?.givenName, fullName?.familyName]
                    .compactMap { $0 }
                    .joined(separator: " ")
                
                Task {
                    await createBibleUser(email: email, name: name, password: userIdentifier)
                }
            }
        case .failure(let error):
            isLoading = false
            if (error as NSError).code != ASAuthorizationError.canceled.rawValue {
                errorMessage = "Apple Sign In failed: \(error.localizedDescription)"
                showError = true
            }
        }
    }
    
    private func signInWithEmail() {
        guard formIsValid else { return }
        
        // Additional validation before API call
        guard validateForm() else { return }
        
        isLoading = true
        
        Task {
            do {
                let bibleToken = try await BibleAPIService.shared.loginUser(email: email, password: password)
                
                // Try to sign in to Firebase as well
                do {
                    let firebaseUser = try await FirebaseAuthService.shared.signIn(
                        email: email,
                        password: password
                    )
                } catch {
                    // Warning: 
                    print("⚠️ Bible API sign in succeeded but Firebase sign in failed: \(error)")
                    // Continue with Bible API success since that's the primary requirement
                }
                
                await MainActor.run {
                    isLoading = false
                    authManager.saveCredentials(email: email, token: bibleToken.token)
                    onSuccess()
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    handleError(error)
                }
            }
        }
    }
    
    private func signUpWithEmail() {
        guard formIsValid else { return }
        
        // Additional validation before API call
        guard validateForm() else { return }
        
        isLoading = true
        
        Task {
            await createBibleUser(email: email, name: name, password: password)
        }
    }
    
    private func createBibleUser(email: String, name: String, password: String) async {
        do {
            // Try to create Bible API user first
            let bibleToken = try await BibleAPIService.shared.createUser(
                email: email,
                name: name,
                password: password
            )
            
            // If Bible API user creation succeeds, also create Firebase user
            do {
                let firebaseUser = try await FirebaseAuthService.shared.createUser(
                    email: email,
                    password: password,
                    name: name
                )
            } catch {
                // Warning: 
                print("⚠️ Bible API user created but Firebase user creation failed: \(error)")
                // Continue with Bible API success since that's the primary requirement
            }
            
            await MainActor.run {
                isLoading = false
                authManager.saveCredentials(email: email, name: name, token: bibleToken.token)
                onSuccess()
                dismiss()
            }
        } catch {
            // If Bible API user creation fails, try to login instead
            do {
                let bibleToken = try await BibleAPIService.shared.loginUser(
                    email: email,
                    password: password
                )
                
                // Try to sign in to Firebase as well
                do {
                    let firebaseUser = try await FirebaseAuthService.shared.signIn(
                        email: email,
                        password: password
                    )
                } catch {
                    // Warning: 
                    print("⚠️ Bible API sign in succeeded but Firebase sign in failed: \(error)")
                    // Continue with Bible API success since that's the primary requirement
                }
                
                await MainActor.run {
                    isLoading = false
                    authManager.saveCredentials(email: email, name: name, token: bibleToken.token)
                    onSuccess()
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    handleError(error)
                }
            }
        }
    }
    
    private func handleError(_ error: Error) {
        if let apiError = error as? BibleAPIError {
            switch apiError {
            case .unauthorized:
                errorMessage = "Invalid email or password. Please try again."
            case .rateLimited:
                errorMessage = "Too many attempts. Please try again later."
            case .serverError(let code):
                if code == 400 {
                    errorMessage = "Invalid request. Please check your information and try again."
                } else if code == 404 {
                    errorMessage = "Bible service temporarily unavailable. Please try again later."
                } else if code == 409 {
                    errorMessage = "An account with this email already exists. Please sign in instead."
                } else if code >= 500 {
                    errorMessage = "Service temporarily unavailable. Please try again later."
                } else {
                    errorMessage = "Request failed (\(code)). Please try again."
                }
            case .networkError:
                errorMessage = "Network connection error. Please check your internet connection."
            case .decodingError:
                errorMessage = "Service response error. Please try again."
            case .invalidURL:
                errorMessage = "Service configuration error. Please contact support."
            case .noData:
                errorMessage = "No response from service. Please try again."
            }
        } else {
            // Handle specific common errors
            let errorString = error.localizedDescription.lowercased()
            if errorString.contains("network") || errorString.contains("connection") {
                errorMessage = "Network connection error. Please check your internet connection."
            } else if errorString.contains("timeout") {
                errorMessage = "Request timed out. Please try again."
            } else if errorString.contains("password") {
                errorMessage = "Password must be at least 6 characters long."
            } else if errorString.contains("email") {
                errorMessage = "Please enter a valid email address."
            } else {
                errorMessage = "Authentication failed. Please try again."
            }
        }
        showError = true
    }
    
    private func clearForm() {
        email = ""
        name = ""
        password = ""
    }
}

struct BibleBenefitRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(.blue)
                .frame(width: 30)
            
            Text(text)
                .font(.subheadline)
                .foregroundColor(.primary)
            
            Spacer()
        }
    }
}

struct RoundedTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding()
            .background(Color(UIColor.tertiarySystemFill))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            )
    }
}

// MARK: - Bible Auth Manager
class BibleAuthManager: ObservableObject {
    @Published var isAuthenticated = false
    @Published var userEmail: String?
    @Published var userName: String?
    
    private let emailKey = "BibleUserEmail"
    private let nameKey = "BibleUserName"
    private let tokenKey = "BibleAPIAuthToken"
    
    init() {
        checkAuthStatus()
    }
    
    func checkAuthStatus() {
        isAuthenticated = KeychainHelper.shared.loadString(forKey: tokenKey) != nil
        userEmail = KeychainHelper.shared.loadString(forKey: emailKey)
        userName = KeychainHelper.shared.loadString(forKey: nameKey)
    }
    
    func saveCredentials(email: String, name: String? = nil, token: String) {
        let _ = KeychainHelper.shared.save(email, forKey: emailKey)
        if let name = name {
            let _ = KeychainHelper.shared.save(name, forKey: nameKey)
            userName = name
        }
        let _ = KeychainHelper.shared.save(token, forKey: tokenKey)
        isAuthenticated = true
        userEmail = email
    }
    
    func signOut() {
        let _ = KeychainHelper.shared.delete(forKey: emailKey)
        let _ = KeychainHelper.shared.delete(forKey: nameKey)
        let _ = KeychainHelper.shared.delete(forKey: tokenKey)
        BibleAPIService.shared.clearAuthToken()
        isAuthenticated = false
        userEmail = nil
        userName = nil
    }
}

#Preview {
    BibleAuthenticationView(
        onSuccess: { print("Success") },
        onDismiss: { print("Dismissed") }
    )
}
