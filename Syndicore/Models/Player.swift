import Foundation

struct Player: Codable, Identifiable, Equatable {
    let id: UUID
    let username: String
    let createdAt: Date
    let updatedAt: Date
}

struct MeResponse: Codable {
    let player: Player
}

struct OnboardingRequest: Codable {
    let username: String
}
