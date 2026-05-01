import Foundation

// MARK: - GET /worlds/:worldId/talents

struct TalentStateResponse: Codable, Sendable {
    var pool: TalentPoolInfo
    let standard: [String: [TalentNode]]
    let faction: FactionTalentInfo
    let modifiers: TalentModifiers
}

struct TalentPoolInfo: Codable, Sendable {
    let researchPoints: Double
    let rpPerHour: Double
    let researchLabLevel: Int
    let lastTalentRespec: Date?
    let respecCooldownDays: Int
}

struct TalentNode: Codable, Identifiable, Sendable {
    let key: String
    let label: String
    let level: Int
    let maxLevel: Int?
    let capstone: Bool?
    var id: String { key }

    var isCapstone: Bool { capstone == true }
    var isMaxed: Bool { level >= (maxLevel ?? 1) }
}

struct FactionTalentInfo: Codable, Sendable {
    let chosen: String?
    let available: Bool
    let units: [String: [TalentNode]]?
}

struct TalentModifiers: Codable, Sendable {
    let atkMultiplier: Double?
    let defMultiplier: Double?
    let siegeMultiplier: Double?
    let creditsProdBonus: Double?
    let alloysProdBonus: Double?
    let techProdBonus: Double?
    let energyProdBonus: Double?
    let buildSpeedBonus: Double?
    let trainingSpeedBonus: Double?
    let movementSpeedBonus: Double?
    let storageCapBonus: Double?
    let lootCapBonus: Double?
    let scoutPowerBonus: Double?
    let watchtowerDetailBonus: Double?
    let alertWindowMinutes: Double?
    let rpPerHourBonus: Double?
    let rpCostReductionBonus: Double?
    let raw: [String: AnyCodableValue]?
}

// MARK: - POST /worlds/:worldId/talents/upgrade

enum TalentTree: String, Codable, Sendable {
    case STANDARD
    case FACTION
}

struct TalentUpgradeRequest: Codable, Sendable {
    let tree: TalentTree
    let scope: String
    let nodeKey: String
}

struct TalentUpgradeResponse: Codable, Sendable {
    let result: TalentUpgradeResult
}

struct TalentUpgradeResult: Codable, Sendable {
    let tree: TalentTree
    let scope: String
    let nodeKey: String
    let previousLevel: Int
    let newLevel: Int
    let cost: Int
    let pointsRemaining: Double
}

// MARK: - POST /worlds/:worldId/talents/respec

struct TalentRespecResponse: Codable, Sendable {
    let result: TalentRespecResult
}

struct TalentRespecResult: Codable, Sendable {
    let refundedRP: Int
}
