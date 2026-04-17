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

    // MARK: - Fixed building order (za vizualni slot mapping)

    private static let fixedOrder: [BuildingType] = [
        .BARRACKS, .MOTOR_POOL, .OPS_CENTER, .WAREHOUSE,
        .WALL, .WATCHTOWER, .RALLY_POINT, .TRADE_POST, .RESEARCH_LAB
    ]

    // MARK: - Lifecycle

    override func didMove(to view: SKView) {
        // VAŽNO: anchorPoint = (0.5, 0.5) → (0,0) je centar ekrana, ne donji-levi ugao
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        scaleMode   = .resizeFill
        backgroundColor = SKColor(red: 0.04, green: 0.04, blue: 0.07, alpha: 1)

        let skybox = SKSpriteNode(imageNamed: "hero_skybox_v1")
        skybox.position  = .zero          // centar ekrana
        skybox.zPosition = -200
        skybox.size      = view.bounds.size
        addChild(skybox)
        skyboxNode = skybox

        addChild(worldNode)

        buildTileLayer()
        buildWallLayer()
        layoutWorld(viewSize: view.bounds.size)
    }

    override func didChangeSize(_ oldSize: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        skyboxNode?.size = size
        layoutWorld(viewSize: size)
    }

    // MARK: - Public API

    func configure(with city: City) {
        buildings = city.buildings ?? []
        rebuildBuildingLayer()
    }

    // MARK: - Layout

    /// Skalira i centrira worldNode tako da iso grid stane u viewport.
    private func layoutWorld(viewSize: CGSize) {
        guard viewSize.width > 0 else { return }

        // Vizualna širina grida (od lvog do desnog ruba sa po pola tile-a extra)
        let gridVisualWidth: CGFloat  = CGFloat(Isometric.gridSize) * Isometric.tileWidth
        // Visina: od vrha grida do dna + malo za zidove
        let gridVisualHeight: CGFloat = CGFloat(Isometric.gridSize) * Isometric.tileHeight + Isometric.tileWidth

        let usableW = viewSize.width  - 40          // 20pt padding sa svake strane
        let usableH = viewSize.height - 240         // rezerva za TopHUD + BottomHUD + TabBar

        let scale = min(usableW / gridVisualWidth, usableH / gridVisualHeight, 1.0)
        worldNode.setScale(scale)

        // Centar iso grida (tile 2,2) → centar scene (= centar ekrana) + malo gore
        // scenePosition(2,2) = (0, -128) u koordinatama worldNode
        let gridCenterInWorld = Isometric.scenePosition(col: 2, row: 2)
        worldNode.position = CGPoint(
            x: -gridCenterInWorld.x * scale,
            y: -gridCenterInWorld.y * scale - 20   // -20 = pomak prema gore (TabBar kompenzacija)
        )
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
            guard let slot = visualSlot(for: building),
                  let coord = Isometric.coord(forSlot: slot) else { continue }
            worldNode.addChild(BuildingNode(building: building, col: coord.col, row: coord.row))
        }
    }

    // MARK: - Slot Mapping

    private func visualSlot(for building: BuildingInfo) -> Int? {
        if let idx = building.slotIndex { return Self.fixedOrder.count + idx }
        return Self.fixedOrder.firstIndex(of: building.type)
    }

    private func building(atSlot slot: Int) -> BuildingInfo? {
        buildings.first { visualSlot(for: $0) == slot }
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

        guard let slot = Isometric.slot(forCoord: col, row: row) else { return }

        if let bldg = building(atSlot: slot) {
            onTapBuilding?(bldg)
        } else {
            onTapEmptySlot?(slot)
        }
    }
}
