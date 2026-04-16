import Foundation

/// Provides the current Supabase access token for authenticated API calls.
protocol TokenProvider: Sendable {
    func accessToken() async throws -> String
}

/// Placeholder token provider — replace with Supabase auth integration.
final class StubTokenProvider: TokenProvider, Sendable {
    func accessToken() async throws -> String {
        fatalError("TokenProvider not configured — integrate supabase-swift")
    }
}
