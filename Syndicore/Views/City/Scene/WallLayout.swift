import CoreGraphics

/// Računa pozicije perimetarnih zidova i pylona oko 5×5 grida.
enum WallLayout {
    struct WallEntry {
        let position: CGPoint
        let xScale: CGFloat  // 1 = normalno, -1 = horizontalni mirror
        let zPosition: CGFloat
    }

    static func wallPositions() -> [WallEntry] {
        var entries: [WallEntry] = []
        let n = Isometric.gridSize

        // Gornja strana (col 0..n-1, row = -1)
        for col in 0..<n {
            entries.append(WallEntry(
                position: Isometric.scenePosition(col: col, row: -1),
                xScale: 1,
                zPosition: Isometric.zDepth(col: col, row: 0) + 1.0
            ))
        }
        // Desna strana (col = n, row 0..n-1) — flip
        for row in 0..<n {
            entries.append(WallEntry(
                position: Isometric.scenePosition(col: n, row: row),
                xScale: -1,
                zPosition: Isometric.zDepth(col: n - 1, row: row) + 1.0
            ))
        }
        // Donja strana (col 0..n-1, row = n) — flip
        for col in 0..<n {
            entries.append(WallEntry(
                position: Isometric.scenePosition(col: col, row: n),
                xScale: -1,
                zPosition: Isometric.zDepth(col: col, row: n - 1) + 1.0
            ))
        }
        // Leva strana (col = -1, row 0..n-1)
        for row in 0..<n {
            entries.append(WallEntry(
                position: Isometric.scenePosition(col: -1, row: row),
                xScale: 1,
                zPosition: Isometric.zDepth(col: 0, row: row) + 1.0
            ))
        }
        return entries
    }

    static func pylonPositions() -> [WallEntry] {
        let n = Isometric.gridSize
        return [
            WallEntry(position: Isometric.scenePosition(col: -1, row: -1),  xScale:  1, zPosition: 2.0),
            WallEntry(position: Isometric.scenePosition(col:  n, row: -1),  xScale: -1, zPosition: 2.0),
            WallEntry(position: Isometric.scenePosition(col:  n, row:  n),  xScale: -1, zPosition: CGFloat(2 * n) + 2.0),
            WallEntry(position: Isometric.scenePosition(col: -1, row:  n),  xScale:  1, zPosition: CGFloat(2 * n) + 2.0),
        ]
    }
}
