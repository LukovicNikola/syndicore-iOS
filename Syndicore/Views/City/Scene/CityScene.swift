import SpriteKit

/// SKScene za isometrijsku vizualizaciju grada (5×5 grid + perimetarski zidovi).
///
/// Komunikacija prema SwiftUI-u je isključivo callback-ovima:
///   - `onTapHQ`          – korisnik tapnuo HQ tile
///   - `onTapBuilding`    – korisnik tapnuo tile na kome stoji zgrada
///   - `onTapEmptySlot`   – korisnik tapnuo prazni slot (slot index za BuildSheet)
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

    // MARK: - Visual grid coordinate mapping

    // Visual grid coordinates for each building. These are OUR choices
    // (iOS layout), not dictated by BE. Returns (col, row) for a given
    // BuildingType + optional slotIndex.
    //
    // 5×5 grid (cols/rows 0..4), HQ na (2,2) = centar.
    // 9 fixed (8 u inner ring + WALL) + 15 flex = 24 buildable.
    //
    //  (0,0) (1,0) (2,0) (3,0) (4,0)
    //  (0,1) (1,1) (2,1) (3,1) (4,1)
    //  (0,2) (1,2) [HQ]  (3,2) (4,2)
    //  (0,3) (1,3) (2,3) (3,3) (4,3)
    //  (0,4) (1,4) (2,4) (3,4) (4,4)
    private static let fixedPositions: [BuildingType: (col: Int, row: Int)] = [
        .OPS_CENTER:    (col: 1, row: 1),   // NW od HQ
        .RALLY_POINT:   (col: 2, row: 1),   // N od HQ
        .WATCHTOWER:    (col: 3, row: 1),   // NE od HQ
        .BARRACKS:      (col: 1, row: 2),   // W od HQ
        .MOTOR_POOL:    (col: 3, row: 2),   // E od HQ
        .WAREHOUSE:     (col: 1, row: 3),   // SW od HQ
        .RESEARCH_LAB:  (col: 2, row: 3),   // S od HQ
        .TRADE_POST:    (col: 3, row: 3),   // SE od HQ
        .WALL:          (col: 2, row: 0),   // daleki sever
    ]

    // 15 outer-ring slotova za flex/resource buildings.
    private static let resourceSlotPositions: [(col: Int, row: Int)] = [
        (0, 0), (1, 0),         (3, 0), (4, 0),
        (0, 1),                                 (4, 1),
        (0, 2),                                 (4, 2),
        (0, 3),                                 (4, 3),
        (0, 4), (1, 4), (2, 4), (3, 4), (4, 4),
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

        // Skybox as a separate background layer, NOT inside worldNode,
        // and NOT scaled by world scale.
        let skybox = SKSpriteNode(imageNamed: "hero_skybox_v1")
        skybox.position  = .zero
        skybox.zPosition = -200
        addChild(skybox)
        skyboxNode = skybox

        addChild(worldNode)
        buildTileMap()
        buildWallLayer()
        // Do NOT call layoutWorld here — size may still be 0.
        // didChangeSize will fire with the real size.
    }

    override func didChangeSize(_ oldSize: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        // Skybox covers full scene. Use aspect fill (scale to max dim)
        // so there's no empty area at edges.
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

    // MARK: - Layout

    private func layoutWorld(viewSize: CGSize) {
        guard viewSize.width > 0 else { return }

        let gridDiamondWidth:  CGFloat = CGFloat(Isometric.gridSize) * Isometric.tileWidth
        let gridDiamondHeight: CGFloat = CGFloat(Isometric.gridSize) * Isometric.tileHeight + 200

        let usableW = viewSize.width  - 40
        let usableH = viewSize.height - 200
        let scale = min(usableW / gridDiamondWidth, usableH / gridDiamondHeight, 1.0)
        worldNode.setScale(scale)

        // Center grid vertically in usable area.
        // scenePosition(2,2) = (0, -128). We want HQ at screen center.
        // So translate worldNode by +128 * scale on Y.
        worldNode.position = CGPoint(x: 0, y: 128 * scale + 40)  // +40 = slight upward nudge
    }

    // MARK: - Build Layers

    // MARK: - Tile map coordinate conversion
    //
    // SKTileMapNode (.isometric) has its row axis inverted relative to our
    // Isometric.scenePosition formula. Measured via centerOfTile(atColumn:row:):
    //   tileMap col step: (+64, -32) — same as our col direction ✓
    //   tileMap row step: (+64, +32) — OPPOSITE to our row direction ✗
    //
    // With tileMap.position = (0, -128), the mapping that aligns a grid tile
    // at Isometric.scenePosition(col, row) with the tileMap cell is:
    //   tmCol = col
    //   tmRow = (gridSize - 1) - row   (i.e. row axis flip)
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
        // Offset so that tile (2,2) lands on Isometric.scenePosition(2,2) = (0,-128)
        tileMap.position = CGPoint(x: 0, y: -128)
        tileMap.zPosition = 0

        // Fill all tiles with empty group, except HQ center tile
        guard let emptyGroup = CityTileSet.emptyGroup(in: tileSet) else { return }
        for col in 0..<n {
            for row in 0..<n {
                if Isometric.isHQ(col: col, row: row) { continue }
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

        // Restore all non-HQ tiles to empty before re-evaluating which are occupied
        let n = Isometric.gridSize
        if let emptyGroup = CityTileSet.emptyGroup(in: tileSet) {
            for col in 0..<n {
                for row in 0..<n {
                    if Isometric.isHQ(col: col, row: row) { continue }
                    tileMapNode?.setTileGroup(emptyGroup, forColumn: col, row: tmRow(row))
                }
            }
        }

        worldNode.addChild(HQNode())

        for building in buildings {
            guard building.type != .HQ else { continue }
            guard let c = coord(for: building) else { continue }
            worldNode.addChild(BuildingNode(building: building, col: c.col, row: c.row))
            // Clear tile only if the building has visible content (texture exists or scaffold).
            // If neither exists, tile stays visible so the slot doesn't become a dark hole.
            let hasTexture = UIImage(named: building.type.rawValue.lowercased() + "_v1") != nil
            if building.isUpgrading || hasTexture {
                tileMapNode?.setTileGroup(nil, forColumn: c.col, row: tmRow(c.row))
            }
        }
    }

    // MARK: - Touch Handling

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first, let tileMap = tileMapNode else { return }
        let locationInWorld = touch.location(in: worldNode)

        // Reset previously selected tile
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

        // Set selected sprite on tapped tile
        if let selectedGroup = CityTileSet.selectedGroup(in: tileSet) {
            tileMap.setTileGroup(selectedGroup, forColumn: col, row: tmRow(row))
        }
        selectedTileCoord = (col, row)

        // Find if any building occupies this (col, row)
        let bldg = buildings.first { b in
            guard b.type != .HQ, let c = coord(for: b) else { return false }
            return c.col == col && c.row == row
        }

        if let bldg {
            onTapBuilding?(bldg)
        } else {
            // Empty slot — derive a "slot number" so BuildSheet can show
            // which flex slot is being built into. For now pass 0;
            // proper slot derivation is a later step.
            onTapEmptySlot?(0)
        }
    }
}
