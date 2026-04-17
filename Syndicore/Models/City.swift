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
    let level: Int
    let isUpgrading: Bool
    let upgradeEnd: String?
    let slotIndex: Int?
}

struct TroopInfo: Codable {
    let unitType: String
    let count: Int
}

struct ConstructionQueue: Codable {
    let buildingId: String
    let type: String
    let endsAt: String?
}

struct TrainingJob: Codable, Identifiable {
    let id: String
    let unitType: String
    let count: Int
    let endsAt: String
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
    let buildingType: String
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
