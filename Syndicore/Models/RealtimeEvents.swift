import Foundation

/// Socket.IO realtime events koje BE emituje ka klijentu.
///
/// **Channels (rooms):**
/// - `city:{cityId}` — per-city events (building_complete, training_complete, incoming_attack)
/// - `world:{worldId}` — world-wide events (troops_arrived, itd.)
///
/// **UI rule:** events su SAMO refresh triggeri — uvek fetch fresh state iz REST API-ja
/// posle event-a. Ne mutirati lokalni state direktno iz payload-a (može biti stale).
///
/// Svi event modeli su Decodable. BE šalje JSON payload, klijent decode-uje po event name-u.

// MARK: - Incoming Attack

/// `incoming_attack` event — BE šalje defender-u kad je attack movement kreiran ka njegovom gradu.
///
/// **Watchtower tier-ovi (detail level skalira sa WT level-om):**
/// - **WT 0:** samo `movementType` + `arrivesAt`
/// - **WT 1-5:** dodat `attackerName`
/// - **WT 6-10:** dodat `troopEstimate` (small/medium/large)
/// - **WT 11-15:** umesto `troopEstimate`, exact `units` dict
/// - **WT 16-20:** dodat `origin` (attacker's city coords)
struct IncomingAttackEvent: Decodable {
    let movementType: String      // "ATTACK" ili "RAID"
    let arrivesAt: Date

    // WT 1+ tier
    let attackerName: String?

    // WT 6-10 tier (nestaje kad dodje WT 11+ ga zameni `units`)
    let troopEstimate: String?    // "small" | "medium" | "large"

    // WT 11+ tier — exact army composition
    let units: [String: Int]?

    // WT 16+ tier — origin coords
    let origin: Coordinate?

    /// Helper — MovementType enum iz rawValue.
    var type: MovementType {
        MovementType(rawValue: movementType) ?? .ATTACK
    }

    /// Helper — decoded units dict sa UnitType keys.
    var unitsTyped: [UnitType: Int]? {
        guard let units else { return nil }
        return units.reduce(into: [:]) { acc, pair in
            if let unit = UnitType(rawValue: pair.key) {
                acc[unit] = pair.value
            }
        }
    }

    /// Watchtower tier koji je potreban za prikazivanje pojedinih polja.
    /// Koristi se za conditional UI (npr. "Show origin only if WT 16+").
    enum Tier {
        case basic      // WT 0: type + time
        case named      // WT 1-5: + attackerName
        case estimate   // WT 6-10: + troopEstimate
        case exactArmy  // WT 11-15: + units
        case fullIntel  // WT 16-20: + origin
    }

    var tier: Tier {
        if origin != nil        { return .fullIntel }
        if units != nil         { return .exactArmy }
        if troopEstimate != nil { return .estimate }
        if attackerName != nil  { return .named }
        return .basic
    }
}

// MARK: - Building Complete

/// `building_complete` event — emituje kad se gradnja ili upgrade završi.
struct BuildingCompleteEvent: Decodable {
    let buildingId: String
    let type: BuildingType
    let newLevel: Int
}

// MARK: - Training Complete

/// `training_complete` event — emituje kad training job završi.
struct TrainingCompleteEvent: Decodable {
    let unitType: UnitType
    let count: Int
}

// MARK: - Troops Arrived

/// `troops_arrived` event — emituje na world room-u kad stigne movement na destination.
struct TroopsArrivedEvent: Decodable {
    let movementId: String
    let type: MovementType
    let targetX: Int
    let targetY: Int
}
