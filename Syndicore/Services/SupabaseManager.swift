import Foundation
import Supabase
import Auth
import AuthenticationServices
import CryptoKit

/// Wrapper oko supabase-swift SDK-a.
/// Credentials se injektuju preko AppConfig-a (loaduje se u SyndicoreApp pre bilo kakvog pristupa).
/// Pruza sign in/up/out i token za API pozive.
@Observable
@MainActor
final class SupabaseManager {

    // MARK: - Configured singleton

    /// Backing za `shared`. Postavlja se jednom preko `configure(config:)` u SyndicoreApp.
    /// `nonisolated(unsafe)` jer singleton bootstrap ide pre nego što bilo koja concurrent
    /// koriscenje pocne — nakon toga `_shared` je immutable de facto.
    nonisolated(unsafe) private static var _shared: SupabaseManager?

    /// Globalni singleton. Pristupaj TEK NAKON `configure(config:)` u SyndicoreApp.
    /// `nonisolated` da bi `SupabaseTokenProvider` mogao da pristupi iz non-main actor konteksta.
    nonisolated static var shared: SupabaseManager {
        guard let mgr = _shared else {
            preconditionFailure("SupabaseManager.configure(config:) mora da se pozove pre pristupa .shared. Vidi SyndicoreApp.")
        }
        return mgr
    }

    /// Poziva se jednom u SyndicoreApp nakon što je AppConfig učitan.
    /// Mora da se zove sa @MainActor konteksta (npr. SwiftUI .task u SyndicoreApp).
    static func configure(config: AppConfig) {
        assert(_shared == nil, "SupabaseManager je vec konfigurisan")
        _shared = SupabaseManager(config: config)
    }

    // MARK: - Properties

    nonisolated let client: SupabaseClient

    /// Trenutna Supabase sesija (nil = nije ulogovan)
    private(set) var session: Session?

    var isAuthenticated: Bool { session != nil }

    /// Nonce za Apple Sign In (mora da se sacuva izmedju request-a i completion-a)
    var currentNonce: String?

    /// Task koji slusa onAuthStateChange stream. Cuva se da bi mogao da se cancel-uje.
    private var authListenerTask: Task<Void, Never>?

    // MARK: - Init

    init(config: AppConfig) {
        self.client = SupabaseClient(
            supabaseURL: config.supabaseURL,
            supabaseKey: config.supabaseAnonKey,
            options: .init(
                auth: .init(emitLocalSessionAsInitialSession: true)
            )
        )
        // Start listening za auth state changes (token refresh, signed out iz drugih tab-ova/uređaja)
        self.authListenerTask = Task { [weak self] in
            await self?.listenToAuthChanges()
        }
    }

    deinit {
        authListenerTask?.cancel()
    }

    // MARK: - Session Management

    func restoreSession() async {
        do {
            session = try await client.auth.session
        } catch {
            session = nil
        }
    }

    func listenToAuthChanges() async {
        for await (event, updatedSession) in client.auth.authStateChanges {
            switch event {
            case .signedIn, .tokenRefreshed:
                session = updatedSession
            case .signedOut:
                session = nil
            default:
                break
            }
        }
    }

    // MARK: - Email Auth

    @discardableResult
    func signUp(email: String, password: String) async throws -> Bool {
        let result = try await client.auth.signUp(email: email, password: password)
        session = result.session
        return result.session != nil
    }

    func signIn(email: String, password: String) async throws {
        session = try await client.auth.signIn(email: email, password: password)
    }

    // MARK: - Apple Sign In

    /// Generise random nonce za Apple Sign In.
    /// Baca SupabaseAuthError.nonceGenerationFailed ako SecRandomCopyBytes otkaze (izuzetno retko).
    func generateNonce() throws -> String {
        let nonce = try randomNonceString()
        currentNonce = nonce
        return nonce
    }

    /// SHA256 hash nonce-a za Apple request.
    func sha256(_ input: String) -> String {
        let data = Data(input.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }

    /// Obradjuje Apple Sign In rezultat — salje identity token Supabase-u.
    func handleAppleSignIn(authorization: ASAuthorization) async throws {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let identityTokenData = credential.identityToken,
              let idToken = String(data: identityTokenData, encoding: .utf8)
        else {
            throw SupabaseAuthError.appleSignInFailed
        }

        guard let nonce = currentNonce else {
            throw SupabaseAuthError.appleSignInFailed
        }

        session = try await client.auth.signInWithIdToken(
            credentials: .init(
                provider: .apple,
                idToken: idToken,
                nonce: nonce
            )
        )
    }

    // MARK: - Sign Out

    func signOut() async throws {
        try await client.auth.signOut()
        session = nil
    }

    // MARK: - Token

    func accessToken() async throws -> String {
        guard let session else {
            throw SupabaseAuthError.notAuthenticated
        }
        return session.accessToken
    }

    // MARK: - Private

    private func randomNonceString(length: Int = 32) throws -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if errorCode != errSecSuccess {
            throw SupabaseAuthError.nonceGenerationFailed(osStatus: errorCode)
        }
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvxyz-._")
        return String(randomBytes.map { charset[Int($0) % charset.count] })
    }
}

// MARK: - TokenProvider conformance (za APIClient)

final class SupabaseTokenProvider: TokenProvider, Sendable {
    func accessToken() async throws -> String {
        let session = try await SupabaseManager.shared.client.auth.session
        return session.accessToken
    }

    func refreshToken() async throws -> String {
        let session = try await SupabaseManager.shared.client.auth.refreshSession()
        return session.accessToken
    }
}

// MARK: - Error

enum SupabaseAuthError: LocalizedError {
    case notAuthenticated
    case appleSignInFailed
    case nonceGenerationFailed(osStatus: Int32)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Not authenticated -- please sign in"
        case .appleSignInFailed:
            return "Apple Sign In failed -- please try again"
        case .nonceGenerationFailed(let osStatus):
            return "Secure nonce generation failed (OSStatus \(osStatus)). Pokušaj ponovo."
        }
    }
}
