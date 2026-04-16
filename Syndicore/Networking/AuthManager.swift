import Foundation
import Supabase
import AuthenticationServices

@Observable
final class AuthManager: TokenProvider, @unchecked Sendable {
    private let supabase: SupabaseClient

    private(set) var isAuthenticated = false

    init(supabaseURL: URL, supabaseKey: String) {
        self.supabase = SupabaseClient(
            supabaseURL: supabaseURL,
            supabaseKey: supabaseKey
        )
    }

    func restoreSession() async {
        do {
            _ = try await supabase.auth.session
            isAuthenticated = true
        } catch {
            isAuthenticated = false
        }
    }

    func signInWithApple(_ credential: ASAuthorizationAppleIDCredential) async throws {
        guard let identityToken = credential.identityToken,
              let idToken = String(data: identityToken, encoding: .utf8) else {
            throw URLError(.userAuthenticationRequired)
        }

        try await supabase.auth.signInWithIdToken(
            credentials: .init(provider: .apple, idToken: idToken)
        )
        isAuthenticated = true
    }

    func signOut() async {
        try? await supabase.auth.signOut()
        isAuthenticated = false
    }

    // MARK: - TokenProvider

    func accessToken() async throws -> String {
        let session = try await supabase.auth.session
        return session.accessToken
    }
}
