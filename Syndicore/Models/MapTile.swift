import Foundation

struct MapTile: Codable {
    let x: Int
    let y: Int
    let ring: Ring
    let terrain: Terrain
    let rarity: Rarity
    let city: TileCity?
    let outpost: TileOutpost?
    let mine: TileMine?
    let warpGate: TileWarpGate?
    let ruins: TileRuins?

    var hasOccupant: Bool {
        city != nil || outpost != nil || mine != nil || warpGate != nil || ruins != nil
    }
}

struct TileCity: Codable {
    let id: String
    let name: String
    let owner: String
    let ownerId: String
    let faction: Faction
}

struct TileOutpost: Codable {
    let id: String
    let level: Int
    let defeated: Bool
}

struct TileMine: Codable {
    let id: String
    let resourceType: ResourceType
    let productionRate: Double
    let owned: Bool
}

struct TileWarpGate: Codable {
    let id: String
}

struct TileRuins: Codable {
    let id: String
    let originalRing: Ring
    let decaysAt: Date
}

// MARK: - API Response
// MapViewport je outer wrapper; ViewportBounds je inner {cx, cy, radius}.

struct MapViewport: Codable {
    let viewport: ViewportBounds
    let tileCount: Int
    let tiles: [MapTile]
}

struct ViewportBounds: Codable {
    let cx: Int
    let cy: Int
    let radius: Int
}
