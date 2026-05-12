import Foundation

// MARK: - Empire Overview (GET /api/v1/me/empire-overview)

struct EmpireOverviewResponse: Codable, Sendable {
    let rings: [EmpireRingEntry]
    let currentRing: Ring?
    let totalActiveRings: Int
}

struct EmpireRingEntry: Codable, Sendable {
    let ringType: Ring
    let worldId: String
    let worldName: String
    let playerWorld: EmpirePlayerWorldInfo
    let stats: EmpireRingStats
}

struct EmpirePlayerWorldInfo: Codable, Sendable {
    let id: String
    let joinedAt: Date
    let isActive: Bool
    let mainCityId: String?
}

struct EmpireRingStats: Codable, Sendable {
    let totalPlayersInWorld: Int
    let playerRank: Int
    let playerRankPercentile: Double
    let totalCitiesOwned: Int
    let totalOutpostsOwned: Int
}

// MARK: - Minimap (GET /api/v1/worlds/{worldId}/minimap)

enum MinimapTileType: String, Codable, Sendable {
    case playerCity   = "PLAYER_CITY"
    case allyCity     = "ALLY_CITY"
    case enemyCity    = "ENEMY_CITY"
    case rogueOutpost = "ROGUE_OUTPOST"
    case resourceMine = "RESOURCE_MINE"
    case warpGate     = "WARP_GATE"
    case ruins        = "RUINS"
}

struct MinimapTile: Codable, Sendable {
    let x: Int
    let y: Int
    let type: MinimapTileType
    let ownerId: String?
    let ownerName: String?
    let syndicateId: String?
    let isPlayerOwned: Bool
    let isAlly: Bool
    let isEnemy: Bool
}

struct MinimapPlayerPosition: Codable, Sendable {
    let x: Int
    let y: Int
    let mainCityId: String
}

struct MinimapResponse: Codable, Sendable {
    let worldId: String
    let worldRadius: Int
    let tiles: [MinimapTile]
    let playerPosition: MinimapPlayerPosition?
}
