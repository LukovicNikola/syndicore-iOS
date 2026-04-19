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
    private var selectedTilePulse: SelectedTilePulseNode?
    private var hqNode: HQNode?

    private var buildings: [BuildingInfo] = []

    /// Debug overlay (cyan tile diamonds + magenta anchor dots) — togglable iz UI-ja.
    private var debugOverlay: DebugGridOverlayNode?

    // MARK: - Camera state (zoom + pan)

    /// Default zoom i pan — tunirani u SpriteAlignmentTestView (Zoom tab).
    private static let defaultZoom: CGFloat = 1.22
    private static let defaultPan:  CGPoint  = CGPoint(x: -2, y: 44)
    private static let minZoom: CGFloat = 0.7   // dovoljno daleko da se vidi ceo grid + walls
    private static let maxZoom: CGFloat = 3.5   // dovoljno blizu za detalje pojedinačnog tile-a

    private var userZoom: CGFloat = CityScene.defaultZoom
    private var userPan: CGPoint  = CityScene.defaultPan
    private var baseScale: CGFloat = 1.0  // izracunato u layoutWorld, fit-to-view bez zoom-a

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

        // Skybox — fiksno u scene root-u, ne pomiče se sa zoom/pan-om
        let skybox = SKSpriteNode(imageNamed: "hero_skybox_v1")
        skybox.position  = .zero
        skybox.zPosition = -200
        addChild(skybox)
        skyboxNode = skybox
        resizeSkybox(to: view.bounds.size)

        addChild(worldNode)
        buildTileMap()
        attachCameraGestures(to: view)
        // layoutWorld() ide u didChangeSize — size je u didMove jos uvek 0
    }

    /// Pinch + pan gesture recognizers za camera zoom/pan na CityScene.
    private func attachCameraGestures(to view: SKView) {
        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        view.addGestureRecognizer(pinch)

        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        pan.minimumNumberOfTouches = 2  // 2 prsta za pan da ne ometa tap detection
        pan.maximumNumberOfTouches = 2
        view.addGestureRecognizer(pan)
    }

    @objc private func handlePinch(_ gesture: UIPinchGestureRecognizer) {
        guard gesture.state == .changed || gesture.state == .ended else { return }
        let newZoom = userZoom * gesture.scale
        userZoom = max(Self.minZoom, min(Self.maxZoom, newZoom))
        gesture.scale = 1.0
        layoutWorld(viewSize: size)
    }

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard let view else { return }
        let translation = gesture.translation(in: view)
        if gesture.state == .changed {
            // SpriteKit ima y-up, UIKit y-down — invertuj y translaciju
            userPan.x += translation.x
            userPan.y -= translation.y
            clampPan()
            gesture.setTranslation(.zero, in: view)
            applyTransforms()
        }
    }

    /// Sprečava da user pan-ovima gurne grad potpuno van ekrana.
    /// Limit zavisi od trenutnog zoom-a — što je veći zoom, toleriše veći pan offset.
    private func clampPan() {
        // Pri zoom 1.0 → ±150px max u svakom smeru. Pri zoom 3.5× → ±525px.
        // Formula: max pan = 150 × userZoom. Tako se pri zoom-out ne može pomerati,
        // a pri zoom-in se može slobodno istraživati ivice.
        let maxPan: CGFloat = 150 * userZoom
        userPan.x = max(-maxPan, min(maxPan, userPan.x))
        userPan.y = max(-maxPan, min(maxPan, userPan.y))
    }

    override func didChangeSize(_ oldSize: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        resizeSkybox(to: size)
        layoutWorld(viewSize: size)
    }

    private func resizeSkybox(to targetSize: CGSize) {
        guard targetSize.width > 0, targetSize.height > 0,
              let skybox = skyboxNode, let tex = skybox.texture else { return }
        let texAspect = tex.size().width / tex.size().height
        // Uvek skalirati na širinu ekrana — ceo zid (levo/desno) mora biti vidljiv.
        // Ako je slika viša od ekrana, donji deo preseče safe area (nevidljivo).
        // Ako je kraća, tamna pozadina ispod se vidi — ista boja kao backgroundColor.
        skybox.size = CGSize(width: targetSize.width, height: targetSize.width / texAspect)
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

    /// Izracunava baseScale (fit grid u view bez zoom-a) i poziva applyTransforms.
    /// Pozvati kad god se size promeni ILI userZoom promeni (pinch).
    private func layoutWorld(viewSize: CGSize) {
        guard viewSize.width > 0 else { return }

        let n = CGFloat(Isometric.gridSize)
        // 6×6 dijamant: width = 6 × 128 = 768, height = 6 × 64 + zid prostor
        let gridDiamondWidth:  CGFloat = n * Isometric.tileWidth
        let gridDiamondHeight: CGFloat = n * Isometric.tileHeight + 240

        let usableW = viewSize.width  - 40
        let usableH = viewSize.height - 200
        baseScale = min(usableW / gridDiamondWidth, usableH / gridDiamondHeight, 1.0)

        applyTransforms()
    }

    /// Primenjuje (baseScale × userZoom) na worldNode + (basePosition + userPan).
    /// Centriraj HQ na vertikalnoj sredini ekrana, pa dodaj user pan offset.
    private func applyTransforms() {
        let effectiveScale = baseScale * userZoom
        worldNode.setScale(effectiveScale)

        let hqOffsetY = -Isometric.hqCenterPosition.y * effectiveScale
        worldNode.position = CGPoint(
            x: userPan.x,
            y: hqOffsetY + 40 + userPan.y
        )
    }

    /// Reset zoom + pan na default vrednosti. Korisno za "recenter" dugme ili double-tap.
    func resetCamera() {
        userZoom = Self.defaultZoom
        userPan  = Self.defaultPan
        layoutWorld(viewSize: size)
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
        // SKTileMapNode anchor (0.5, 0.5) → centerOfTile(c, r) = position + offset_for(c, r)
        // gde je offset_for(c, r) = ((c + r - (n-1)) * tileWidth/2, (r - c) * tileHeight/2)
        //
        // Hocemo da scenePosition(2, 2) = (0, -128) za 6×6 mapira na
        // SKTileMapNode (col=2, row=tmRow(2)=3).
        // offset_for(2, 3) = ((2+3-5)*64, (3-2)*32) = (0, 32)
        // => tileMap.position = (0, -128) - (0, 32) = (0, -160) = hqCenterPosition.y ✓
        //
        // Generalno: tileMap.position.y = hqCenterPosition.y centrira grid na HQ region.
        tileMap.position = CGPoint(x: 0, y: Isometric.hqCenterPosition.y)
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

        let hq = HQNode()
        worldNode.addChild(hq)
        hqNode = hq

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

        // Reset prethodno selected tile + HQ selected stanje + pulse overlay
        if let prev = selectedTileCoord,
           let emptyGroup = CityTileSet.emptyGroup(in: tileSet) {
            tileMap.setTileGroup(emptyGroup, forColumn: prev.col, row: tmRow(prev.row))
        }
        selectedTileCoord = nil
        selectedTilePulse?.removeFromParent()
        selectedTilePulse = nil
        hqNode?.setSelected(false)

        guard let (col, row) = Isometric.tileCoord(at: locationInWorld) else { return }

        if Isometric.isHQ(col: col, row: row) {
            hqNode?.setSelected(true)
            onTapHQ?()
            return
        }

        // Set selected sprite na tapped tile
        if let selectedGroup = CityTileSet.selectedGroup(in: tileSet) {
            tileMap.setTileGroup(selectedGroup, forColumn: col, row: tmRow(row))
        }
        selectedTileCoord = (col, row)

        // Pulsing cyan diamond overlay iznad selected tile-a
        let pulsePos = Isometric.scenePosition(col: col, row: row)
        let pulseZ = Isometric.zDepth(col: col, row: row) + 0.05
        let pulse = SelectedTilePulseNode(at: pulsePos, zPosition: pulseZ)
        worldNode.addChild(pulse)
        selectedTilePulse = pulse

        // Da li neka zgrada zauzima ovaj (col, row)?
        let bldg = buildings.first { b in
            guard b.type != .HQ, let c = coord(for: b) else { return false }
            return c.col == col && c.row == row
        }

        if let bldg {
            // Brz scale pulse na tapped building-u (vizuelni feedback)
            findBuildingNode(for: bldg)?.playTapPulse()
            onTapBuilding?(bldg)
        } else {
            // Empty slot — pošalji slot index za BuildSheet (Isometric ga zna)
            let slotIdx = Isometric.slot(forCoord: col, row: row) ?? 0
            onTapEmptySlot?(slotIdx)
        }
    }

    /// Pomocni — pronalazi BuildingNode u sceni za dati BuildingInfo (poredi po id-u).
    private func findBuildingNode(for building: BuildingInfo) -> BuildingNode? {
        for child in worldNode.children {
            if let bn = child as? BuildingNode, bn.building.id == building.id {
                return bn
            }
        }
        return nil
    }
}
