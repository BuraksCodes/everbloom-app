// AuthView.swift
// Everbloom — Anxiety & Panic Support App
// Login / Sign-up screen with Zen aesthetic

import SwiftUI
import AuthenticationServices

struct AuthView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var mode: AuthMode = .signIn
    @State private var email = ""
    @State private var password = ""
    @State private var displayName = ""
    @State private var showingReset = false
    @State private var didAppear = false

    enum AuthMode { case signIn, signUp }

    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [.bgTop, Color(red: 0.90, green: 0.87, blue: 0.98)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // Decorative circles
            decorativeBackground

            ScrollView(showsIndicators: false) {
                VStack(spacing: 32) {
                    Spacer(minLength: 60)

                    // Logo / header
                    headerSection

                    // Card
                    formCard
                        .padding(.horizontal, 24)

                    // Toggle sign in / sign up
                    toggleButton

                    Spacer(minLength: 40)
                }
            }
        }
        .opacity(didAppear ? 1 : 0)
        .offset(y: didAppear ? 0 : 20)
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) { didAppear = true }
        }
        .alert("Reset Password", isPresented: $showingReset) {
            TextField("Your email", text: $email)
                .textInputAutocapitalization(.never)
                .keyboardType(.emailAddress)
            Button("Send Reset Email") {
                Task { await authManager.resetPassword(email: email) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("We'll send a reset link to your email.")
        }
    }

    // MARK: - Decorative Background

    private var decorativeBackground: some View {
        ZStack {
            Circle()
                .fill(Color.zenLavender.opacity(0.35))
                .frame(width: 300, height: 300)
                .offset(x: -120, y: -200)
                .blur(radius: 40)
            Circle()
                .fill(Color.zenPeach.opacity(0.35))
                .frame(width: 250, height: 250)
                .offset(x: 140, y: 200)
                .blur(radius: 40)
            Circle()
                .fill(Color.zenSage.opacity(0.25))
                .frame(width: 200, height: 200)
                .offset(x: 100, y: -300)
                .blur(radius: 30)
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 12) {
            Image("EvBloomLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 100, height: 100)
                .clipShape(Circle())
                .shadow(color: .zenLavender.opacity(0.4), radius: 12, x: 0, y: 6)

            Text("Everbloom")
                .font(ZenFont.title(34))
                .foregroundColor(.zenText)

            Text("Your calm companion")
                .font(ZenFont.body(16))
                .foregroundColor(.zenSubtext)
        }
    }

    // MARK: - Form Card

    private var formCard: some View {
        VStack(spacing: 20) {

            // Mode header
            Text(mode == .signIn ? "Welcome back" : "Create your account")
                .font(ZenFont.heading(20))
                .foregroundColor(.zenText)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Error message
            if let error = authManager.errorMessage {
                HStack(spacing: 8) {
                    Image(systemName: error.hasPrefix("Password reset") ? "checkmark.circle" : "exclamationmark.circle")
                        .foregroundColor(error.hasPrefix("Password reset") ? .zenMoss : .red.opacity(0.8))
                    Text(error)
                        .font(ZenFont.caption(13))
                        .foregroundColor(error.hasPrefix("Password reset") ? .zenMoss : .red.opacity(0.8))
                }
                .padding(12)
                .background(
                    (error.hasPrefix("Password reset") ? Color.zenSage : Color.zenRose).opacity(0.3)
                )
                .cornerRadius(10)
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            // Display name (sign up only)
            if mode == .signUp {
                ZenTextField(
                    icon: "person",
                    placeholder: "Your name",
                    text: $displayName,
                    type: .name
                )
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            // Email
            ZenTextField(
                icon: "envelope",
                placeholder: "Email address",
                text: $email,
                type: .email
            )

            // Password
            ZenSecureField(
                icon: "lock",
                placeholder: "Password",
                text: $password
            )

            // Forgot password
            if mode == .signIn {
                Button {
                    showingReset = true
                } label: {
                    Text("Forgot password?")
                        .font(ZenFont.caption(13))
                        .foregroundColor(.zenPurple)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }

            // Primary action button
            Button {
                Task {
                    if mode == .signIn {
                        await authManager.signIn(email: email, password: password)
                    } else {
                        await authManager.signUp(email: email, password: password, displayName: displayName)
                    }
                }
            } label: {
                ZStack {
                    if authManager.isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text(mode == .signIn ? "Sign In" : "Create Account")
                            .font(ZenFont.heading(17))
                            .foregroundColor(.white)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [.zenPurple, Color(red: 0.65, green: 0.45, blue: 0.85)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(16)
                .shadow(color: .zenPurple.opacity(0.35), radius: 10, x: 0, y: 5)
            }
            .disabled(authManager.isLoading || email.isEmpty || password.isEmpty)
            .opacity(email.isEmpty || password.isEmpty ? 0.6 : 1)

            // Divider
            HStack {
                Rectangle().fill(Color.zenSubtext.opacity(0.2)).frame(height: 1)
                Text("or")
                    .font(ZenFont.caption(13))
                    .foregroundColor(.zenSubtext)
                    .padding(.horizontal, 8)
                Rectangle().fill(Color.zenSubtext.opacity(0.2)).frame(height: 1)
            }

            // Sign in with Apple
            SignInWithAppleButton(
                mode == .signIn ? .signIn : .signUp
            ) { request in
                let hashedNonce = authManager.prepareAppleSignIn()
                request.requestedScopes = [.fullName, .email]
                request.nonce = hashedNonce
            } onCompletion: { result in
                switch result {
                case .success(let auth):
                    Task { await authManager.handleAppleSignIn(auth) }
                case .failure(let error):
                    #if DEBUG
                    print("Apple Sign In error: \(error)")
                    #endif
                }
            }
            .signInWithAppleButtonStyle(.black)
            .frame(height: 50)
            .cornerRadius(14)
        }
        .padding(24)
        .zenCard()
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: mode)
        .animation(.easeInOut(duration: 0.3), value: authManager.errorMessage)
    }

    // MARK: - Toggle Mode

    private var toggleButton: some View {
        HStack(spacing: 4) {
            Text(mode == .signIn ? "Don't have an account?" : "Already have an account?")
                .font(ZenFont.body(15))
                .foregroundColor(.zenSubtext)
            Button {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    mode = mode == .signIn ? .signUp : .signIn
                    authManager.errorMessage = nil
                }
            } label: {
                Text(mode == .signIn ? "Sign Up" : "Sign In")
                    .font(ZenFont.heading(15))
                    .foregroundColor(.zenPurple)
            }
        }
    }
}

// MARK: - Zen Text Field

struct ZenTextField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    var type: TextFieldType = .text

    enum TextFieldType { case text, email, name }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.zenSubtext)
                .frame(width: 20)

            TextField(placeholder, text: $text)
                .font(ZenFont.body(16))
                .foregroundColor(.zenText)
                .textInputAutocapitalization(type == .email ? .never : .words)
                .autocorrectionDisabled(type == .email)
                .keyboardType(type == .email ? .emailAddress : .default)
        }
        .padding(14)
        .background(Color.white.opacity(0.75))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.zenLavender.opacity(0.5), lineWidth: 1)
        )
    }
}

// MARK: - Zen Secure Field

struct ZenSecureField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    @State private var isVisible = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.zenSubtext)
                .frame(width: 20)

            if isVisible {
                TextField(placeholder, text: $text)
                    .font(ZenFont.body(16))
                    .foregroundColor(.zenText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            } else {
                SecureField(placeholder, text: $text)
                    .font(ZenFont.body(16))
                    .foregroundColor(.zenText)
            }

            Button {
                isVisible.toggle()
            } label: {
                Image(systemName: isVisible ? "eye.slash" : "eye")
                    .font(.system(size: 14))
                    .foregroundColor(.zenSubtext)
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.75))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.zenLavender.opacity(0.5), lineWidth: 1)
        )
    }
}

#Preview {
    AuthView()
        .environmentObject(AuthManager())
}
