import CoreGraphics

/// Izometrijska matematika za CityScene — standardna 2:1 dimetric projekcija.
///
/// **Layout (v2):** 6×6 grid sa octagonal trim (12 corner tiles uklonjeni)
/// i HQ zauzima centralni 2×2 region (4 tile-a). Rezultat: **20 buildable slots**.
///
/// **Camera angle:** elevation = arctan(0.5) = 26.565°. Svi sprite-ovi iz Tripo3D
/// MORAJU biti rendered pri ovom uglu sa orthographic projection. Vidi
/// `SyndicoreContracts/art-reference/sprite_spec_v2.md` za prompt template.
enum Isometric {

    // MARK: - Core constants

    static let tileWidth:  CGFloat = 128
    static let tileHeight: CGFloat = 64    // strict 2:1 ratio
    static let gridSize:   Int     = 6     // even number, allows centered 2x2 HQ

    /// Top-left corner of HQ 2×2 region. HQ pokriva (2,2), (3,2), (2,3), (3,3).
    static let hqOriginCoord: (col: Int, row: Int) = (2, 2)

    // MARK: - Octagonal corner cutouts (12 tiles)
    // Removes 3 corner tiles per corner = octagonal silhouette as on hero reference image.

    /// Tile-ovi koji su izrezani iz grida (ne renderuju se, ne mogu da se grade na njima).
    static let cornerCutouts: Set<GridCoord> = [
        GridCoord(4, 0), GridCoord(5, 0),
        GridCoord(1, 1), GridCoord(5, 1),
        GridCoord(0, 4), GridCoord(4, 4),
        GridCoord(0, 5), GridCoord(1, 5),
    ]

    // MARK: - Scene projection (grid → screen)

    /// Grid coord → scene pozicija (anchor centra tile-a u worldLayer prostoru).
    static func scenePosition(col: Int, row: Int) -> CGPoint {
        CGPoint(
            x: CGFloat(col - row) * tileWidth  / 2,
            y: -CGFloat(col + row) * tileHeight / 2
        )
    }

    /// Pozicija centra HQ-ovog 2×2 regiona — tačno na sredini između 4 HQ tile-a.
    /// Koristi se za pozicioniranje HQ sprite-a koji pokriva 4 tile-a.
    static var hqCenterPosition: CGPoint {
        let topLeft = scenePosition(col: hqOriginCoord.col, row: hqOriginCoord.row)
        let bottomRight = scenePosition(col: hqOriginCoord.col + 1, row: hqOriginCoord.row + 1)
        return CGPoint(
            x: (topLeft.x + bottomRight.x) / 2,
            y: (topLeft.y + bottomRight.y) / 2
        )
    }

    /// Tap u scene space → grid coord. Vraca nil ako je van grida ili u corner cutout-u.
    static func tileCoord(at point: CGPoint) -> (col: Int, row: Int)? {
        let fx =  point.x / (tileWidth  / 2)
        let fy = -point.y / (tileHeight / 2)
        let col = Int(((fx + fy) / 2).rounded())
        let row = Int(((fy - fx) / 2).rounded())
        guard col >= 0, col < gridSize, row >= 0, row < gridSize else { return nil }
        guard !cornerCutouts.contains(GridCoord(col, row)) else { return nil }
        return (col, row)
    }

    // MARK: - Z-depth (iso back-to-front sort)

    /// Z-position za iso depth sort (veće = bliže kameri).
    static func zDepth(col: Int, row: Int) -> CGFloat {
        CGFloat(col + row)
    }

    /// Z-position za HQ — koristi center 2×2 regiona.
    static var hqZDepth: CGFloat {
        // Center between (2,2) and (3,3) → effective depth = (2+3)/2 = 2.5 + (2+3)/2 = 5
        CGFloat(hqOriginCoord.col + hqOriginCoord.row + 1)
    }

    // MARK: - Tile classification

    static func isHQ(col: Int, row: Int) -> Bool {
        col >= hqOriginCoord.col && col <= hqOriginCoord.col + 1 &&
        row >= hqOriginCoord.row && row <= hqOriginCoord.row + 1
    }

    static func isCutout(col: Int, row: Int) -> Bool {
        cornerCutouts.contains(GridCoord(col, row))
    }

    /// Da li se na ovom tile-u moze graditi (nije HQ region, nije cutout, u gridu je).
    static func isBuildable(col: Int, row: Int) -> Bool {
        guard col >= 0, col < gridSize, row >= 0, row < gridSize else { return false }
        return !isHQ(col: col, row: row) && !isCutout(col: col, row: row)
    }

    // MARK: - Slot ↔ coord mapping
    // Slots numerisani 0..19 (20 buildable), ide row by row, top-left → bottom-right.
    // HQ region i corner cutouts se preskaču.

    /// Pre-computed slot lookup table. O(1) pristup nakon prvog poziva.
    private static let slotTable: [(col: Int, row: Int)] = {
        var result: [(col: Int, row: Int)] = []
        for row in 0..<gridSize {
            for col in 0..<gridSize {
                guard isBuildable(col: col, row: row) else { continue }
                result.append((col, row))
            }
        }
        return result
    }()

    /// Inverzna mapa za O(1) slot(forCoord:) lookup.
    private static let coordToSlot: [GridCoord: Int] = {
        var map: [GridCoord: Int] = [:]
        for (idx, coord) in slotTable.enumerated() {
            map[GridCoord(coord.col, coord.row)] = idx
        }
        return map
    }()

    /// Ukupan broj buildable slotova (20 za 6×6 sa octagonal trim + 2×2 HQ).
    static var buildableSlotCount: Int { slotTable.count }

    /// Slot index → (col, row). Vraca nil ako je slot van bounds-a.
    static func coord(forSlot slot: Int) -> (col: Int, row: Int)? {
        guard slot >= 0, slot < slotTable.count else { return nil }
        return slotTable[slot]
    }

    /// (col, row) → slot index. Vraca nil ako je HQ, cutout, ili van grida.
    static func slot(forCoord col: Int, row: Int) -> Int? {
        coordToSlot[GridCoord(col, row)]
    }
}

/// Hashable wrapper za (col, row) tuple — Set/Dict ključ.
struct GridCoord: Hashable {
    let col: Int
    let row: Int
    init(_ col: Int, _ row: Int) {
        self.col = col
        self.row = row
    }
}
