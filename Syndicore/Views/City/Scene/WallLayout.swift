import CoreGraphics

enum WallLayout {
    struct WallEntry {
        let position: CGPoint
        let xScale: CGFloat
        let zPosition: CGFloat
    }

    static func wallPositions() -> [WallEntry] {
        var entries: [WallEntry] = []
        let n = Isometric.gridSize

        // Top-left diagonal edge: from (-1, -1) toward (n, -1)
        // These go along the top-right edge of the iso diamond
        for col in 0..<n {
            entries.append(WallEntry(
                position: Isometric.scenePosition(col: col, row: -1),
                xScale: 1,
                zPosition: Isometric.zDepth(col: col, row: 0) - 0.5
            ))
        }
        // Top-right diagonal edge: from (n, -1) toward (n, n)
        for row in 0..<n {
            entries.append(WallEntry(
                position: Isometric.scenePosition(col: n, row: row),
                xScale: -1,
                zPosition: Isometric.zDepth(col: n - 1, row: row) + 1.5
            ))
        }
        // Bottom-right diagonal edge: from (n, n) back toward (-1, n)
        for col in 0..<n {
            entries.append(WallEntry(
                position: Isometric.scenePosition(col: col, row: n),
                xScale: -1,
                zPosition: Isometric.zDepth(col: col, row: n - 1) + 1.5
            ))
        }
        // Bottom-left diagonal edge: from (-1, n) back toward (-1, -1)
        for row in 0..<n {
            entries.append(WallEntry(
                position: Isometric.scenePosition(col: -1, row: row),
                xScale: 1,
                zPosition: Isometric.zDepth(col: 0, row: row) - 0.5
            ))
        }
        return entries
    }

    static func pylonPositions() -> [WallEntry] {
        let n = Isometric.gridSize
        // Four corners of the iso diamond
        return [
            WallEntry(position: Isometric.scenePosition(col: -1, row: -1), xScale:  1, zPosition: -1.0),                   // TOP  (back)
            WallEntry(position: Isometric.scenePosition(col:  n, row: -1), xScale: -1, zPosition: CGFloat(n) + 0.5),        // RIGHT
            WallEntry(position: Isometric.scenePosition(col:  n, row:  n), xScale: -1, zPosition: CGFloat(2 * n) + 1.0),    // BOTTOM (front)
            WallEntry(position: Isometric.scenePosition(col: -1, row:  n), xScale:  1, zPosition: CGFloat(n) + 0.5),        // LEFT
        ]
    }
}
