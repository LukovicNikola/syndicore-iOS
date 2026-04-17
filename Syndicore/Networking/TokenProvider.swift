import Foundation

protocol TokenProvider: Sendable {
    /// Vraca trenutni access token. SDK interno refresh-uje ako je blizu isteka.
    func accessToken() async throws -> String

    /// Forsira refresh session-a. APIClient ovo zove na 401 response.
    /// Vraca novi access token ili baca ako refresh ne uspe (signed out slucaj).
    func refreshToken() async throws -> String
}
