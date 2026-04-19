import SwiftUI

/// Dev tool: vizuelni editor za tile raspored CityScene-a.
///
/// - **Tap** na tile → opcija za brisanje (postaje cutout) ili vraćanje u grid
/// - **Drag** (pomeri prst > 8pt) → premesti building na slobodan tile (swap)
/// - **Output panel** → kopira novi kod za cornerCutouts + fixedPositions + resourceSlots
struct TileGridEditorView: View {

    // MARK: - Tile role

    enum TileRole: Equatable {
        case hq
        case fixed(BuildingType)
        case resource(Int)   // originalni slot index (za sort u outputu)
        case empty
        case cutout

        var fillColor: Color {
            switch self {
            case .hq:       return Color(red: 0.55, green: 0.20, blue: 1.00)
            case .fixed:    return Color(red: 0.00, green: 0.80, blue: 1.00)
            case .resource: return Color(red: 1.00, green: 0.55, blue: 0.00)
            case .empty:    return Color(white: 0.18)
            case .cutout:   return Color(white: 0.06)
            }
        }

        var shortLabel: String {
            switch self {
            case .hq:              return "HQ"
            case .fixed(let t):    return String(t.rawValue.prefix(3))
            case .resource(let i): return "R\(i)"
            case .empty:           return "·"
            case .cutout:          return ""
            }
        }

        var isMovable: Bool {
            switch self {
            case .fixed, .resource, .empty: return true
            default: return false
            }
        }
    }

    // MARK: - State

    @State private var roles: [GridCoord: TileRole] = TileGridEditorView.initialRoles()
    @State private var dragSource: GridCoord? = nil
    @State private var dragLocation: CGPoint = .zero
    @State private var isDragging = false
    @State private var deleteTarget: GridCoord? = nil
    @State private var showDeleteDialog = false

    // MARK: - Layout

    let tileW: CGFloat = 54
    let tileH: CGFloat = 27
    let n = Isometric.gridSize  // 6

    // MARK: - Initial roles (mirrors CityScene static layout)

    static func initialRoles() -> [GridCoord: TileRole] {
        var result: [GridCoord: TileRole] = [:]
        let n = Isometric.gridSize

        for col in 0..<n {
            for row in 0..<n {
                let gc = GridCoord(col, row)
                if Isometric.cornerCutouts.contains(gc) {
                    result[gc] = .cutout
                } else if Isometric.isHQ(col: col, row: row) {
                    result[gc] = .hq
                } else {
                    result[gc] = .empty
                }
            }
        }

        // Mirrors CityScene.fixedPositions
        let fixed: [(BuildingType, Int, Int)] = [
            (.OPS_CENTER,   2, 1), (.RALLY_POINT,  3, 1),
            (.BARRACKS,     1, 2), (.MOTOR_POOL,   4, 2),
            (.WAREHOUSE,    1, 3), (.TRADE_POST,   4, 3),
            (.WATCHTOWER,   2, 4), (.RESEARCH_LAB, 3, 4),
            (.WALL,         1, 1),
        ]
        for (type, col, row) in fixed {
            let gc = GridCoord(col, row)
            if result[gc]?.isMovable == true { result[gc] = .fixed(type) }
        }

        // Mirrors CityScene.resourceSlotPositions
        let resources: [(Int, Int)] = [
            (2,0),(3,0),(4,1),(5,2),(5,3),(4,4),(3,5),(2,5),(1,4),(0,3),(0,2)
        ]
        for (i, pos) in resources.enumerated() {
            let gc = GridCoord(pos.0, pos.1)
            if result[gc]?.isMovable == true { result[gc] = .resource(i) }
        }

        return result
    }

    // MARK: - Coord helpers

    var allCoords: [GridCoord] {
        (0..<n).flatMap { row in (0..<n).map { GridCoord($0, row) } }
    }

    func tileCenter(_ gc: GridCoord, in size: CGSize) -> CGPoint {
        let isoX = CGFloat(gc.col - gc.row) * tileW / 2
        let isoY = CGFloat(gc.col + gc.row) * tileH / 2
        return CGPoint(x: size.width / 2 + isoX, y: 44 + tileH + isoY)
    }

    func coordAt(_ point: CGPoint, in size: CGSize) -> GridCoord? {
        guard let nearest = allCoords.min(by: {
            let ca = tileCenter($0, in: size), cb = tileCenter($1, in: size)
            return hypot(point.x - ca.x, point.y - ca.y) < hypot(point.x - cb.x, point.y - cb.y)
        }) else { return nil }
        let c = tileCenter(nearest, in: size)
        return hypot(point.x - c.x, point.y - c.y) < tileW ? nearest : nil
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            GeometryReader { geo in
                ZStack {
                    Color(white: 0.04)

                    ForEach(allCoords, id: \.self) { gc in
                        let role = roles[gc] ?? .cutout
                        let isSource = dragSource == gc
                        tileDiamond(role: role, isSource: isSource)
                            .frame(width: tileW, height: tileH)
                            .position(tileCenter(gc, in: geo.size))
                            .opacity(role == .cutout ? 0.3 : 1.0)
                    }

                    // Floating tile while dragging
                    if isDragging, let src = dragSource {
                        let role = roles[src] ?? .empty
                        tileDiamond(role: role, isSource: false)
                            .frame(width: tileW, height: tileH)
                            .scaleEffect(1.2)
                            .position(dragLocation)
                            .allowsHitTesting(false)
                            .zIndex(100)
                    }
                }
                .gesture(
                    DragGesture(minimumDistance: 0, coordinateSpace: .local)
                        .onChanged { val in
                            let moved = max(abs(val.translation.width), abs(val.translation.height))
                            if moved > 8 {
                                if !isDragging {
                                    // Identify drag source
                                    if let gc = coordAt(val.startLocation, in: geo.size),
                                       roles[gc]?.isMovable == true {
                                        dragSource = gc
                                        isDragging = true
                                    }
                                }
                                dragLocation = val.location
                            }
                        }
                        .onEnded { val in
                            let moved = max(abs(val.translation.width), abs(val.translation.height))
                            if moved <= 8 {
                                // Tap → delete dialog
                                if let gc = coordAt(val.startLocation, in: geo.size),
                                   roles[gc] != .some(.hq) {
                                    deleteTarget = gc
                                    showDeleteDialog = true
                                }
                            } else if isDragging, let src = dragSource {
                                // Drop → swap
                                if let dest = coordAt(val.location, in: geo.size),
                                   dest != src,
                                   roles[dest] != .some(.hq),
                                   roles[dest] != .some(.cutout) {
                                    let tmp = roles[src]
                                    roles[src] = roles[dest]
                                    roles[dest] = tmp
                                }
                            }
                            dragSource = nil
                            isDragging = false
                        }
                )
            }
            .frame(maxHeight: .infinity)

            outputPanel
        }
        .confirmationDialog(dialogTitle, isPresented: $showDeleteDialog, titleVisibility: .visible) {
            if let gc = deleteTarget {
                let role = roles[gc] ?? .cutout
                if role == .cutout {
                    Button("Vrati tile u grid") { roles[gc] = .empty }
                } else {
                    Button("Obrisi tile (cutout)", role: .destructive) { roles[gc] = .cutout }
                    if case .fixed = role {
                        Button("Samo ukloni zgradu") { roles[gc] = .empty }
                    }
                    if case .resource = role {
                        Button("Samo ukloni resource slot") { roles[gc] = .empty }
                    }
                }
                Button("Otkaži", role: .cancel) {}
            }
        }
    }

    private var dialogTitle: String {
        guard let gc = deleteTarget else { return "" }
        let label = roles[gc]?.shortLabel ?? "?"
        return "Tile (\(gc.col),\(gc.row)) — \(label)"
    }

    // MARK: - Diamond view

    private func tileDiamond(role: TileRole, isSource: Bool) -> some View {
        ZStack {
            DiamondTileShape()
                .fill(role.fillColor.opacity(isSource ? 0.4 : 0.85))
            DiamondTileShape()
                .stroke(
                    isSource ? Color.yellow : Color.white.opacity(role == .cutout ? 0.12 : 0.35),
                    lineWidth: isSource ? 2 : 0.5
                )
            if role != .cutout {
                Text(role.shortLabel)
                    .font(.system(size: 7, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
            }
        }
    }

    // MARK: - Output panel

    private var outputPanel: some View {
        let code = generatedCode
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("OUTPUT — kopiraj u kod")
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    UIPasteboard.general.string = code
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                        .font(.caption2)
                }
            }
            Text(code)
                .font(.system(.caption2, design: .monospaced))
                .textSelection(.enabled)
                .lineLimit(nil)
                .padding(8)
                .background(Color.black.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .padding(12)
        .background(Color(white: 0.08))
        .frame(maxHeight: 200)
    }

    private var generatedCode: String {
        // cornerCutouts
        let cuts = allCoords
            .filter { roles[$0] == .some(.cutout) }
            .map { "GridCoord(\($0.col), \($0.row))" }
            .joined(separator: ", ")

        // fixedPositions
        let fixedLines = allCoords.compactMap { gc -> String? in
            guard case .fixed(let t) = roles[gc] else { return nil }
            return ".\(t.rawValue): (col: \(gc.col), row: \(gc.row))"
        }.joined(separator: ",\n    ")

        // resourceSlotPositions (sorted by original index)
        var resourceByIdx: [(Int, GridCoord)] = []
        for gc in allCoords {
            if case .resource(let i) = roles[gc] { resourceByIdx.append((i, gc)) }
        }
        resourceByIdx.sort { $0.0 < $1.0 }
        let resLines = resourceByIdx.map { "(\($0.1.col), \($0.1.row))" }.joined(separator: ", ")

        return """
        // Isometric.cornerCutouts:
        [\(cuts)]

        // CityScene.fixedPositions:
        [\(fixedLines)]

        // CityScene.resourceSlotPositions:
        [\(resLines)]
        """
    }
}

// MARK: - Diamond shape

private struct DiamondTileShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to:    CGPoint(x: rect.midX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
        p.closeSubpath()
        return p
    }
}

#Preview {
    TileGridEditorView()
        .frame(height: 600)
        .background(Color.black)
}
