import Foundation

struct World: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let slug: String
    let status: WorldStatus
    let speedMultiplier: Double
    let mapRadius: Int
    let maxPlayers: Int
    let playerCount: Int
}

struct WorldsResponse: Codable {
    let worlds: [World]
}
