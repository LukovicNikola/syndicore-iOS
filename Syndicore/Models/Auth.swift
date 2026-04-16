import Foundation

struct UserSummary: Codable, Identifiable {
    let id: UUID
    let email: String?
}

struct OnboardingRequiredResponse: Codable {
    let error: String
    let user: UserSummary
}
