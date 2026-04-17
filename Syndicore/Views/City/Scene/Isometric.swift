import CoreGraphics

/// Izometrijska matematika za CityScene — 2:1 projekcija, 5×5 grid.
enum Isometric {
    static let tileWidth:  CGFloat = 128
    static let tileHeight: CGFloat = 64
    static let gridSize:   Int     = 5
    static let hqCoord: (col: Int, row: Int) = (2, 2)

    /// Grid coord → scene pozicija (relative to worldLayer center).
    static func scenePosition(col: Int, row: Int) -> CGPoint {
        CGPoint(
            x: CGFloat(col - row) * tileWidth  / 2,
            y: -CGFloat(col + row) * tileHeight / 2
        )
    }

    /// Tap u scene space → grid coord (za tap detection).
    static func tileCoord(at point: CGPoint) -> (col: Int, row: Int)? {
        let fx =  point.x / (tileWidth  / 2)
        let fy = -point.y / (tileHeight / 2)
        let col = Int(((fx + fy) / 2).rounded())
        let row = Int(((fy - fx) / 2).rounded())
        guard col >= 0, col < gridSize, row >= 0, row < gridSize else { return nil }
        return (col, row)
    }

    /// Z-position za iso depth sort (veće = bliže kameri).
    static func zDepth(col: Int, row: Int) -> CGFloat {
        CGFloat(col + row)
    }

    static func isHQ(col: Int, row: Int) -> Bool {
        col == hqCoord.col && row == hqCoord.row
    }

    /// Slot index (0-23) → (col, row), preskačući HQ.
    static func coord(forSlot slot: Int) -> (col: Int, row: Int)? {
        var index = 0
        for row in 0..<gridSize {
            for col in 0..<gridSize {
                if isHQ(col: col, row: row) { continue }
                if index == slot { return (col, row) }
                index += 1
            }
        }
        return nil
    }

    /// (col, row) → slot index (nil ako je HQ ili van grida).
    static func slot(forCoord col: Int, row: Int) -> Int? {
        guard col >= 0, col < gridSize, row >= 0, row < gridSize else { return nil }
        guard !isHQ(col: col, row: row) else { return nil }
        var index = 0
        for r in 0..<gridSize {
            for c in 0..<gridSize {
                if isHQ(col: c, row: r) { continue }
                if c == col && r == row { return index }
                index += 1
            }
        }
        return nil
    }
}
