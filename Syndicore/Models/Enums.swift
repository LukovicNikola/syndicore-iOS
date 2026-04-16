import Foundation

// MARK: - Terrain

enum Terrain: String, Codable, CaseIterable {
    case WASTELAND, FLATLAND, QUARRY, RUINS, GEOTHERMAL, HILLTOP, RIVERSIDE, CROSSROADS
}

// MARK: - Rarity

enum Rarity: String, Codable {
    case COMMON, UNCOMMON, RARE
}

// MARK: - Building Type

enum BuildingType: String, Codable, CaseIterable {
    // Resource buildings (flex slots)
    case DATA_BANK, FOUNDRY, TECH_LAB, POWER_GRID
    // Fixed buildings (one each)
    case HQ, BARRACKS, MOTOR_POOL, OPS_CENTER, WAREHOUSE
    case WALL, WATCHTOWER, RALLY_POINT, TRADE_POST, RESEARCH_LAB
}

// MARK: - Unit Type

enum UnitType: String, Codable, CaseIterable {
    case GRUNT, ENFORCER, SENTINEL, STRIKER, PHANTOM, BUSTER, HAULER, TITAN, SETTLER
}

// MARK: - Movement Type

enum MovementType: String, Codable {
    case ATTACK, RAID, SCOUT, REINFORCE, TRANSPORT, SETTLE, RETURN
}
