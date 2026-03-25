// AuthManager.swift
// Everbloom — Anxiety & Panic Support App
// Handles Firebase Authentication (email/password + Sign in with Apple)

import SwiftUI
import Combine
import CryptoKit
import AuthenticationServices
import FirebaseAuth

// Swift 6 fix: @MainActor on the class breaks @Published synthesis.
// Solution: no @MainActor on the class; mark individual methods @MainActor instead.
class AuthManager: ObservableObject {
    @Published var user: User? = nil
    @Published var isLoading = false
    @Published var errorMessage: String? = nil

    private var stateListener: AuthStateDidChangeListenerHandle?

    @MainActor
    init() {
        // Listen for auth state changes
        stateListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                self?.user = user
            }
        }
    }

    deinit {
        if let handle = stateListener {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }

    @MainActor var isSignedIn: Bool { user != nil }
    @MainActor var userEmail: String { user?.email ?? "" }
    @MainActor var displayName: String {
        if let name = user?.displayName, !name.isEmpty { return name }
        return userEmail.components(separatedBy: "@").first?.capitalized ?? "Friend"
    }

    // MARK: - Email / Password

    @MainActor
    func signIn(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        do {
            try await Auth.auth().signIn(withEmail: email, password: password)
        } catch {
            errorMessage = friendlyError(error)
        }
        isLoading = false
    }

    @MainActor
    func signUp(email: String, password: String, displayName: String) async {
        isLoading = true
        errorMessage = nil
        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            // Set display name
            let changeRequest = result.user.createProfileChangeRequest()
            changeRequest.displayName = displayName.isEmpty ? email.components(separatedBy: "@").first ?? "" : displayName
            try await changeRequest.commitChanges()
        } catch {
            errorMessage = friendlyError(error)
        }
        isLoading = false
    }

    @MainActor
    func resetPassword(email: String) async {
        isLoading = true
        errorMessage = nil
        do {
            try await Auth.auth().sendPasswordReset(withEmail: email)
            errorMessage = "Password reset email sent — check your inbox."
        } catch {
            errorMessage = friendlyError(error)
        }
        isLoading = false
    }

    @MainActor
    func signOut() {
        do {
            try Auth.auth().signOut()
        } catch {
            errorMessage = friendlyError(error)
        }
    }

    // MARK: - Delete Account

    /// Permanently deletes the Firebase Auth account and all Firestore data for this user.
    /// After deletion the auth state listener fires and drives navigation back to AuthView.
    @MainActor
    func deleteAccount() async {
        guard let currentUser = Auth.auth().currentUser else { return }
        isLoading = true
        do {
            // 1. Delete all Firestore data first (journals, moods, profile)
            try? await FirestoreManager.shared.deleteAllUserData(uid: currentUser.uid)
            // 2. Delete the Firebase Auth account itself
            try await currentUser.delete()
            // Auth state listener handles navigation automatically
        } catch {
            errorMessage = friendlyError(error)
        }
        isLoading = false
    }

    // MARK: - Sign in with Apple

    // Holds the current nonce for Apple sign-in (must persist across async call)
    private var currentNonce: String?

    @MainActor
    func handleAppleSignIn(_ authorization: ASAuthorization) async {
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let nonce = currentNonce,
              let appleIDToken = appleIDCredential.identityToken,
              let idTokenString = String(data: appleIDToken, encoding: .utf8)
        else {
            errorMessage = "Apple Sign In failed — please try again."
            return
        }

        isLoading = true
        errorMessage = nil

        let credential = OAuthProvider.appleCredential(
            withIDToken: idTokenString,
            rawNonce: nonce,
            fullName: appleIDCredential.fullName
        )

        do {
            try await Auth.auth().signIn(with: credential)
        } catch {
            errorMessage = friendlyError(error)
        }
        isLoading = false
    }

    @MainActor
    func prepareAppleSignIn() -> String {
        let nonce = randomNonceString()
        currentNonce = nonce
        return sha256(nonce)
    }

    // MARK: - Nonce Helpers

    private func randomNonceString(length: Int = 32) -> String {
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length
        while remainingLength > 0 {
            var randoms = [UInt8](repeating: 0, count: 16)
            let status = SecRandomCopyBytes(kSecRandomDefault, randoms.count, &randoms)
            if status != errSecSuccess { fatalError("Unable to generate nonce: \(status)") }
            randoms.forEach { random in
                if remainingLength == 0 { return }
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }
        return result
    }

    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashed = SHA256.hash(data: inputData)
        return hashed.compactMap { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Error Messages

    private func friendlyError(_ error: Error) -> String {
        let nsError = error as NSError
        guard let code = AuthErrorCode(rawValue: nsError.code) else {
            return error.localizedDescription
        }
        switch code {
        case .emailAlreadyInUse:      return "This email is already in use. Try signing in instead."
        case .invalidEmail:           return "Please enter a valid email address."
        case .weakPassword:           return "Password must be at least 6 characters."
        case .wrongPassword:          return "Incorrect password. Please try again."
        case .userNotFound:           return "No account found with this email."
        case .networkError:           return "Network error — please check your connection."
        case .tooManyRequests:        return "Too many attempts. Please wait a moment."
        default:                      return error.localizedDescription
        }
    }
}
