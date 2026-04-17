import CoreGraphics

enum WallLayout {
    struct WallEntry {
        let position: CGPoint
        let xScale: CGFloat
        let zPosition: CGFloat
    }

    /// Svi wall entry-ji — 4 stranice × n segmenata + 4 corner filler-a na
    /// pozicijama gde su ranije stajali pyloni. Corner filler-i su obični
    /// WallNode-ovi koji vizuelno spajaju dve stranice u kontinualan zid.
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

        // Corner filler-i — pozicionirani na midpoint-ima gde se dve
        // stranice sastaju. Orijentacija (xScale) matchuje slope stranice
        // koja se nastavlja dalje po iso toku.
        entries.append(contentsOf: cornerFillers(n: n))

        return entries
    }

    private static func cornerFillers(n: Int) -> [WallEntry] {
        func mid(_ a: CGPoint, _ b: CGPoint) -> CGPoint {
            CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
        }

        // TOP corner (sever, između NW i NE) — iza svega.
        let topPos = mid(
            Isometric.scenePosition(col: -1, row:  0),
            Isometric.scenePosition(col:  0, row: -1)
        )
        // RIGHT corner (istok, između NE i SE).
        let rightPos = mid(
            Isometric.scenePosition(col: n - 1, row: -1),
            Isometric.scenePosition(col: n,     row:  0)
        )
        // BOTTOM corner (jug, između SE i SW) — najbliže kameri.
        let bottomPos = mid(
            Isometric.scenePosition(col: n,     row: n - 1),
            Isometric.scenePosition(col: n - 1, row: n)
        )
        // LEFT corner (zapad, između SW i NW).
        let leftPos = mid(
            Isometric.scenePosition(col:  0, row: n),
            Isometric.scenePosition(col: -1, row: n - 1)
        )

        return [
            WallEntry(position: topPos,    xScale:  1, zPosition: -5),
            WallEntry(position: rightPos,  xScale: -1, zPosition: Isometric.zDepth(col: n - 1, row: 0) + 2),
            WallEntry(position: bottomPos, xScale:  1, zPosition: Isometric.zDepth(col: n - 1, row: n - 1) + 3),
            WallEntry(position: leftPos,   xScale: -1, zPosition: Isometric.zDepth(col: 0, row: n - 1) + 2),
        ]
    }

    /// Deprecated — pyloni uklonjeni (Opcija C layout). Ostavljeno radi
    /// lakšeg vraćanja ako korisnik promeni mišljenje.
    static func pylonPositions() -> [WallEntry] { [] }
}
