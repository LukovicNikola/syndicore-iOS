import Foundation

struct GameData: Codable {
    let factions: [String: FactionData]
    let resources: [String]
    let units: [String: UnitStats]
    let clanUnit: [String: ClanUnitStats]?
    let buildingFormulas: BuildingFormulas
    let buildings: BuildingsData
    let techTree: TechTreeData
    let map: MapData
    let movement: MovementData?
    let combat: CombatData
    let syndikat: SyndikatData
    let clanBuildings: [String: ClanBuildingData]
    let reinforcement: [String: ReinforcementData]
    let respec: RespecData
}

// MARK: - Factions

struct FactionData: Codable {
    let id: String
    let name: String
    let bonusType: String
    let bonusValue: Double
    let primaryResource: String
    let description: String
}

// MARK: - Units

struct UnitStats: Codable {
    let atk: Int
    let def: Int
    let spd: Int
    let carry: Int
    let energy: Int
    let trainMin: Int
    let cost: [String: Int]
    let trainsAt: String
    let unlockLevel: Int
    let maxPerClan: Int?
}

struct ClanUnitStats: Codable {
    let atk: Int
    let def: Int
    let spd: Int
    let carry: Int
    let energy: Int
    let trainMin: Int
    let cost: [String: Int]
    let maxPerClan: Int
}

// MARK: - Buildings

struct BuildingFormulas: Codable {
    let costMultiplier: Double
    let timeMultiplier: Double
}

struct BuildingsData: Codable {
    let resource: [String: ResourceBuildingData]
    let fixed: [String: FixedBuildingData]
}

struct ResourceBuildingData: Codable {
    let produces: String
    let baseRate: Int
    let maxRate: Int
    let maxLevel: Int
    let baseCost: [String: Int]
    let baseTimeMinutes: Int
}

struct FixedBuildingData: Codable {
    let maxLevel: Int
    let baseCost: [String: Int]
    let baseTimeMinutes: Int
    let slots: [String: Int]?
    let settlerUnlock: [String: Int]?
    let unlocks: [String: String]?
    let protectionMin: Int?
    let protectionMax: Int?
    let defBonusMin: Double?
    let defBonusMax: Double?
    let createAt: [String: Int]?
    let silentMarchAt: Int?
    let maxTransactionMin: Int?
    let maxTransactionMax: Int?
    let points: [String: Int]?
}

// MARK: - Tech Tree

struct TechTreeData: Codable {
    let researchCostMultiplier: Double?
    let researchTimeMultiplier: Double?
    let universal: [String: TechBranchData]
    let faction: [String: TechBranchData]
}

struct TechBranchData: Codable {
    let faction: String?
    let maxLevel: Int
    let pointCosts: [Int]
    let baseCost: [String: Int]
    let baseTimeMinutes: Int
    let effects: [[String: AnyCodableValue]]
}

// MARK: - Map

struct MapData: Codable {
    let zones: [String: ZoneData]
    let terrains: [String: TerrainData]
    let rarities: [String: RarityData]
}

struct ZoneData: Codable {
    let productionBonus: Double
    let minHq: Int
    let canDestroy: Bool
}

struct TerrainData: Codable {
    let bonusType: String?
    let bonusValue: Double?
}

struct RarityData: Codable {
    let bonus: Double
    let distribution: Double
}

// MARK: - Movement

struct MovementData: Codable {
    let warpGateDelayMinutes: Int?
    let warpGateInterceptionEnabled: Bool?
}

// MARK: - Combat

struct CombatData: Codable {
    let wallHpPerLevel: Int?
    let lootMaxPerAttack: Int?
    let casualtyMultiplier: Double
    let rallyBonusPerPlayer: Double
    let rallyMaxPlayers: Int
    let shadeExposeDurationHours: Int
    let shadeExposeAtkBonus: Double
    let havocRebuildLockHours: Int
    let overloadProductionPenalty: Double
    let overloadPenaltyHours: Int
    let siphonWarehouseBypass: Double
    let aegisAuraDef: Int
    let aegisMaxStack: Int
    let rhinoShieldPct: Double
    let bastionHomeDef: Int
    let bastionAwayDef: Int
    let watchmanWallHpPer10: Double
    let breacherWallMultiplier: Double
    let gruntDeathAtkBonus: Int
}

// MARK: - Syndikat

struct SyndikatData: Codable {
    let maxMembers: Int
    let maxWardens: Int
    let maxOfficers: Int
    let pactBreakCooldownHours: Int
    let settlementCeasefireHours: Int
    let settlementReofferCooldownHours: Int
    let maxClanBuildings: Int
}

// MARK: - Clan Buildings

struct ClanBuildingData: Codable {
    let cost: [String: Int]
    let hp: Int
    let radius: Int?
    let capacity: Int?
    let scoutDebuff: Double?
    let watchtowerBonus: Int?
    let transferBonus: Double?
}

// MARK: - Reinforcement

struct ReinforcementData: Codable {
    let name: String
    let def: Int
    let spd: Int
    let energyDrain: Int
    let energyProduces: Int
    let cost: [String: Int]
}

// MARK: - Respec

struct RespecData: Codable {
    let resourceLossPct: Double
    let cooldownHours: Int
}
