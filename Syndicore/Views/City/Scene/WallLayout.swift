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

        // Top-left side: col 0..<n, row = -1 (severno od grida, ide od top ka right korneru)
        for col in 0..<n {
            entries.append(WallEntry(
                position: Isometric.scenePosition(col: col, row: -1),
                xScale: 1,
                zPosition: Isometric.zDepth(col: col, row: 0) - 0.5
            ))
        }
        // Top-right side: col = n, row 0..<n (istočno, ide od right ka bottom)
        for row in 0..<n {
            entries.append(WallEntry(
                position: Isometric.scenePosition(col: n, row: row),
                xScale: -1,
                zPosition: Isometric.zDepth(col: n - 1, row: row) + 1.5
            ))
        }
        // Bottom-right side: col 0..<n, row = n (južno, ide od bottom ka left)
        for col in 0..<n {
            entries.append(WallEntry(
                position: Isometric.scenePosition(col: col, row: n),
                xScale: -1,
                zPosition: Isometric.zDepth(col: col, row: n - 1) + 1.5
            ))
        }
        // Bottom-left side: col = -1, row 0..<n (zapadno, ide od left ka top)
        for row in 0..<n {
            entries.append(WallEntry(
                position: Isometric.scenePosition(col: -1, row: row),
                xScale: 1,
                zPosition: Isometric.zDepth(col: 0, row: row) - 0.5
            ))
        }
        return entries
    }

    /// Pyloni se postavljaju na PRAVE uglove dijamanta (midpoint između
    /// susednih wall segmenata), ne na grid koordinate. Tako prirodno
    /// popunjavaju prazninu gde se dve strane perimetra spajaju.
    static func pylonPositions() -> [WallEntry] {
        let n = Isometric.gridSize

        // Midpoints između poslednjeg segmenta jedne strane i prvog segmenta naredne.
        let topWallEnd      = Isometric.scenePosition(col: -1, row: 0)   // bottom-left prva
        let topWallStart    = Isometric.scenePosition(col: 0,  row: -1)  // top-left prva
        let rightWallEnd    = Isometric.scenePosition(col: n - 1, row: -1) // top-left poslednja
        let rightWallStart  = Isometric.scenePosition(col: n,      row: 0)  // top-right prva
        let bottomWallEnd   = Isometric.scenePosition(col: n,      row: n - 1) // top-right poslednja
        let bottomWallStart = Isometric.scenePosition(col: n - 1,  row: n)     // bottom-right prva
        let leftWallEnd     = Isometric.scenePosition(col: 0,  row: n)    // bottom-right poslednja
        let leftWallStart   = Isometric.scenePosition(col: -1, row: n - 1) // bottom-left poslednja

        func midpoint(_ a: CGPoint, _ b: CGPoint) -> CGPoint {
            CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
        }

        return [
            // TOP (back corner) — iza svega
            WallEntry(
                position:  midpoint(topWallEnd, topWallStart),
                xScale:    1,
                zPosition: -5
            ),
            // RIGHT (east corner) — ispred susednih top-left i top-right segmenata
            WallEntry(
                position:  midpoint(rightWallEnd, rightWallStart),
                xScale:   -1,
                zPosition: Isometric.zDepth(col: n - 1, row: 0) + 2.0
            ),
            // BOTTOM (front corner) — ispred svih zidova u frontu
            WallEntry(
                position:  midpoint(bottomWallEnd, bottomWallStart),
                xScale:   -1,
                zPosition: Isometric.zDepth(col: n - 1, row: n - 1) + 3.0
            ),
            // LEFT (west corner) — ispred susednih bottom-left i bottom-right segmenata
            WallEntry(
                position:  midpoint(leftWallEnd, leftWallStart),
                xScale:    1,
                zPosition: Isometric.zDepth(col: 0, row: n - 1) + 2.0
            ),
        ]
    }
}
