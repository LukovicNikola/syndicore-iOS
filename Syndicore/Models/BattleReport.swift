import Foundation

struct BattleReport: Codable, Identifiable {
    let id: String
    let attackerWon: Bool
    let targetX: Int
    let targetY: Int
    let ratio: Double
    let totalAtk: Double
    let totalDef: Double
    let attackerUnits: ArmySnapshot
    let defenderUnits: ArmySnapshot
    let resourcesStolen: Resources?
    let occurredAt: String
    let isAttacker: Bool
}

struct ArmySnapshot: Codable {
    let before: [String: Int]
    let after: [String: Int]
    let lost: [String: Int]
}

struct TroopMovement: Codable, Identifiable {
    let id: String
    let type: String
    let from: Coordinate
    let to: Coordinate
    let units: [String: Int]
    let routeViaGates: [String]
    let departedAt: String
    let arrivesAt: String
    let isReturning: Bool
}

struct Coordinate: Codable {
    let x: Int
    let y: Int
}

// MARK: - API Responses

struct ReportsResponse: Codable {
    let reports: [BattleReport]
}

struct MovementsResponse: Codable {
    let movements: [TroopMovement]
}

struct SendTroopsResponse: Codable {
    let movement: TroopMovement
    let route: RouteInfo
}

struct RouteInfo: Codable {
    let direct: Bool
    let viaGates: [String]
    let travelMinutes: Double
    let arrivesAt: String
}
