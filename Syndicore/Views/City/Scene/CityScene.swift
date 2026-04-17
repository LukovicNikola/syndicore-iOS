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
    private var tileGrid:  [[TileNode]] = []   // tileGrid[col][row]
    private var selectedTile: TileNode?
    private var buildings: [BuildingInfo] = []

    // MARK: - Visual grid coordinate mapping

    // Visual grid coordinates for each building. These are OUR choices
    // (iOS layout), not dictated by BE. Returns (col, row) for a given
    // BuildingType + optional slotIndex.
    //
    // Strategy: fixed buildings get dedicated positions around HQ.
    // Resource buildings fan out through remaining positions by slotIndex.
    // 4×4 grid (cols/rows 0..3), HQ at (2,2).
    //
    //  (0,0) (1,0) (2,0) (3,0)
    //  (0,1) (1,1) (2,1) (3,1)
    //  (0,2) (1,2) [HQ]  (3,2)
    //  (0,3) (1,3) (2,3) (3,3)
    private static let fixedPositions: [BuildingType: (col: Int, row: Int)] = [
        .RALLY_POINT:   (col: 2, row: 0),   // N of HQ
        .RESEARCH_LAB:  (col: 1, row: 1),   // NW
        .OPS_CENTER:    (col: 2, row: 1),   // directly above HQ
        .MOTOR_POOL:    (col: 3, row: 1),   // NE
        .WALL:          (col: 0, row: 2),   // far left
        .BARRACKS:      (col: 1, row: 2),   // left of HQ
        .WATCHTOWER:    (col: 3, row: 2),   // right of HQ
        .WAREHOUSE:     (col: 1, row: 3),   // SW
        .TRADE_POST:    (col: 2, row: 3),   // S of HQ
    ]

    // Remaining 6 slots for resource buildings (DATA_BANK, FOUNDRY, TECH_LAB, POWER_GRID)
    private static let resourceSlotPositions: [(col: Int, row: Int)] = [
        (0, 0), (1, 0), (3, 0),
        (0, 1), (0, 3), (3, 3),
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
        buildTileLayer()
        buildFloorRing()
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

        // Scale based on gridSize*tileWidth (640) — left/right pylons clip ~35pt at edges
        // which is acceptable. Using gridSize+1 (768) makes the scene too small.
        let diamondW = CGFloat(Isometric.gridSize) * Isometric.tileWidth   // 640
        let diamondH = CGFloat(Isometric.gridSize) * Isometric.tileHeight  // 320

        let usableW = viewSize.width  - 8
        let usableH = viewSize.height - 160  // top HUD ~80 + bottom safe ~80

        let scale = min(usableW / diamondW, usableH / diamondH)
        worldNode.setScale(scale)

        // HQ is at world y = -160 (with tileHeight=80: -(2+2)*40 = -160).
        // Place HQ 8% below screen center so the city feels "closer"/lower to the user.
        let hqTargetY = -viewSize.height * 0.08
        worldNode.position = CGPoint(x: 0, y: hqTargetY + 160 * scale)
    }

    // MARK: - Build Layers

    private func buildTileLayer() {
        let n = Isometric.gridSize
        tileGrid = []
        for col in 0..<n {
            var column: [TileNode] = []
            for row in 0..<n {
                // HQ tile preskačemo — HQNode ga vizualno pokriva
                if !Isometric.isHQ(col: col, row: row) {
                    let tile = TileNode(col: col, row: row)
                    worldNode.addChild(tile)
                    column.append(tile)
                } else {
                    // Placeholder u tileGrid da indeksi ostanu konzistentni
                    let placeholder = TileNode(col: col, row: row)
                    column.append(placeholder)  // nije dodat u worldNode
                }
            }
            tileGrid.append(column)
        }
    }

    /// Adds non-interactive floor tiles at the perimeter ring so the grid looks
    /// flush with the wall interior. Side tiles (col=-1/col=n) are placed deep
    /// behind the wall (zPosition -2) so the wall hides the outward overhang.
    private func buildFloorRing() {
        let n = Isometric.gridSize
        let tileSize = CGSize(width: Isometric.tileWidth, height: Isometric.tileHeight)

        func addFloor(col: Int, row: Int, z: CGFloat) {
            let sprite = SKSpriteNode(imageNamed: "tile_empty_v1")
            sprite.size      = tileSize
            sprite.position  = Isometric.scenePosition(col: col, row: row)
            sprite.zPosition = z
            worldNode.addChild(sprite)
        }

        // Top/bottom: normal z, wall is in front and covers the outer edge cleanly.
        for col in 0..<n {
            addFloor(col: col, row: -1, z: Isometric.zDepth(col: col, row: 0) - 1)
            addFloor(col: col, row: n,  z: Isometric.zDepth(col: col, row: n - 1))
        }
        // Left/right: push to z = -100 (well behind walls) so the tile fills the
        // interior gap but the overhanging edge is hidden behind the wall sprite.
        for row in 0..<n {
            addFloor(col: -1, row: row, z: -100)
            addFloor(col: n,  row: row, z: -100)
        }
    }

    private func buildWallLayer() {
        WallLayout.wallPositions().forEach  { worldNode.addChild(WallNode(entry: $0)) }
        WallLayout.pylonPositions().forEach { worldNode.addChild(CornerPylonNode(entry: $0)) }
    }

    private func rebuildBuildingLayer() {
        worldNode.children
            .filter { $0 is BuildingNode || $0 is HQNode }
            .forEach { $0.removeFromParent() }

        worldNode.addChild(HQNode())

        for building in buildings {
            guard building.type != .HQ else { continue }
            guard let c = coord(for: building) else { continue }
            worldNode.addChild(BuildingNode(building: building, col: c.col, row: c.row))
        }
    }

    // MARK: - Touch Handling

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let locationInWorld = touch.location(in: worldNode)

        selectedTile?.isSelected = false
        selectedTile = nil

        guard let (col, row) = Isometric.tileCoord(at: locationInWorld) else { return }

        let tile = tileGrid[col][row]
        tile.isSelected = true
        selectedTile = tile

        if Isometric.isHQ(col: col, row: row) {
            onTapHQ?()
            return
        }

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
