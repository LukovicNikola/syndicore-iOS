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
    // Syndikat membership (null ako nije u klanu)
    let syndikatId: String?
    let syndikatRole: SyndikatRole?
    let syndikat: SyndikatSummary?

    var isInSyndikat: Bool { syndikatId != nil }
}

/// Lightweight syndikat info embedded in PlayerWorld (from GET /me).
struct SyndikatSummary: Codable {
    let id: String
    let name: String
    let tag: String
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
