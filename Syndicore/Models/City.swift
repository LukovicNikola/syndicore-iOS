import Foundation

struct City: Codable, Identifiable, Sendable {
    let id: String
    let name: String
    let resources: Resources?
    let tile: TileInfo?
    let buildings: [BuildingInfo]?
    let troops: [TroopInfo]?
    /// Trupe koje su saveznici (iz istog sindikata ili sa PACT diplomatijom)
    /// REINFORCE-ovali u ovaj grad. Defender-only view.
    let reinforcements: [ReinforcementInfo]?
    let constructionQueue: ConstructionQueue?
}

/// Savezničke trupe trenutno garrison-ovane u gradu.
/// Prikazuju se kao sekundarna sekcija u ArmyView Troops tab-u, grupisano po vlasniku.
struct ReinforcementInfo: Codable, Identifiable, Sendable {
    let id: String
    let ownerPlayerId: String
    let ownerUsername: String
    let unitType: UnitType
    let count: Int
}

/// Response za POST /reinforcements/:id/recall
struct RecallReinforcementResponse: Codable, Sendable {
    let recalled: Bool
    let movement: TroopMovement
}

struct Resources: Codable, Sendable {
    let credits: Double
    let alloys: Double
    let tech: Double
    let energy: Double?
}

struct TileInfo: Codable, Sendable {
    let x: Int
    let y: Int
    let ring: Ring?
    let terrain: Terrain?
    let rarity: Rarity?
}

struct BuildingInfo: Codable, Identifiable, Sendable {
    let id: String
    let type: BuildingType
    let currentLevel: Int
    let targetLevel: Int?       // nil ako nije u upgrade-u
    let endsAt: Date?           // nil ako nije u upgrade-u
    let slotIndex: Int?         // nil za fixed buildings

    var isUpgrading: Bool { targetLevel != nil && endsAt != nil }

    // Backward compat: stari BE šalje "level"+"isUpgrading"+"upgradeEnd",
    // novi BE šalje "currentLevel"+"targetLevel"+"endsAt"
    enum CodingKeys: String, CodingKey {
        case id, type, slotIndex
        case currentLevel, level
        case targetLevel
        case endsAt, upgradeEnd
        case isUpgrading
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id          = try c.decode(String.self,       forKey: .id)
        type        = try c.decode(BuildingType.self,  forKey: .type)
        slotIndex   = try? c.decode(Int.self,          forKey: .slotIndex)
        targetLevel = try? c.decode(Int.self,          forKey: .targetLevel)
        // "currentLevel" (novi BE) ili "level" (stari BE) — explicit throw ako oba fale
        if let v = try? c.decode(Int.self, forKey: .currentLevel) {
            currentLevel = v
        } else if let v = try? c.decode(Int.self, forKey: .level) {
            currentLevel = v
        } else {
            throw DecodingError.keyNotFound(
                CodingKeys.currentLevel,
                .init(codingPath: c.codingPath, debugDescription: "Neither 'currentLevel' nor 'level' found in BuildingInfo")
            )
        }
        // "endsAt" (novi BE) ili "upgradeEnd" (stari BE)
        endsAt = (try? c.decode(Date.self, forKey: .endsAt))
            ?? (try? c.decode(Date.self, forKey: .upgradeEnd))
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id,           forKey: .id)
        try c.encode(type,         forKey: .type)
        try c.encode(currentLevel, forKey: .currentLevel)
        try c.encodeIfPresent(targetLevel, forKey: .targetLevel)
        try c.encodeIfPresent(endsAt,      forKey: .endsAt)
        try c.encodeIfPresent(slotIndex,   forKey: .slotIndex)
    }
}

struct TroopInfo: Codable, Sendable {
    let unitType: UnitType
    let count: Int
}

struct ConstructionQueue: Codable, Sendable {
    let buildingId: String
    let type: BuildingType
    let endsAt: Date?
}

struct TrainingJob: Codable, Identifiable, Sendable {
    let id: String
    let unitType: UnitType
    let count: Int
    let endsAt: Date
}

// MARK: - API Responses

struct CityResponse: Codable, Sendable {
    let city: City
}

struct BuildResponse: Codable, Sendable {
    let building: BuildingInfo
    let cost: Resources?
}

struct BuildCostResponse: Codable, Sendable {
    let buildingType: BuildingType
    let currentLevel: Int
    let targetLevel: Int
    let cost: Resources
    let durationMinutes: Double
}

struct TrainResponse: Codable, Sendable {
    let trainingJob: TrainingJob
    let cost: Resources?
}

struct TrainingListResponse: Codable, Sendable {
    let training: [TrainingJob]
}

// MARK: - Implosion

struct ImplodeResponse: Codable, Sendable {
    /// The ring whose crystal was just collected (e.g. FRINGE → GRID transition collects FRINGE).
    let crystal: Ring
    /// The new ring the player has progressed into.
    let newRing: Ring
    let ruins: ImplodeRuinsInfo
    let newCity: ImplodeCityInfo
}

struct ImplodeRuinsInfo: Codable, Sendable {
    let x: Int
    let y: Int
    let decaysAt: Date
}

struct ImplodeCityInfo: Codable, Sendable {
    let id: String
    let name: String
    let tile: TileInfo
}
