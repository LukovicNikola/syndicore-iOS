import SpriteKit
import UIKit

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

    /// Pozvan kad neka zgrada zavrsi upgrade timer u UI-ju.
    /// SwiftUI sloj wire-uje na refreshCity() da povuče novi state sa BE-a.
    var onConstructionComplete: (() -> Void)?

    // MARK: - Private

    private let worldNode = SKNode()
    private var skyboxNode: SKSpriteNode?
    private var attachedGestures: [UIGestureRecognizer] = []

    private let tileSet = CityTileSet.build()
    private var tileMapNode: SKTileMapNode?
    private var selectedTileCoord: (col: Int, row: Int)?
    private var selectedTilePulse: SelectedTilePulseNode?
    private var hqNode: HQNode?
    private var queueIndicator: QueueIndicatorNode?

    private var buildings: [BuildingInfo] = []
    /// Aktivan construction queue — koristi se da forsira scaffold prikaz čak i kad
    /// BE ne setuje targetLevel/endsAt na building-u tokom gradnje nove zgrade.
    private var activeQueue: ConstructionQueue?

    /// Building ID-evi koji su prethodno prikazivali scaffold — za fade-in animaciju
    /// kad gradnja završi i scaffold se zameni pravim sprite-om.
    private var scaffoldedBuildingIds: Set<String> = []

    /// Prethodne vrednosti resursa — za tick animaciju (diff prikazujemo iznad HQ-a).
    /// nil pri prvom configure() — ne prikazujemo tick ako još nemamo baseline.
    private var previousResources: Resources?

    /// Debug overlay (cyan tile diamonds + magenta anchor dots) — togglable iz UI-ja.
    private var debugOverlay: DebugGridOverlayNode?

    // MARK: - Camera state

    /// Fiksiran zoom — tunirano u SpriteAlignmentTestView (Zoom tab).
    private static let fixedZoom: CGFloat = 1.76
    private static let fixedPan:  CGPoint = CGPoint(x: 2, y: 20)
    private var baseScale: CGFloat = 1.0

    private let hapticTap: UIImpactFeedbackGenerator = UIImpactFeedbackGenerator(style: .light)
    private let hapticHQ:  UIImpactFeedbackGenerator = UIImpactFeedbackGenerator(style: .medium)

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
    ]

    /// Flex/resource slot positions — outer ring (9 slotova).
    /// BE slotIndex (0..N-1) mapira u ovaj array.
    private static let resourceSlotPositions: [(col: Int, row: Int)] = [
        (2, 0), (3, 0),                  // top edge
        (4, 1),                          // NE diagonal
        (5, 2), (5, 3),                  // right edge
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

        // Skybox — idempotent: ne dodajemo ponovo ako je vec u sceni
        if skyboxNode == nil {
            let skybox = SKSpriteNode(imageNamed: "hero_skybox_v1")
            skybox.position  = .zero
            skybox.zPosition = -200
            addChild(skybox)
            skyboxNode = skybox
        }
        resizeSkybox(to: view.bounds.size)

        // worldNode + tileMap — idempotent: ako je vec dodat (re-present), preskoci
        if worldNode.parent == nil {
            addChild(worldNode)
            buildTileMap()
        }

        // Long-press gesture za tooltip — re-attach na novi view
        attachLongPressGesture(to: view)
        // layoutWorld() ide u didChangeSize — size je u didMove jos uvek 0
    }

    private func attachLongPressGesture(to view: SKView) {
        attachedGestures.forEach { $0.view?.removeGestureRecognizer($0) }
        attachedGestures.removeAll()

        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        longPress.minimumPressDuration = 0.5
        view.addGestureRecognizer(longPress)
        attachedGestures.append(longPress)

        hapticTap.prepare()
        hapticHQ.prepare()
    }

    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began, let view else { return }
        let viewLoc = gesture.location(in: view)
        let sceneLoc = sceneLocation(from: viewLoc, viewSize: view.bounds.size)
        let worldLoc = CGPoint(
            x: (sceneLoc.x - worldNode.position.x) / worldNode.xScale,
            y: (sceneLoc.y - worldNode.position.y) / worldNode.yScale
        )

        guard let (col, row) = Isometric.tileCoord(at: worldLoc) else { return }

        // Pronadji zgradu na tom tile-u (ili HQ)
        let tooltipBuilding: BuildingInfo?
        if Isometric.isHQ(col: col, row: row) {
            tooltipBuilding = buildings.first { $0.type == .HQ }
        } else {
            tooltipBuilding = buildings.first { b in
                guard b.type != .HQ, let c = coord(for: b) else { return false }
                return c.col == col && c.row == row
            }
        }
        guard let building = tooltipBuilding else { return }

        // Ukloni postojeci tooltip ako postoji (single instance)
        worldNode.children.filter { $0 is BuildingTooltipNode }.forEach { $0.removeFromParent() }

        let tooltip = BuildingTooltipNode(building: building)
        let buildingPos = Isometric.isHQ(col: col, row: row)
            ? Isometric.hqCenterPosition
            : Isometric.scenePosition(col: col, row: row)
        tooltip.position = CGPoint(x: buildingPos.x, y: buildingPos.y + Isometric.tileWidth * 1.1)
        tooltip.zPosition = 1500   // iznad svega (iznad selected pulse, debug overlay, itd.)
        worldNode.addChild(tooltip)

        hapticTap.impactOccurred(intensity: 0.7)
    }

    /// Konvertuje tačku iz UIKit view coords (y-down, origin top-left) u scene coords
    /// (y-up, origin na centru view-a zbog scene.anchorPoint = 0.5, 0.5).
    private func sceneLocation(from viewPoint: CGPoint, viewSize: CGSize) -> CGPoint {
        CGPoint(
            x: viewPoint.x - viewSize.width  / 2,
            y: viewSize.height / 2 - viewPoint.y
        )
    }

    override func didChangeSize(_ oldSize: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        resizeSkybox(to: size)
        layoutWorld(viewSize: size)
    }

    private func resizeSkybox(to targetSize: CGSize) {
        guard targetSize.width > 0, targetSize.height > 0,
              let skybox = skyboxNode, let tex = skybox.texture else { return }
        let texSize = tex.size()
        let scaleW = targetSize.width  / texSize.width
        let scaleH = targetSize.height / texSize.height
        let scale  = max(scaleW, scaleH)   // aspect-fill: prekrij ceo ekran
        skybox.size = CGSize(width: texSize.width * scale, height: texSize.height * scale)
    }

    // MARK: - Public API

    func configure(with city: City) {
        buildings = city.buildings ?? []
        activeQueue = city.constructionQueue
        rebuildBuildingLayer()
        spawnResourceTicksIfNeeded(newResources: city.resources)
        updateQueueIndicator(hasQueue: city.constructionQueue != nil)
    }

    /// Show/hide pulsing dot iznad HQ-a — visible kad postoji aktivna gradnja.
    private func updateQueueIndicator(hasQueue: Bool) {
        if hasQueue, queueIndicator == nil {
            let q = QueueIndicatorNode()
            // Iznad gornjeg vrha HQ-a (vrh pyramid + S hologram)
            q.position = CGPoint(
                x: Isometric.hqCenterPosition.x + Isometric.tileWidth * 0.55,
                y: Isometric.hqCenterPosition.y + Isometric.tileWidth * 1.4
            )
            q.zPosition = 950
            worldNode.addChild(q)
            queueIndicator = q
        } else if !hasQueue, let q = queueIndicator {
            q.removeFromParent()
            queueIndicator = nil
        }
    }

    /// Diff vs prethodne resources — prikazuje "+X" tick iznad HQ-a za svaki pozitivan delta.
    private func spawnResourceTicksIfNeeded(newResources: Resources?) {
        guard let new = newResources else { return }
        defer { previousResources = new }

        guard let prev = previousResources else { return }  // prvi load — ne prikazujemo

        // Pozicije iznad HQ-a (gornji centar, sa malim horizontalnim offset-om za 4 resursa)
        // Spawn-ujemo ih sa malim staggerom da se ne preklapaju ako više resursa raste odjednom.
        let basePos = CGPoint(x: Isometric.hqCenterPosition.x,
                              y: Isometric.hqCenterPosition.y + Isometric.tileWidth * 0.9)
        let baseZ = Isometric.hqZDepth + 10

        func tryTick(delta: Double, resource: ResourceTickNode.Resource, offsetX: CGFloat) {
            let amount = Int(delta.rounded())
            guard amount > 0 else { return }
            let pos = CGPoint(x: basePos.x + offsetX, y: basePos.y)
            let tick = ResourceTickNode(amount: amount, resource: resource, at: pos, zPosition: baseZ)
            worldNode.addChild(tick)
        }

        // 4 resursa, svaki na svojoj horizontalnoj poziciji da se ne preklapaju
        tryTick(delta: new.credits - prev.credits, resource: .credits, offsetX: -60)
        tryTick(delta: new.alloys  - prev.alloys,  resource: .alloys,  offsetX: -20)
        tryTick(delta: new.tech    - prev.tech,    resource: .tech,    offsetX:  20)
        tryTick(delta: (new.energy ?? 0) - (prev.energy ?? 0), resource: .energy, offsetX: 60)
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

    /// Primenjuje fiksni zoom + pan na worldNode.
    private func applyTransforms() {
        let effectiveScale = baseScale * Self.fixedZoom
        worldNode.setScale(effectiveScale)

        let hqOffsetY = -Isometric.hqCenterPosition.y * effectiveScale
        worldNode.position = CGPoint(
            x: Self.fixedPan.x,
            y: hqOffsetY + 40 + Self.fixedPan.y
        )
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
        let previousScaffolds = scaffoldedBuildingIds

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

        var newScaffolds: Set<String> = []

        for building in buildings {
            guard building.type != .HQ else { continue }
            guard let c = coord(for: building) else { continue }
            // Forsiramo scaffold ako je ova zgrada u activeQueue — BE za novu zgradu
            // ponekad ne setuje targetLevel/endsAt na building-u, prati samo kroz queue.
            let isInQueue = activeQueue?.buildingId == building.id
            let forceScaffold = isInQueue
            let showsScaffold = forceScaffold || building.isUpgrading

            if showsScaffold { newScaffolds.insert(building.id) }

            let bn = BuildingNode(building: building, col: c.col, row: c.row,
                                  forceScaffold: forceScaffold,
                                  queueEndsAt: forceScaffold ? activeQueue?.endsAt : nil)

            // Fade-in ako je zgrada upravo završila gradnju (bila scaffold, sad nije)
            if !showsScaffold && previousScaffolds.contains(building.id) {
                bn.alpha = 0
                bn.run(.fadeIn(withDuration: 0.5))
            }

            worldNode.addChild(bn)
            // Wire construction-complete callback (samo za upgrading buildings)
            if let progress = bn.progressNode {
                let buildingPos = Isometric.scenePosition(col: c.col, row: c.row)
                progress.onComplete = { [weak self] in
                    self?.handleConstructionComplete(at: buildingPos)
                }
            }
            // Uvek obrisi tile kad zgrada postoji — da tile_empty_v1 ne ostane vidljiv
            // kad je zgrada izgradjena ali nema sprajt asset-a (npr. foundry_v1 fali).
            tileMapNode?.setTileGroup(nil, forColumn: c.col, row: tmRow(c.row))
        }

        scaffoldedBuildingIds = newScaffolds
    }

    /// Pozvan iz ConstructionProgressNode kad timer dođe na 0.
    /// Spawn-uje celebration burst + screen flash + haptic + signalira refresh.
    private func handleConstructionComplete(at buildingPos: CGPoint) {
        // 1. Particle burst u world space-u (na zgradu)
        let burst = CelebrationBurstNode()
        burst.position = buildingPos
        burst.zPosition = 800
        worldNode.addChild(burst)

        // 2. Screen flash (ne u worldNode — fixed full screen)
        let flash = SKShapeNode(rectOf: size)
        flash.fillColor = .white
        flash.strokeColor = .clear
        flash.zPosition = 9999
        flash.alpha = 0.55
        addChild(flash)
        flash.run(.sequence([
            .fadeAlpha(to: 0, duration: 0.45),
            .removeFromParent()
        ]))

        // 3. Haptic notification — success vibe
        let notify = UINotificationFeedbackGenerator()
        notify.prepare()
        notify.notificationOccurred(.success)

        // 4. Signaliziraj SwiftUI sloju da povuče novi state sa BE-a
        onConstructionComplete?()
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
            hapticHQ.impactOccurred()
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
            // Brz scale pulse na tapped building-u (vizuelni feedback) + haptic
            findBuildingNode(for: bldg)?.playTapPulse()
            hapticTap.impactOccurred()
            onTapBuilding?(bldg)
        } else {
            // Empty slot — pošalji slot index za BuildSheet (Isometric ga zna) + light haptic
            hapticTap.impactOccurred(intensity: 0.5)
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
