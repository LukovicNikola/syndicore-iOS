import Foundation

struct Player: Codable, Identifiable {
    let id: String
    let username: String
    let createdAt: String
    let updatedAt: String
    let worlds: [PlayerWorld]?
}

struct PlayerWorld: Codable, Identifiable {
    let id: String
    let playerId: String
    let worldId: String
    let faction: Faction
    let ring: Ring
    let crystals: [String]
    let joinedAt: String
    let city: City?
}

// MARK: - API

struct MeResponse: Codable {
    let player: Player
}

struct OnboardingRequest: Codable {
    let username: String
}

struct JoinWorldRequest: Codable {
    let faction: Faction
}

struct JoinWorldResponse: Codable {
    let playerWorld: PlayerWorld
    let city: City
    let tile: TileInfo
}
