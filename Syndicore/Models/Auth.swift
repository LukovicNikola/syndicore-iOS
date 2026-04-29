import Foundation

struct UserSummary: Codable, Identifiable, Sendable {
    let id: UUID
    let email: String?
}

struct OnboardingRequiredResponse: Codable, Sendable {
    let error: String
    let user: UserSummary
}
