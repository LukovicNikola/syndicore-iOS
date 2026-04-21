import Foundation

struct Player: Codable, Identifiable {
    let id: String
    let username: String
    let createdAt: Date
    let updatedAt: Date
    let worlds: [PlayerWorld]?
}

struct PlayerWorld: Codable, Identifiable {
    let id: String
    let playerId: String?   // nije u join response-u, prisutan u GET /me
    let worldId: String?    // nije u join response-u, prisutan u GET /me
    let faction: Faction
    let ring: Ring?         // nije uvek u join response-u
    let crystals: [String]? // nije uvek u join response-u
    let joinedAt: Date?     // nije u join response-u, prisutan u GET /me
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
    let city: City?
    let tile: TileInfo?
}
