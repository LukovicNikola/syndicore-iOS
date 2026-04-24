import Foundation

// MARK: - Display Name Helper

extension String {
    /// Converts SNAKE_CASE to "Title Case" — e.g. "DATA_BANK" → "Data Bank".
    var displayName: String {
        replacingOccurrences(of: "_", with: " ").capitalized
    }
}

// MARK: - Terrain

enum Terrain: String, Codable, CaseIterable {
    case WASTELAND, FLATLAND, QUARRY, RUINS, GEOTHERMAL, HILLTOP, RIVERSIDE, CROSSROADS
}

// MARK: - Rarity

enum Rarity: String, Codable, CaseIterable {
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

enum MovementType: String, Codable, CaseIterable {
    case ATTACK, RAID, SCOUT, REINFORCE, TRANSPORT, SETTLE, RETURN
}

// MARK: - World Status

enum WorldStatus: String, Codable, CaseIterable {
    case OPEN, RUNNING, ENDED, ARCHIVED
}

// MARK: - Resource Type

enum ResourceType: String, Codable, CaseIterable {
    case CREDITS, ALLOYS, TECH, ENERGY
}

// MARK: - Syndikat Role

enum SyndikatRole: String, Codable, CaseIterable, Comparable {
    case OVERLORD, WARDEN, OFFICER, MEMBER

    /// Numeric rank for comparison (lower = higher authority).
    private var rank: Int {
        switch self {
        case .OVERLORD: 0
        case .WARDEN: 1
        case .OFFICER: 2
        case .MEMBER: 3
        }
    }

    static func < (lhs: SyndikatRole, rhs: SyndikatRole) -> Bool {
        lhs.rank < rhs.rank
    }

    /// Whether this role can manage (promote/demote/kick) the target role.
    func canManage(_ target: SyndikatRole) -> Bool {
        self < target
    }
}

// MARK: - Diplomacy Status

enum DiplomacyStatus: String, Codable, CaseIterable {
    case PACT, NEUTRAL, HOSTILE
}

// MARK: - Research Branch

enum ResearchBranch: String, Codable, CaseIterable {
    // Universal
    case LOGISTICS, SIEGE_ENGINEERING, MOBILIZATION
    // Faction-specific
    case AGGRESSION_PROTOCOL   // Reapers
    case BASTION_PROTOCOL      // Hegemony
    case OVERRIDE_PROTOCOL     // Netrunners

    var isUniversal: Bool {
        switch self {
        case .LOGISTICS, .SIEGE_ENGINEERING, .MOBILIZATION: true
        case .AGGRESSION_PROTOCOL, .BASTION_PROTOCOL, .OVERRIDE_PROTOCOL: false
        }
    }

    /// Which faction this branch belongs to (nil for universal).
    var faction: Faction? {
        switch self {
        case .AGGRESSION_PROTOCOL: .reapers
        case .BASTION_PROTOCOL: .hegemony
        case .OVERRIDE_PROTOCOL: .netrunners
        default: nil
        }
    }
}
