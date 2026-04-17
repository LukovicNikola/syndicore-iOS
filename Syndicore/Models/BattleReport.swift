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
    let buildingsDamaged: [String]?
    let occurredAt: Date
    let isAttacker: Bool
}

// ArmySnapshot uses [UnitType: Int] but JSON has [String: Int] keys — custom Codable required.
struct ArmySnapshot: Codable {
    let before: [UnitType: Int]
    let after: [UnitType: Int]
    let lost: [UnitType: Int]

    enum CodingKeys: String, CodingKey { case before, after, lost }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        before = Self.decodeUnitDict(try c.decode([String: Int].self, forKey: .before))
        after  = Self.decodeUnitDict(try c.decode([String: Int].self, forKey: .after))
        lost   = Self.decodeUnitDict(try c.decode([String: Int].self, forKey: .lost))
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(before.stringKeyed(), forKey: .before)
        try c.encode(after.stringKeyed(), forKey: .after)
        try c.encode(lost.stringKeyed(), forKey: .lost)
    }

    private static func decodeUnitDict(_ raw: [String: Int]) -> [UnitType: Int] {
        raw.reduce(into: [:]) { acc, kv in
            if let unit = UnitType(rawValue: kv.key) { acc[unit] = kv.value }
        }
    }
}

// TroopMovement uses [UnitType: Int] for units and renamed viaGates — custom Codable required.
struct TroopMovement: Codable, Identifiable {
    let id: String
    let type: MovementType
    let from: Coordinate
    let to: Coordinate
    let units: [UnitType: Int]
    let viaGates: [String]
    let departedAt: Date
    let arrivesAt: Date
    let isReturning: Bool

    enum CodingKeys: String, CodingKey {
        case id, type, from, to, units, viaGates, departedAt, arrivesAt, isReturning
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id          = try c.decode(String.self,       forKey: .id)
        type        = try c.decode(MovementType.self, forKey: .type)
        from        = try c.decode(Coordinate.self,   forKey: .from)
        to          = try c.decode(Coordinate.self,   forKey: .to)
        let rawUnits = try c.decode([String: Int].self, forKey: .units)
        units       = rawUnits.reduce(into: [:]) { acc, kv in
            if let unit = UnitType(rawValue: kv.key) { acc[unit] = kv.value }
        }
        viaGates    = try c.decode([String].self,     forKey: .viaGates)
        departedAt  = try c.decode(Date.self,         forKey: .departedAt)
        arrivesAt   = try c.decode(Date.self,         forKey: .arrivesAt)
        isReturning = try c.decode(Bool.self,         forKey: .isReturning)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id,                    forKey: .id)
        try c.encode(type,                  forKey: .type)
        try c.encode(from,                  forKey: .from)
        try c.encode(to,                    forKey: .to)
        try c.encode(units.stringKeyed(),   forKey: .units)
        try c.encode(viaGates,              forKey: .viaGates)
        try c.encode(departedAt,            forKey: .departedAt)
        try c.encode(arrivesAt,             forKey: .arrivesAt)
        try c.encode(isReturning,           forKey: .isReturning)
    }
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
    let route: Route
}

struct Route: Codable {
    let direct: Bool
    let viaGates: [String]
    let travelMinutes: Double
    let arrivesAt: Date
}

// MARK: - Helper

private extension Dictionary where Key == UnitType, Value == Int {
    func stringKeyed() -> [String: Int] {
        var result: [String: Int] = [:]
        for (unit, count) in self { result[unit.rawValue] = count }
        return result
    }
}
