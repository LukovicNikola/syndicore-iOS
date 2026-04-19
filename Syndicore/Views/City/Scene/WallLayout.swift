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

        // N side (row = 0, cols 2..3) — pomeren 1 korak unutra da sede uz outer tiles
        for col in 2...3 {
            entries.append(WallEntry(
                position: Isometric.scenePosition(col: col, row: 0),
                xScale: 1,
                zRotation: 0,
                zPosition: Isometric.zDepth(col: col, row: 0) - 0.5
            ))
        }

        // E side (col = n-1, rows 2..3)
        for row in 2...3 {
            entries.append(WallEntry(
                position: Isometric.scenePosition(col: n - 1, row: row),
                xScale: -1,
                zRotation: 0,
                zPosition: Isometric.zDepth(col: n - 1, row: row) + 1.5
            ))
        }

        // S side (row = n-1, cols 2..3)
        for col in 2...3 {
            entries.append(WallEntry(
                position: Isometric.scenePosition(col: col, row: n - 1),
                xScale: 1,
                zRotation: 0,
                zPosition: Isometric.zDepth(col: col, row: n - 1) + 1.5
            ))
        }

        // W side (col = 0, rows 2..3)
        for row in 2...3 {
            entries.append(WallEntry(
                position: Isometric.scenePosition(col: 0, row: row),
                xScale: -1,
                zRotation: 0,
                zPosition: Isometric.zDepth(col: 0, row: row) - 0.5
            ))
        }

        return entries
    }

    // MARK: - Corner pieces (4 bend sprajtova u 4 cornerCutout regiona)

    /// 4 corner pieces koji pokrivaju diagonal cut segmente octagonal-a.
    ///
    /// Pozicija: midpoint između krajnjih endpoint-a dva susedna wall segmenta.
    /// - N corner: midpoint( N-wall-leftmost, W-wall-top )
    /// - E corner: midpoint( N-wall-rightmost, E-wall-top )
    /// - S corner: midpoint( E-wall-bottom, S-wall-rightmost )
    /// - W corner: midpoint( S-wall-leftmost, W-wall-bottom )
    ///
    /// zRotation: sprite prirodno ima konveks DOLE (arms gore u V-formaciji).
    /// - S corner (convex down): 0
    /// - E corner (convex right): π/2
    /// - N corner (convex up): π
    /// - W corner (convex left): -π/2
    ///
    /// Anchor (0.5, 0.5) na WallCornerNode je obavezan — centered anchor
    /// garantuje da rotacija ne pomera vizuelni centar.
    static func cornerPositions() -> [WallEntry] {
        let n = Isometric.gridSize  // 6

        func mid(_ a: (Int, Int), _ b: (Int, Int)) -> CGPoint {
            let pa = Isometric.scenePosition(col: a.0, row: a.1)
            let pb = Isometric.scenePosition(col: b.0, row: b.1)
            return CGPoint(x: (pa.x + pb.x) / 2, y: (pa.y + pb.y) / 2)
        }

        // N/W corner: between N-wall left (col=2,row=0) and W-wall top (col=0,row=2)
        let nPos = mid((2, 0), (0, 2))
        // N/E corner: between N-wall right (col=3,row=0) and E-wall top (col=n-1,row=2)
        let ePos = mid((3, 0), (n - 1, 2))
        // S/E corner: between E-wall bottom (col=n-1,row=3) and S-wall right (col=3,row=n-1)
        let sPos = mid((n - 1, 3), (3, n - 1))
        // S/W corner: between S-wall left (col=2,row=n-1) and W-wall bottom (col=0,row=3)
        let wPos = mid((2, n - 1), (0, 3))

        return [
            WallEntry(
                position: nPos,
                xScale: 1,
                zRotation: .pi,
                zPosition: 1.0   // ispred tile mapa (z=0), iza prednjih zidova
            ),
            WallEntry(
                position: ePos,
                xScale: 1,
                zRotation: .pi / 2,
                zPosition: Isometric.zDepth(col: n - 1, row: 0) + 1.5
            ),
            WallEntry(
                position: sPos,
                xScale: 1,
                zRotation: 0,
                zPosition: Isometric.zDepth(col: n - 1, row: n - 1) + 2.0
            ),
            WallEntry(
                position: wPos,
                xScale: 1,
                zRotation: -.pi / 2,
                zPosition: Isometric.zDepth(col: 0, row: n - 1) + 1.5
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
