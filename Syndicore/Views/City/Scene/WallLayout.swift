import CoreGraphics

enum WallLayout {
    struct WallEntry {
        let position: CGPoint
        let xScale: CGFloat
        let zPosition: CGFloat
    }

    /// Perimetarski zidovi — po n segmenata na svakoj od 4 strane grida.
    static func wallPositions() -> [WallEntry] {
        var entries: [WallEntry] = []
        let n = Isometric.gridSize

        // NE side (row=-1, col 0..<n) — slope "\" (prirodna orijentacija).
        for col in 0..<n {
            entries.append(WallEntry(
                position: Isometric.scenePosition(col: col, row: -1),
                xScale: 1,
                zPosition: Isometric.zDepth(col: col, row: 0) - 0.5
            ))
        }
        // SE side (col=n, row 0..<n) — slope "/".
        for row in 0..<n {
            entries.append(WallEntry(
                position: Isometric.scenePosition(col: n, row: row),
                xScale: -1,
                zPosition: Isometric.zDepth(col: n - 1, row: row) + 1.5
            ))
        }
        // SW side (row=n, col 0..<n) — slope "\" (simetrično NE).
        for col in 0..<n {
            entries.append(WallEntry(
                position: Isometric.scenePosition(col: col, row: n),
                xScale: 1,
                zPosition: Isometric.zDepth(col: col, row: n - 1) + 1.5
            ))
        }
        // NW side (col=-1, row 0..<n) — slope "/" (simetrično SE).
        for row in 0..<n {
            entries.append(WallEntry(
                position: Isometric.scenePosition(col: -1, row: row),
                xScale: -1,
                zPosition: Isometric.zDepth(col: 0, row: row) - 0.5
            ))
        }
        return entries
    }

    /// 4 ugaona pylona na pravim tačkama dijamanta (midpoint susednih
    /// wall endpoint-ova). Pokrivaju seam između dve strane perimetra.
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
            // TOP (back corner) — iza svega.
            WallEntry(position: topPos, xScale: 1, zPosition: -5),
            // RIGHT (east) — ispred susednih zidova.
            WallEntry(
                position:  rightPos,
                xScale:   -1,
                zPosition: Isometric.zDepth(col: n - 1, row: 0) + 2.0
            ),
            // BOTTOM (front) — najbliže kameri.
            WallEntry(
                position:  bottomPos,
                xScale:   -1,
                zPosition: Isometric.zDepth(col: n - 1, row: n - 1) + 3.0
            ),
            // LEFT (west).
            WallEntry(
                position:  leftPos,
                xScale:    1,
                zPosition: Isometric.zDepth(col: 0, row: n - 1) + 2.0
            ),
        ]
    }
}
