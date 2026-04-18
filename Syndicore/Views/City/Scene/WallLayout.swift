import CoreGraphics
import Foundation

/// Octagonal perimeter wall placement za CityScene.
///
/// **v3 layout:** octagonal perimeter (prati shape buildable tile-ova):
/// - **4 cardinal edges** (N/E/S/W), svaka sa 2 wall_segment_v1 segmenta = 8 segmenata
/// - **4 corner pieces** (N/E/S/W vertices octagon-a), jedan wall_corner_v1 po uglu
/// - **4 cardinal pylons** na extreme cardinal pozicijama (opciono, mogu se skriti ako preklapaju)
///
/// Orijentacija octagon-a prati screen space (gde je N = top screen, itd.),
/// jer nase grid ima N vertex iso-projected na tile (0,0), E na (5,0), etc.
enum WallLayout {

    struct WallEntry {
        let position: CGPoint
        let xScale: CGFloat       // -1 za mirrored horizontal flip
        let zRotation: CGFloat    // radijani, za WallCornerNode rotaciju
        let zPosition: CGFloat
    }

    // MARK: - Cardinal walls (8 segmenata, 2 po svakoj od 4 strane)

    /// 8 segmenata postojećeg wall_segment_v1 sprajta na 4 cardinal edge-a.
    /// Svaka strana pokriva samo buildable cols/rows (2..3), NE full 0..n-1.
    static func wallPositions() -> [WallEntry] {
        var entries: [WallEntry] = []
        let n = Isometric.gridSize  // 6

        // N side (row = -1, cols 2..3) — slope "\"
        for col in 2...3 {
            entries.append(WallEntry(
                position: Isometric.scenePosition(col: col, row: -1),
                xScale: 1,
                zRotation: 0,
                zPosition: Isometric.zDepth(col: col, row: 0) - 0.5
            ))
        }

        // E side (col = n, rows 2..3) — slope "/"
        for row in 2...3 {
            entries.append(WallEntry(
                position: Isometric.scenePosition(col: n, row: row),
                xScale: -1,
                zRotation: 0,
                zPosition: Isometric.zDepth(col: n - 1, row: row) + 1.5
            ))
        }

        // S side (row = n, cols 2..3) — slope "\" (front-facing, najbliže kameri)
        for col in 2...3 {
            entries.append(WallEntry(
                position: Isometric.scenePosition(col: col, row: n),
                xScale: 1,
                zRotation: 0,
                zPosition: Isometric.zDepth(col: col, row: n - 1) + 1.5
            ))
        }

        // W side (col = -1, rows 2..3) — slope "/"
        for row in 2...3 {
            entries.append(WallEntry(
                position: Isometric.scenePosition(col: -1, row: row),
                xScale: -1,
                zRotation: 0,
                zPosition: Isometric.zDepth(col: 0, row: row) - 0.5
            ))
        }

        return entries
    }

    // MARK: - Corner pieces (4 bend sprajtova u 4 cornerCutout regiona)

    /// 4 corner pieces koji pokrivaju diagonal cut segmente octagonal-a.
    /// Orijentacija (zRotation) prati orijentaciju ugla:
    /// - N corner: rotacija tako da konveks strana gleda TOP screen
    /// - E corner: konveks gleda desno
    /// - S corner: konveks gleda dole (natural sprite orientation = 0)
    /// - W corner: konveks gleda levo
    ///
    /// Sprite prirodno ima konveks DOLE i arms UP u V-formaciji (bend na dnu).
    static func cornerPositions() -> [WallEntry] {
        // Centar svakog cornerCutout regiona — srednja tačka 3 cutout tile-a.
        // Npr. za N corner (cutouts (0,0),(1,0),(0,1)) → center = scenePosition(1/3, 1/3) ≈ (0, -21)

        func cutoutCenter(_ cutouts: [(Int, Int)]) -> CGPoint {
            let positions = cutouts.map { Isometric.scenePosition(col: $0.0, row: $0.1) }
            let sumX = positions.reduce(0) { $0 + $1.x }
            let sumY = positions.reduce(0) { $0 + $1.y }
            return CGPoint(
                x: sumX / CGFloat(positions.count),
                y: sumY / CGFloat(positions.count)
            )
        }

        // N vertex octagon-a (top of screen) — cornerCutouts (0,0)(1,0)(0,1)
        let nPos = cutoutCenter([(0, 0), (1, 0), (0, 1)])
        // E vertex (right of screen) — cornerCutouts (4,0)(5,0)(5,1)
        let ePos = cutoutCenter([(4, 0), (5, 0), (5, 1)])
        // S vertex (bottom of screen) — cornerCutouts (5,4)(4,5)(5,5)
        let sPos = cutoutCenter([(5, 4), (4, 5), (5, 5)])
        // W vertex (left of screen) — cornerCutouts (0,4)(0,5)(1,5)
        let wPos = cutoutCenter([(0, 4), (0, 5), (1, 5)])

        // zRotation (SpriteKit: CCW positive radians)
        // Natural sprite (zRotation=0) ima konveks DOLE. Da dobijemo:
        // - S corner (convex down): 0 rad
        // - E corner (convex right): π/2
        // - N corner (convex up): π
        // - W corner (convex left): -π/2
        return [
            WallEntry(
                position: nPos,
                xScale: 1,
                zRotation: .pi,
                zPosition: -4.0  // iza svega (top corner je najdalji od kamere)
            ),
            WallEntry(
                position: ePos,
                xScale: 1,
                zRotation: .pi / 2,
                zPosition: Isometric.zDepth(col: 4, row: 0) + 1.0
            ),
            WallEntry(
                position: sPos,
                xScale: 1,
                zRotation: 0,
                zPosition: Isometric.zDepth(col: 4, row: 4) + 2.5  // ispred svega
            ),
            WallEntry(
                position: wPos,
                xScale: 1,
                zRotation: -.pi / 2,
                zPosition: Isometric.zDepth(col: 0, row: 4) + 1.0
            ),
        ]
    }

    // MARK: - Pylons (opciono — možda se preklapaju sa corner pieces)

    /// 4 decorative pylona na ekstremnim cardinal tačkama octagonal-a.
    /// Trenutno iste pozicije kao u originalnom square layout-u — možda će se
    /// vizuelno preklapati sa corner pieces, pa ih skidamo ako ne rade.
    static func pylonPositions() -> [WallEntry] {
        let n = Isometric.gridSize

        func mid(_ a: CGPoint, _ b: CGPoint) -> CGPoint {
            CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
        }

        let topPos = mid(
            Isometric.scenePosition(col: -1, row:  0),
            Isometric.scenePosition(col:  0, row: -1)
        )
        let rightPos = mid(
            Isometric.scenePosition(col: n - 1, row: -1),
            Isometric.scenePosition(col: n,     row:  0)
        )
        let bottomPos = mid(
            Isometric.scenePosition(col: n,     row: n - 1),
            Isometric.scenePosition(col: n - 1, row: n)
        )
        let leftPos = mid(
            Isometric.scenePosition(col:  0, row: n),
            Isometric.scenePosition(col: -1, row: n - 1)
        )

        return [
            WallEntry(position: topPos,    xScale:  1, zRotation: 0, zPosition: -5),
            WallEntry(position: rightPos,  xScale: -1, zRotation: 0, zPosition: Isometric.zDepth(col: n - 1, row: 0) + 2.0),
            WallEntry(position: bottomPos, xScale: -1, zRotation: 0, zPosition: Isometric.zDepth(col: n - 1, row: n - 1) + 3.0),
            WallEntry(position: leftPos,   xScale:  1, zRotation: 0, zPosition: Isometric.zDepth(col: 0, row: n - 1) + 2.0),
        ]
    }
}
