import SpriteKit
import UIKit

// MARK: - EntityComposite

/// Holds references to all nodes that make up one map entity (sprite + halo + nameplate).
/// Each component lives in its own scene layer; removeFromScene() cleans all three.
private struct EntityComposite {
    let sprite:    SKSpriteNode
    let halo:      SKSpriteNode?
    let nameplate: SKNode?

    func removeFromScene() {
        sprite.removeFromParent()
        halo?.removeFromParent()
        nameplate?.removeFromParent()
    }
}

// MARK: - MapScene

final class MapScene: SKScene {

    // MARK: - Layout constants

    /// On-screen tile rendering size (SpriteKit points). Source texture is 1024×1024;
    /// diamond bounding box is 1024×867 px → height = 256 * (867/1024) ≈ 216 pt.
    /// Using native aspect ratio eliminates the transparent-margin gaps between tiles.
    static let isoTileW: CGFloat = 256
    static let isoTileH: CGFloat = 216

    /// Offset so BE coord (0,0) maps to the center of the 201×201 tilemap.
    private static let halfMap  = 100
    private static let mapCount = halfMap * 2 + 1   // 201

    private static let minCamScale: CGFloat = 1.0
    private static let maxCamScale: CGFloat = 12.0
    private static let overviewThreshold: CGFloat = 5.0
    private static let detailSnapScale:   CGFloat = 3.0
    private static let overviewSnapScale: CGFloat = 7.0

    // MARK: - Asset pools

    private static let decoratorPool: [String] = {
        ["debris", "container", "neon", "scrap"].flatMap { cat in
            (1...4).map { "decorator_\(cat)_0\($0)" }
        }
    }()

    /// entity_ruins_04 is a .dataset (tiff), not an imageset — skip it.
    private static let ruinsPool = ["entity_ruins_01", "entity_ruins_02", "entity_ruins_03"]

    // MARK: - Scene layers

    private let cameraNode     = SKCameraNode()
    private let tileMapNode:  SKTileMapNode
    private let tileGroup:    SKTileGroup
    private let decoratorLayer = SKNode()   // z =  5
    private let haloLayer      = SKNode()   // z = 10
    private let selectionLayer = SKNode()   // z = 12
    private let entityLayer    = SKNode()   // z = 15
    private let nameplateLayer = SKNode()   // z = 20
    private let movementLayer  = SKNode()   // z = 50

    // MARK: - Mutable state

    private var tiles: [MapTile] = []
    private var entityComposites:  [String: EntityComposite]  = [:]
    private var decoratorNodes:    [String: SKSpriteNode]     = [:]
    private var movementLineNodes: [String: MovementLineNode] = [:]
    /// Tracks which (col,row) cells have a tile group set — for O(loaded) reset.
    private var setTileCoords: Set<String> = []

    private var lastFetchCenter = (cx: 0, cy: 0)
    private let fetchThreshold  = 10
    private var hasCenteredOnOwnCity = false

    private var currentLOD: LOD = .detail
    private var boundsMin = CGPoint.zero
    private var boundsMax = CGPoint.zero

    private var pinchGesture: UIPinchGestureRecognizer?
    private var panGesture:   UIPanGestureRecognizer?

    // MARK: - Ownership (set by MapView before each loadTiles call)

    /// "x,y" key of the player's own city tile — gets cyan halo.
    var ownCityKey:    String?
    /// Player IDs of syndikat allies — their cities get gold halo.
    var allyPlayerIds: Set<String> = []

    // MARK: - Callbacks

    var onTileTapped:    ((MapTile) -> Void)?
    var onViewportMoved: ((Int, Int) -> Void)?
    /// Called when the user performs a clear pinch-out gesture — used to navigate
    /// back to EmpireOverviewView without a dedicated back button.
    var onPinchOut: (() -> Void)?

    // MARK: - LOD

    enum LOD { case detail, overview }

    // MARK: - Init

    override init() {
        let tileSize = CGSize(width: Self.isoTileW, height: Self.isoTileH)
        let tex      = SKTexture(imageNamed: "tile_fringe_base")
        let def      = SKTileDefinition(texture: tex, size: tileSize)
        let group    = SKTileGroup(tileDefinition: def)
        tileGroup    = group

        let tileSet  = SKTileSet(tileGroups: [group])
        tileSet.type = .isometric

        tileMapNode = SKTileMapNode(
            tileSet: tileSet,
            columns: Self.mapCount,
            rows:    Self.mapCount,
            tileSize: tileSize
        )
        tileMapNode.anchorPoint       = CGPoint(x: 0.5, y: 0.5)
        tileMapNode.position          = .zero
        tileMapNode.enableAutomapping = false

        super.init(size: .zero)
    }

    required init?(coder: NSCoder) { fatalError("MapScene is code-only") }

    // MARK: - Scene lifecycle

    override func didMove(to view: SKView) {
        backgroundColor = SKColor(red: 0.04, green: 0.04, blue: 0.07, alpha: 1)
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        scaleMode   = .resizeFill

        tileMapNode.zPosition = 0
        addChild(tileMapNode)

        decoratorLayer.zPosition  = 5
        haloLayer.zPosition       = 10
        selectionLayer.zPosition  = 12
        entityLayer.zPosition     = 15
        nameplateLayer.zPosition  = 20
        movementLayer.zPosition   = 50
        for layer in [decoratorLayer, haloLayer, selectionLayer,
                      entityLayer, nameplateLayer, movementLayer] {
            addChild(layer)
        }

        camera = cameraNode
        addChild(cameraNode)
        // Center camera on BE origin — tile (halfMap, halfMap) in tilemap space
        let localOrigin = tileMapNode.centerOfTile(atColumn: Self.halfMap, row: Self.halfMap)
        cameraNode.position = tileMapNode.convert(localOrigin, to: self)
        cameraNode.setScale(8.0)   // shows ~12 tiles wide on a standard iPhone

        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        view.addGestureRecognizer(pinch)
        pinchGesture = pinch

        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        pan.minimumNumberOfTouches = 1
        pan.maximumNumberOfTouches = 1
        view.addGestureRecognizer(pan)
        panGesture = pan
    }

    override func willMove(from view: SKView) {
        if let g = pinchGesture { view.removeGestureRecognizer(g); pinchGesture = nil }
        if let g = panGesture   { view.removeGestureRecognizer(g); panGesture   = nil }
    }

    // MARK: - Public API

    /// Full clear — call on world switch (Crystal Implosion).
    func reset() {
        tiles = []
        lastFetchCenter = (0, 0)
        hasCenteredOnOwnCity = false

        entityComposites.values.forEach  { $0.removeFromScene() }
        entityComposites.removeAll()

        decoratorNodes.values.forEach    { $0.removeFromParent() }
        decoratorNodes.removeAll()

        movementLineNodes.values.forEach { $0.removeFromParent() }
        movementLineNodes.removeAll()

        selectionLayer.removeAllChildren()

        // Clear only the cells we actually set — O(loaded) not O(201²)
        for coordKey in setTileCoords {
            let parts = coordKey.split(separator: ",")
            guard parts.count == 2,
                  let col = Int(parts[0]),
                  let row = Int(parts[1]) else { continue }
            tileMapNode.setTileGroup(nil, forColumn: col, row: row)
        }
        setTileCoords.removeAll()
    }

    func loadTiles(_ newTiles: [MapTile], center: (cx: Int, cy: Int)) {
        lastFetchCenter = center
        tiles = newTiles

        let newKeys = Set(newTiles.map { tileKey($0.x, $0.y) })

        // Remove stale entities / decorators no longer in viewport
        for k in Array(entityComposites.keys) where !newKeys.contains(k) {
            entityComposites[k]?.removeFromScene()
            entityComposites.removeValue(forKey: k)
        }
        for k in Array(decoratorNodes.keys) where !newKeys.contains(k) {
            decoratorNodes[k]?.removeFromParent()
            decoratorNodes.removeValue(forKey: k)
        }

        for tile in newTiles {
            let k          = tileKey(tile.x, tile.y)
            let (col, row) = mapCoord(tile.x, tile.y)
            let scenePos   = scenePosition(col: col, row: row)

            // 1. Base tile group
            tileMapNode.setTileGroup(tileGroup, forColumn: col, row: row)
            setTileCoords.insert("\(col),\(row)")

            let hasEntity = tile.hasOccupant

            // 2. Decorator (only on empty tiles, seeded so same tile always same deco)
            if !hasEntity && decoratorNodes[k] == nil && shouldDecorate(tile.x, tile.y) {
                let dec = buildDecorator(x: tile.x, y: tile.y, at: scenePos)
                decoratorLayer.addChild(dec)
                decoratorNodes[k] = dec
            }

            // 3. Entity composite (halo + sprite + nameplate)
            if hasEntity && entityComposites[k] == nil {
                let composite = buildEntityComposite(tile: tile, at: scenePos)
                entityLayer.addChild(composite.sprite)
                if let h = composite.halo      { haloLayer.addChild(h) }
                if let p = composite.nameplate { nameplateLayer.addChild(p) }
                entityComposites[k] = composite
            }
        }

        // On first load, snap camera to player's own city rather than BE origin (0,0)
        if !hasCenteredOnOwnCity, let key = ownCityKey {
            let parts = key.split(separator: ",")
            if parts.count == 2, let bx = Int(parts[0]), let by = Int(parts[1]) {
                let (col, row) = mapCoord(bx, by)
                cameraNode.position = scenePosition(col: col, row: row)
                hasCenteredOnOwnCity = true
            }
        }

        updateCameraBounds()
        applyLOD()
    }

    func setMovements(_ movements: [TroopMovement]) {
        let activeIds = Set(movements.map { $0.id })

        for (id, node) in movementLineNodes where !activeIds.contains(id) {
            node.removeFromParent()
            movementLineNodes.removeValue(forKey: id)
        }
        for movement in movements {
            guard movementLineNodes[movement.id] == nil else { continue }
            let (sc, sr) = mapCoord(movement.from.x, movement.from.y)
            let (ec, er) = mapCoord(movement.to.x,   movement.to.y)
            let line = MovementLineNode(
                movement: movement,
                start: scenePosition(col: sc, row: sr),
                end:   scenePosition(col: ec, row: er)
            )
            movementLayer.addChild(line)
            movementLineNodes[movement.id] = line
        }
    }

    // MARK: - Coordinate helpers

    private func tileKey(_ x: Int, _ y: Int) -> String { "\(x),\(y)" }

    private func mapCoord(_ x: Int, _ y: Int) -> (col: Int, row: Int) {
        (col: x + Self.halfMap, row: y + Self.halfMap)
    }

    private func scenePosition(col: Int, row: Int) -> CGPoint {
        let local = tileMapNode.centerOfTile(atColumn: col, row: row)
        return tileMapNode.convert(local, to: self)
    }

    // MARK: - Seeded deterministic random

    /// Hash of (x, y, salt) — same inputs always produce the same output.
    private func seededInt(_ x: Int, _ y: Int, _ salt: Int = 0) -> Int {
        var h = x &* 374761393 &+ y &* 668265263 &+ salt &* 2246822519
        h = (h ^ (h >> 13)) &* 1274126177
        return abs(h ^ (h >> 16))
    }

    private func shouldDecorate(_ x: Int, _ y: Int) -> Bool {
        seededInt(x, y) % 10 < 6   // ~60 % coverage
    }

    // MARK: - Decorator builder

    private func buildDecorator(x: Int, y: Int, at pos: CGPoint) -> SKSpriteNode {
        let name = Self.decoratorPool[seededInt(x, y, 1) % Self.decoratorPool.count]
        let node = SKSpriteNode(imageNamed: name)
        node.size = CGSize(width: 110, height: 110)
        let ox = CGFloat(seededInt(x, y, 2) % 41 - 20)   // ±20 pt offset
        let oy = CGFloat(seededInt(x, y, 3) % 25 - 12)
        node.position = CGPoint(x: pos.x + ox, y: pos.y + oy)
        node.alpha = 0.85
        return node
    }

    // MARK: - Entity composite builder

    private func buildEntityComposite(tile: MapTile, at pos: CGPoint) -> EntityComposite {
        EntityComposite(
            sprite:    buildEntitySprite(tile: tile, at: pos),
            halo:      buildHalo(tile: tile, at: pos),
            nameplate: buildNameplate(tile: tile, at: pos)
        )
    }

    private func buildEntitySprite(tile: MapTile, at pos: CGPoint) -> SKSpriteNode {
        let name: String
        let nodeSize: CGFloat   // absolute pts

        if tile.city != nil {
            (name, nodeSize) = ("hq_pyramid_v1", 200)
        } else if tile.warpGate != nil {
            (name, nodeSize) = ("entity_warp_gate", 180)
        } else if tile.outpost != nil {
            (name, nodeSize) = ("entity_rogue_outpost", 180)
        } else if tile.mine != nil {
            (name, nodeSize) = ("entity_resource_mine", 170)
        } else if let ruins = tile.ruins {
            let idx = abs(ruins.id.hashValue) % Self.ruinsPool.count
            (name, nodeSize) = (Self.ruinsPool[idx], 175)
        } else {
            (name, nodeSize) = ("tile_empty_v1", 180)
        }

        let node = SKSpriteNode(imageNamed: name)
        node.size        = CGSize(width: nodeSize, height: nodeSize)
        node.anchorPoint = CGPoint(x: 0.5, y: 0.2)   // ground the sprite on the tile surface
        node.position    = pos

        if let outpost = tile.outpost, outpost.defeated {
            node.colorBlendFactor = 0.7
            node.color = .gray
            node.alpha = 0.55
        }
        return node
    }

    private func buildHalo(tile: MapTile, at pos: CGPoint) -> SKSpriteNode? {
        guard let color = haloColor(for: tile) else { return nil }
        let halo = SKSpriteNode(imageNamed: "halo_hex_master")
        halo.size             = CGSize(width: 280, height: 280)
        halo.position         = pos
        halo.color            = color
        halo.colorBlendFactor = 1.0
        halo.blendMode        = .add
        halo.alpha            = 0.65
        return halo
    }

    private func haloColor(for tile: MapTile) -> SKColor? {
        if let city = tile.city {
            if tileKey(tile.x, tile.y) == ownCityKey {
                return SKColor(red: 0,   green: 1,    blue: 1,   alpha: 1)   // cyan — own
            }
            if allyPlayerIds.contains(city.ownerId) {
                return SKColor(red: 1.0, green: 0.78, blue: 0.2, alpha: 1)   // gold — ally
            }
            return SKColor(red: 1, green: 0.2, blue: 0.2, alpha: 1)          // red  — enemy
        }
        if tile.outpost != nil {
            return SKColor(red: 1, green: 0.2, blue: 0.2, alpha: 1)          // red  — rogue
        }
        return nil   // mines / warp gates: no halo
    }

    private func buildNameplate(tile: MapTile, at pos: CGPoint) -> SKNode? {
        typealias Plate = (line1: String, line2: String, c1: SKColor, c2: SKColor)
        let content: Plate

        let cyan    = SKColor(red: 0,   green: 1,    blue: 1,   alpha: 1)
        let cyanDim = SKColor(red: 0,   green: 0.65, blue: 0.65, alpha: 0.85)
        let red     = SKColor(red: 1,   green: 0.3,  blue: 0.3,  alpha: 1)
        let redDim  = SKColor(red: 0.7, green: 0.14, blue: 0.14, alpha: 0.85)
        let purple  = SKColor(red: 0.7, green: 0.3,  blue: 1,    alpha: 1)
        let teal    = SKColor(red: 0,   green: 0.9,  blue: 1,    alpha: 1)
        let tealDim = SKColor(red: 0,   green: 0.6,  blue: 0.75, alpha: 0.85)
        let orange  = SKColor(red: 1,   green: 0.5,  blue: 0,    alpha: 1)
        let orangeDim = SKColor(red: 0.8, green: 0.35, blue: 0,  alpha: 0.85)

        if let city = tile.city {
            let isOwn = tileKey(tile.x, tile.y) == ownCityKey
            content = (city.name, city.owner, isOwn ? cyan : red, isOwn ? cyanDim : redDim)
        } else if let outpost = tile.outpost {
            content = ("ROGUE OUTPOST", "Lv. \(outpost.level)", red, redDim)
        } else if tile.warpGate != nil {
            content = ("WARP GATE", "", purple, purple)
        } else if let mine = tile.mine {
            let typeStr = mine.resourceType.rawValue.capitalized
            content = ("RESOURCE MINE", "\(typeStr) · \(Int(mine.productionRate))/hr", teal, tealDim)
        } else if let ruins = tile.ruins {
            content = ("RUINS", ruins.originalRing.rawValue.capitalized, orange, orangeDim)
        } else {
            return nil
        }

        let container = SKNode()
        container.position = CGPoint(x: pos.x, y: pos.y + 130)

        let bg = SKSpriteNode(imageNamed: "nameplate_master")
        bg.size  = CGSize(width: 200, height: 52)
        bg.alpha = 0.88
        container.addChild(bg)

        let lbl1 = SKLabelNode(text: content.line1)
        lbl1.fontName               = "AvenirNext-Bold"
        lbl1.fontSize               = 9
        lbl1.fontColor              = content.c1
        lbl1.horizontalAlignmentMode = .center
        lbl1.position               = CGPoint(x: 0, y: 5)
        container.addChild(lbl1)

        if !content.line2.isEmpty {
            let lbl2 = SKLabelNode(text: content.line2)
            lbl2.fontName               = "AvenirNext-Medium"
            lbl2.fontSize               = 7
            lbl2.fontColor              = content.c2
            lbl2.horizontalAlignmentMode = .center
            lbl2.position               = CGPoint(x: 0, y: -5)
            container.addChild(lbl2)
        }

        return container
    }

    // MARK: - Tap / selection

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let scenePos  = touch.location(in: self)
        let localPos  = convert(scenePos, to: tileMapNode)
        let col       = tileMapNode.tileColumnIndex(fromPosition: localPos)
        let row       = tileMapNode.tileRowIndex(fromPosition: localPos)
        let beX       = col - Self.halfMap
        let beY       = row - Self.halfMap

        if let tile = tiles.first(where: { $0.x == beX && $0.y == beY }) {
            showSelection(at: scenePosition(col: col, row: row))
            onTileTapped?(tile)
        } else {
            selectionLayer.removeAllChildren()
        }
    }

    private func showSelection(at pos: CGPoint) {
        selectionLayer.removeAllChildren()
        let sel = SKSpriteNode(imageNamed: "tile_selected_v2")
        sel.size     = CGSize(width: Self.isoTileW, height: Self.isoTileH)  // 256×216 matches tile
        sel.position = pos
        sel.alpha    = 0
        sel.run(.sequence([
            .fadeIn(withDuration: 0.15),
            .repeatForever(.sequence([
                .fadeAlpha(to: 0.6, duration: 0.5),
                .fadeAlpha(to: 1.0, duration: 0.5)
            ]))
        ]))
        selectionLayer.addChild(sel)
    }

    // MARK: - LOD

    private func applyLOD() {
        let overview = cameraNode.xScale > Self.overviewThreshold
        currentLOD   = overview ? .overview : .detail
        nameplateLayer.alpha = overview ? 0 : 1
        decoratorLayer.alpha = overview ? 0 : 1
    }

    private func snapToLOD(_ lod: LOD) {
        currentLOD = lod
        let targetScale: CGFloat = lod == .detail ? Self.detailSnapScale : Self.overviewSnapScale
        cameraNode.run(.scale(to: targetScale, duration: 0.25), withKey: "lod")
        let hide = lod == .overview
        nameplateLayer.run(.fadeAlpha(to: hide ? 0 : 1, duration: 0.25))
        decoratorLayer.run(.fadeAlpha(to: hide ? 0 : 1, duration: 0.25))
    }

    // MARK: - Camera bounds

    private func updateCameraBounds() {
        guard !tiles.isEmpty else { return }
        var minX =  CGFloat.greatestFiniteMagnitude
        var maxX = -CGFloat.greatestFiniteMagnitude
        var minY =  CGFloat.greatestFiniteMagnitude
        var maxY = -CGFloat.greatestFiniteMagnitude

        for tile in tiles {
            let (col, row) = mapCoord(tile.x, tile.y)
            let pos = scenePosition(col: col, row: row)
            minX = min(minX, pos.x); maxX = max(maxX, pos.x)
            minY = min(minY, pos.y); maxY = max(maxY, pos.y)
        }
        boundsMin = CGPoint(x: minX - Self.isoTileW, y: minY - Self.isoTileH)
        boundsMax = CGPoint(x: maxX + Self.isoTileW, y: maxY + Self.isoTileH)
    }

    private func clampCamera() {
        guard !tiles.isEmpty else { return }
        cameraNode.position.x = max(boundsMin.x, min(boundsMax.x, cameraNode.position.x))
        cameraNode.position.y = max(boundsMin.y, min(boundsMax.y, cameraNode.position.y))
    }

    // MARK: - Gestures

    @objc private func handlePinch(_ gesture: UIPinchGestureRecognizer) {
        // Zoom is disabled — pinch-out past threshold navigates back to Empire Overview.
        // gesture.scale is cumulative from gesture start (not reset each frame here).
        guard gesture.state == .ended else { return }
        if gesture.scale < 0.7 {
            onPinchOut?()
        }
    }

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard let cam = camera else { return }
        let t = gesture.translation(in: view)
        cam.position = CGPoint(
            x: cam.position.x - t.x * cam.xScale,
            y: cam.position.y + t.y * cam.xScale
        )
        gesture.setTranslation(.zero, in: view)
        clampCamera()
        if gesture.state == .ended { checkViewportRefetch() }
    }

    // MARK: - Viewport refetch

    private func checkViewportRefetch() {
        guard let cam = camera else { return }
        let localPos = convert(cam.position, to: tileMapNode)
        let col = tileMapNode.tileColumnIndex(fromPosition: localPos)
        let row = tileMapNode.tileRowIndex(fromPosition: localPos)
        let cx  = col - Self.halfMap
        let cy  = row - Self.halfMap

        if abs(cx - lastFetchCenter.cx) >= fetchThreshold ||
           abs(cy - lastFetchCenter.cy) >= fetchThreshold {
            onViewportMoved?(cx, cy)
        }
    }
}
