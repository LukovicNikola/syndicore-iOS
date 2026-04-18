import SpriteKit

/// SKScene za isometrijsku vizualizaciju grada.
///
/// **Layout v2:** 6×6 grid sa octagonal trim (12 corner cutouts) i HQ 2×2 centered.
/// Total buildable slots: 20 (vidi `Isometric.buildableSlotCount`).
///
/// Komunikacija prema SwiftUI-u je callback-ovima:
///   - `onTapHQ`          – korisnik tapnuo bilo koji HQ tile (2×2 region)
///   - `onTapBuilding`    – korisnik tapnuo zauzeti tile
///   - `onTapEmptySlot`   – korisnik tapnuo prazni buildable tile (slot index za BuildSheet)
///   - `onToggleDebug`    – nije callback, ali debug overlay se kontroliše preko `setDebugOverlay(_:)`
final class CityScene: SKScene {

    // MARK: - Callbacks

    var onTapHQ:          (() -> Void)?
    var onTapBuilding:    ((BuildingInfo) -> Void)?
    var onTapEmptySlot:   ((Int) -> Void)?

    // MARK: - Private

    private let worldNode = SKNode()
    private var skyboxNode: SKSpriteNode?

    private let tileSet = CityTileSet.build()
    private var tileMapNode: SKTileMapNode?
    private var selectedTileCoord: (col: Int, row: Int)?

    private var buildings: [BuildingInfo] = []

    /// Debug overlay (cyan tile diamonds + magenta anchor dots) — togglable iz UI-ja.
    private var debugOverlay: DebugGridOverlayNode?

    // MARK: - Visual grid coordinate mapping (6×6 layout)
    //
    // Tile-ovi koji se NE vide (cornerCutouts iz Isometric):
    //   (0,0)(1,0)(0,1)  (4,0)(5,0)(5,1)
    //   (0,4)(0,5)(1,5)  (5,4)(4,5)(5,5)
    //
    // HQ pokriva 2×2 region (2,2)-(3,3) — center grida.
    //
    // Inner ring (12 tile-ova adjacent na HQ):
    //   N:    (2,1) (3,1)
    //   S:    (2,4) (3,4)
    //   W:    (1,2) (1,3)
    //   E:    (4,2) (4,3)
    //   diag: (1,1) (4,1) (1,4) (4,4)
    //
    // Outer ring (8 tile-ova, daleko od HQ-a):
    //   top:    (2,0) (3,0)
    //   bottom: (2,5) (3,5)
    //   left:   (0,2) (0,3)
    //   right:  (5,2) (5,3)
    //
    // Total: 12 inner + 8 outer + 4 HQ = 24 visible tiles (od 36 u 6×6).

    /// Fixed buildings — pozicije zakucane po dizajnu, blizu HQ-a.
    private static let fixedPositions: [BuildingType: (col: Int, row: Int)] = [
        // Inner ring cardinal positions around HQ 2×2
        .OPS_CENTER:    (col: 2, row: 1),   // N
        .RALLY_POINT:   (col: 3, row: 1),   // N
        .BARRACKS:      (col: 1, row: 2),   // W
        .MOTOR_POOL:    (col: 4, row: 2),   // E
        .WAREHOUSE:     (col: 1, row: 3),   // W
        .TRADE_POST:    (col: 4, row: 3),   // E
        .WATCHTOWER:    (col: 2, row: 4),   // S
        .RESEARCH_LAB:  (col: 3, row: 4),   // S
        .WALL:          (col: 1, row: 1),   // NW diagonal
    ]

    /// Flex/resource slot positions — outer ring + 3 diagonal corners za 11 ukupno.
    /// BE slotIndex (0..N-1) mapira u ovaj array.
    private static let resourceSlotPositions: [(col: Int, row: Int)] = [
        (2, 0), (3, 0),                  // top edge
        (4, 1),                          // NE diagonal
        (5, 2), (5, 3),                  // right edge
        (4, 4),                          // SE diagonal
        (3, 5), (2, 5),                  // bottom edge
        (1, 4),                          // SW diagonal
        (0, 3), (0, 2),                  // left edge
    ]

    private func coord(for building: BuildingInfo) -> (col: Int, row: Int)? {
        // Resource buildings (have slotIndex) use resourceSlotPositions
        if let idx = building.slotIndex, idx >= 0, idx < Self.resourceSlotPositions.count {
            return Self.resourceSlotPositions[idx]
        }
        // Fixed buildings look up by type
        return Self.fixedPositions[building.type]
    }

    // MARK: - Lifecycle

    override func didMove(to view: SKView) {
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        scaleMode   = .resizeFill
        backgroundColor = SKColor(red: 0.04, green: 0.04, blue: 0.07, alpha: 1)

        // Skybox kao odvojen background sloj (NE u worldNode da se ne skalira sa world-om)
        let skybox = SKSpriteNode(imageNamed: "hero_skybox_v1")
        skybox.position  = .zero
        skybox.zPosition = -200
        addChild(skybox)
        skyboxNode = skybox

        addChild(worldNode)
        buildTileMap()
        buildWallLayer()
        // layoutWorld() ide u didChangeSize — size je u didMove jos uvek 0
    }

    override func didChangeSize(_ oldSize: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        // Skybox aspect-fill da pokrije ceo viewport bez praznih ivica
        if let skybox = skyboxNode, let tex = skybox.texture {
            let texAspect   = tex.size().width / tex.size().height
            let sceneAspect = size.width / size.height
            if sceneAspect > texAspect {
                skybox.size = CGSize(width: size.width, height: size.width / texAspect)
            } else {
                skybox.size = CGSize(width: size.height * texAspect, height: size.height)
            }
        }
        layoutWorld(viewSize: size)
    }

    // MARK: - Public API

    func configure(with city: City) {
        buildings = city.buildings ?? []
        rebuildBuildingLayer()
    }

    /// Toggle debug grid overlay. Pozvati iz SettingsView ili SpriteAlignmentTestView.
    func setDebugOverlay(_ enabled: Bool) {
        if enabled, debugOverlay == nil {
            let overlay = DebugGridOverlayNode()
            worldNode.addChild(overlay)
            debugOverlay = overlay
        } else if !enabled, let overlay = debugOverlay {
            overlay.removeFromParent()
            debugOverlay = nil
        }
    }

    // MARK: - Layout

    private func layoutWorld(viewSize: CGSize) {
        guard viewSize.width > 0 else { return }

        let n = CGFloat(Isometric.gridSize)
        // 6×6 dijamant: width = 6 × 128 = 768, height = 6 × 64 + zid prostor
        let gridDiamondWidth:  CGFloat = n * Isometric.tileWidth
        let gridDiamondHeight: CGFloat = n * Isometric.tileHeight + 240   // +240 za zidove + UI padding

        let usableW = viewSize.width  - 40
        let usableH = viewSize.height - 200
        let scale = min(usableW / gridDiamondWidth, usableH / gridDiamondHeight, 1.0)
        worldNode.setScale(scale)

        // Centriraj HQ na vertikalnoj sredini ekrana.
        // hqCenterPosition.y = -160 za 6×6 (između tile (2,2) y=-128 i tile (3,3) y=-192)
        // Pomeramo worldNode na +abs(hqCenterPosition.y) * scale + small upward nudge.
        let hqOffsetY = -Isometric.hqCenterPosition.y * scale
        worldNode.position = CGPoint(x: 0, y: hqOffsetY + 40)
    }

    // MARK: - Build Layers

    /// SKTileMapNode (.isometric) ima invertovanu row osu u odnosu na nase Isometric.scenePosition.
    /// Mapa: tmCol = col, tmRow = (gridSize-1) - row.
    private func tmRow(_ row: Int) -> Int { (Isometric.gridSize - 1) - row }

    private func buildTileMap() {
        let n = Isometric.gridSize
        let tileMap = SKTileMapNode(
            tileSet: tileSet,
            columns: n,
            rows: n,
            tileSize: CityTileSet.tileSize
        )
        tileMap.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        // Offset tako da tile (centerCol, centerRow) sedne na hqCenterPosition.
        // Za 6×6 sa hqOrigin (2,2), centar grida je između (2.5, 2.5) tile coord.
        // SKTileMapNode anchor (0.5, 0.5) centrira na (n/2, n/2) tile coord.
        // Za n=6, to je (3, 3). Razlika između (2.5, 2.5) i (3, 3) = (0.5 col, 0.5 row).
        // Trebamo pomeriti tileMap nazad za pola tile-a u col i row smeru.
        let halfTileOffsetX = -CGFloat(0.5 - 0.5) * Isometric.tileWidth / 2  // = 0
        let centerY = -CGFloat(Isometric.gridSize - 1) * Isometric.tileHeight / 2  // tile center y
        tileMap.position = CGPoint(x: halfTileOffsetX, y: centerY + Isometric.hqCenterPosition.y / 2)
        tileMap.zPosition = 0

        // Fill samo BUILDABLE tile-ove (skip HQ region + cornerCutouts)
        guard let emptyGroup = CityTileSet.emptyGroup(in: tileSet) else { return }
        for col in 0..<n {
            for row in 0..<n {
                guard Isometric.isBuildable(col: col, row: row) else { continue }
                tileMap.setTileGroup(emptyGroup, forColumn: col, row: tmRow(row))
            }
        }

        worldNode.addChild(tileMap)
        tileMapNode = tileMap
    }

    private func buildWallLayer() {
        WallLayout.wallPositions().forEach  { worldNode.addChild(WallNode(entry: $0)) }
        WallLayout.pylonPositions().forEach { worldNode.addChild(CornerPylonNode(entry: $0)) }
    }

    private func rebuildBuildingLayer() {
        worldNode.children
            .filter { $0 is BuildingNode || $0 is HQNode }
            .forEach { $0.removeFromParent() }

        // Restore sve buildable tile-ove na empty pre nego sto evaluiramo zauzetost
        let n = Isometric.gridSize
        if let emptyGroup = CityTileSet.emptyGroup(in: tileSet) {
            for col in 0..<n {
                for row in 0..<n {
                    guard Isometric.isBuildable(col: col, row: row) else { continue }
                    tileMapNode?.setTileGroup(emptyGroup, forColumn: col, row: tmRow(row))
                }
            }
        }

        worldNode.addChild(HQNode())

        for building in buildings {
            guard building.type != .HQ else { continue }
            guard let c = coord(for: building) else { continue }
            worldNode.addChild(BuildingNode(building: building, col: c.col, row: c.row))
            // Clear tile samo ako zgrada ima vidljiv content (texture exists ili scaffold)
            let spec = SpriteCatalog.spec(for: building.type)
            if building.isUpgrading || SpriteCatalog.assetExists(spec) {
                tileMapNode?.setTileGroup(nil, forColumn: c.col, row: tmRow(c.row))
            }
        }
    }

    // MARK: - Touch Handling

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first, let tileMap = tileMapNode else { return }
        let locationInWorld = touch.location(in: worldNode)

        // Reset prethodno selected tile
        if let prev = selectedTileCoord,
           let emptyGroup = CityTileSet.emptyGroup(in: tileSet) {
            tileMap.setTileGroup(emptyGroup, forColumn: prev.col, row: tmRow(prev.row))
        }
        selectedTileCoord = nil

        guard let (col, row) = Isometric.tileCoord(at: locationInWorld) else { return }

        if Isometric.isHQ(col: col, row: row) {
            onTapHQ?()
            return
        }

        // Set selected sprite na tapped tile
        if let selectedGroup = CityTileSet.selectedGroup(in: tileSet) {
            tileMap.setTileGroup(selectedGroup, forColumn: col, row: tmRow(row))
        }
        selectedTileCoord = (col, row)

        // Da li neka zgrada zauzima ovaj (col, row)?
        let bldg = buildings.first { b in
            guard b.type != .HQ, let c = coord(for: b) else { return false }
            return c.col == col && c.row == row
        }

        if let bldg {
            onTapBuilding?(bldg)
        } else {
            // Empty slot — pošalji slot index za BuildSheet (Isometric ga zna)
            let slotIdx = Isometric.slot(forCoord: col, row: row) ?? 0
            onTapEmptySlot?(slotIdx)
        }
    }
}
