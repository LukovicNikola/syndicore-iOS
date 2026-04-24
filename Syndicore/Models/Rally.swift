import Foundation
import os

// MARK: - Rally Status

enum RallyStatus: String, Codable {
    case FORMING, LAUNCHED, RESOLVED, CANCELLED
}

// MARK: - Rally Item

struct RallyItem: Codable, Identifiable {
    let id: String
    let status: RallyStatus
    let creator: RallyCreator
    let target: Coordinate
    let launchAt: Date
    let arrivesAt: Date?
    let silentMarch: Bool
    let participants: [RallyParticipantItem]

    /// Total troop count across all participants.
    var totalTroops: Int {
        participants.reduce(0) { acc, p in acc + p.unitsTyped.values.reduce(0, +) }
    }
}

struct RallyCreator: Codable {
    let playerWorldId: String
    let username: String
}

struct RallyParticipantItem: Codable, Identifiable {
    let id: String
    let playerWorldId: String
    let username: String
    let units: [String: Int]
    let joinedAt: Date

    /// Typed units dict (same pattern as ArmySnapshot).
    var unitsTyped: [UnitType: Int] {
        units.reduce(into: [:]) { acc, kv in
            if let unit = UnitType(rawValue: kv.key) {
                acc[unit] = kv.value
            }
        }
    }
}

// MARK: - Request / Response

struct CreateRallyRequest: Codable, Sendable {
    let targetX: Int
    let targetY: Int
    let launchAt: String  // ISO8601
    let units: [String: Int]
}

struct JoinRallyRequest: Codable, Sendable {
    let units: [String: Int]
}

struct RallyListResponse: Codable {
    let rallies: [RallyItem]
}

struct CreateRallyResponse: Codable {
    let rally: RallyItem
}

struct JoinRallyResponse: Codable {
    let joined: Bool
}

struct LeaveRallyResponse: Codable {
    let left: Bool
}

struct CancelRallyResponse: Codable {
    let cancelled: Bool
}
