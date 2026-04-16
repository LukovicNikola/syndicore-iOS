import Foundation

struct WorldSummary: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let slug: String
    let status: String
    let speedMultiplier: Double
    let mapRadius: Int
    let maxPlayers: Int
    let playerCount: Int
}

struct WorldsResponse: Codable {
    let worlds: [WorldSummary]
}

struct JoinWorldRequest: Codable {
    let faction: Faction
}
