import Foundation

struct City: Codable, Identifiable {
    let id: String
    let name: String
    let resources: Resources?
    let tile: TileInfo?
    let buildings: [BuildingInfo]?
    let troops: [TroopInfo]?
    let constructionQueue: ConstructionQueue?
}

struct Resources: Codable {
    let credits: Double
    let alloys: Double
    let tech: Double
    let energy: Double?
}

struct TileInfo: Codable {
    let x: Int
    let y: Int
    let ring: Ring
    let terrain: Terrain
    let rarity: Rarity
}

struct BuildingInfo: Codable, Identifiable {
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

struct TroopInfo: Codable {
    let unitType: UnitType
    let count: Int
}

struct ConstructionQueue: Codable {
    let buildingId: String
    let type: BuildingType
    let endsAt: Date?
}

struct TrainingJob: Codable, Identifiable {
    let id: String
    let unitType: UnitType
    let count: Int
    let endsAt: Date
}

// MARK: - API Responses

struct CityResponse: Codable {
    let city: City
}

struct BuildResponse: Codable {
    let building: BuildingInfo
    let cost: Resources?
}

struct BuildCostResponse: Codable {
    let buildingType: BuildingType
    let currentLevel: Int
    let targetLevel: Int
    let cost: Resources
    let durationMinutes: Double
}

struct TrainResponse: Codable {
    let trainingJob: TrainingJob
    let cost: Resources?
}

struct TrainingListResponse: Codable {
    let training: [TrainingJob]
}
