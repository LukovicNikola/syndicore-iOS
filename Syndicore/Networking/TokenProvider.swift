import Foundation

protocol TokenProvider: Sendable {
    func accessToken() async throws -> String
}
