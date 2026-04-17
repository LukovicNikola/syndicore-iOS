import SwiftUI
import AuthenticationServices

struct AuthView: View {
    @Environment(GameState.self) private var gameState

    enum Mode {
        case signIn, signUp
    }

    @State private var mode: Mode = .signIn
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var successMessage: String?

    private var isValid: Bool {
        !email.isEmpty && password.count >= 6
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Logo
            Text("SYNDICORE")
                .font(.system(size: 36, weight: .black, design: .monospaced))
                .tracking(4)

            Text(mode == .signIn ? "Sign In" : "Create Account")
                .font(.title3)
                .foregroundStyle(.secondary)

            // Apple Sign In
            SignInWithAppleButton(.signIn) { request in
                do {
                    let nonce = try gameState.auth.generateNonce()
                    request.requestedScopes = [.email]
                    request.nonce = gameState.auth.sha256(nonce)
                } catch {
                    errorMessage = error.localizedDescription
                }
            } onCompletion: { result in
                Task { await handleAppleSignIn(result: result) }
            }
            .signInWithAppleButtonStyle(.white)
            .frame(height: 50)
            .padding(.horizontal, 32)

            // Divider
            HStack {
                Rectangle().frame(height: 1).foregroundStyle(.secondary.opacity(0.3))
                Text("or")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Rectangle().frame(height: 1).foregroundStyle(.secondary.opacity(0.3))
            }
            .padding(.horizontal, 32)

            // Email form
            VStack(spacing: 16) {
                TextField("Email", text: $email)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.emailAddress)
                    .disabled(isLoading)

                SecureField("Password", text: $password)
                    .textFieldStyle(.roundedBorder)
                    .disabled(isLoading)

                if mode == .signUp {
                    Text("Minimum 6 characters")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 32)

            // Success message
            if let successMessage {
                Text(successMessage)
                    .font(.caption)
                    .foregroundStyle(.green)
                    .padding(.horizontal, 32)
                    .multilineTextAlignment(.center)
            }

            // Error
            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 32)
                    .multilineTextAlignment(.center)
            }

            // Submit button
            Button {
                Task { await submitEmail() }
            } label: {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text(mode == .signIn ? "Sign In" : "Sign Up")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(!isValid || isLoading)
            .padding(.horizontal, 32)

            // Toggle mode
            Button {
                withAnimation {
                    mode = mode == .signIn ? .signUp : .signIn
                    errorMessage = nil
                    successMessage = nil
                }
            } label: {
                Text(mode == .signIn
                     ? "Don't have an account? Sign Up"
                     : "Already have an account? Sign In")
                    .font(.footnote)
            }

            Spacer()
            Spacer()
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Email Auth

    private func submitEmail() async {
        isLoading = true
        errorMessage = nil
        successMessage = nil

        do {
            if mode == .signUp {
                let hasSession = try await gameState.auth.signUp(email: email, password: password)
                if hasSession {
                    await gameState.didSignIn()
                } else {
                    successMessage = "Check your email for a confirmation link, then sign in."
                    mode = .signIn
                }
            } else {
                try await gameState.auth.signIn(email: email, password: password)
                await gameState.didSignIn()
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Apple Sign In

    private func handleAppleSignIn(result: Result<ASAuthorization, any Error>) async {
        isLoading = true
        errorMessage = nil
        successMessage = nil

        switch result {
        case .success(let authorization):
            do {
                try await gameState.auth.handleAppleSignIn(authorization: authorization)
                await gameState.didSignIn()
            } catch {
                errorMessage = error.localizedDescription
            }
        case .failure(let error):
            let appleError = error as? ASAuthorizationError
            if appleError?.code == .canceled {
                // Korisnik otkazao — ne prikazuj gresku
            } else if appleError?.code == .unknown {
                // Code 1000 = simulator ili drugi sistemski problem
                errorMessage = "Apple Sign In requires a real device. Use email/password instead."
            } else {
                errorMessage = error.localizedDescription
            }
        }

        isLoading = false
    }
}
