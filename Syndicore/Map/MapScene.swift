import SpriteKit
import UIKit

/// Isometric world map scene. Uses pre-rendered iso diamond asset (map_tile_iso_v1),
/// same projection math as CityScene. No rotation/skew — just size and position.
final class MapScene: SKScene {

    // MARK: - Iso Constants

    static let tileWidth:  CGFloat = 88
    static let tileHeight: CGFloat = 50
    static let spacingX:   CGFloat = -4.9
    static let spacingY:   CGFloat = -10.8

    // MARK: - State

    private let cameraNode = SKCameraNode()
    private let tileLayer = SKNode()
    private let movementLayer = SKNode()  // iznad tile-ova
    private var tileNodes: [String: SKSpriteNode] = [:]
    private var occupantNodes: [String: SKSpriteNode] = [:]
    private var labelNodes: [String: SKLabelNode] = [:]
    private var movementLineNodes: [String: MovementLineNode] = [:]  // keyed by movement.id
    private var lastFetchCenter = (cx: 0, cy: 0)
    private let fetchThreshold = 10
    private var pinchGesture: UIPinchGestureRecognizer?
    private var panGesture: UIPanGestureRecognizer?

    var onTileTapped: ((MapTile) -> Void)?
    var onViewportMoved: ((Int, Int) -> Void)?

    private var tiles: [MapTile] = []

    // MARK: - Iso Math (identical to CityScene)

    private static let stepX: CGFloat = tileWidth / 2.0 + spacingX
    private static let stepY: CGFloat = tileHeight / 2.0 + spacingY

    private func tileToWorld(col: Int, row: Int) -> CGPoint {
        let x = CGFloat(col - row) * Self.stepX
        let y = CGFloat(col + row) * (-Self.stepY)
        return CGPoint(x: x, y: y)
    }

    private func worldToTile(point: CGPoint) -> (col: Int, row: Int) {
        let fx =  point.x / Self.stepX
        let fy = -point.y / Self.stepY
        let col = Int(((fx + fy) / 2.0).rounded())
        let row = Int(((fy - fx) / 2.0).rounded())
        return (col, row)
    }

    // MARK: - Setup

    override func didMove(to view: SKView) {
        backgroundColor = SKColor(red: 0.05, green: 0.05, blue: 0.08, alpha: 1)
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        scaleMode = .resizeFill

        camera = cameraNode
        addChild(cameraNode)
        cameraNode.setScale(2.0)
        cameraNode.position = .zero

        tileLayer.position = .zero
        addChild(tileLayer)

        // Movement linije iznad tile-ova ali ispod occupant sprajtova
        movementLayer.position = .zero
        movementLayer.zPosition = 500   // well above tile zDepth (max ~100 for 50-tile grid)
        addChild(movementLayer)

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
        if let g = pinchGesture { view.removeGestureRecognizer(g) }
        if let g = panGesture { view.removeGestureRecognizer(g) }
        pinchGesture = nil
        panGesture = nil
    }

    // MARK: - Public API

    /// Brisanje svih tile / occupant / movement node-ova + cached state-a.
    /// Pozivati pri prelasku na drugi svet (Crystal Implosion → novi grad u
    /// novom ringu) — inače stari nodi-ovi ostaju u memoriji + stale viewport.
    func reset() {
        for (_, node) in tileNodes { node.removeFromParent() }
        for (_, node) in occupantNodes { node.removeFromParent() }
        for (_, node) in labelNodes { node.removeFromParent() }
        for (_, node) in movementLineNodes { node.removeFromParent() }
        tileNodes.removeAll()
        occupantNodes.removeAll()
        labelNodes.removeAll()
        movementLineNodes.removeAll()
        tiles = []
        lastFetchCenter = (cx: 0, cy: 0)
    }

    func loadTiles(_ newTiles: [MapTile], center: (cx: Int, cy: Int)) {
        lastFetchCenter = center
        tiles = newTiles

        let newKeys = Set(newTiles.map { "\($0.x),\($0.y)" })

        // Remove tiles no longer in viewport
        for (key, node) in tileNodes where !newKeys.contains(key) {
            node.removeFromParent()
            tileNodes.removeValue(forKey: key)
            occupantNodes[key]?.removeFromParent()
            occupantNodes.removeValue(forKey: key)
            labelNodes[key]?.removeFromParent()
            labelNodes.removeValue(forKey: key)
        }

        // Add new tiles + occupants
        for tile in newTiles {
            let key = "\(tile.x),\(tile.y)"
            if tileNodes[key] != nil { continue }

            let pos = tileToWorld(col: tile.x, row: tile.y)
            let tileZ = CGFloat(tile.x + tile.y) * 0.1

            // Tile node
            let node = SKSpriteNode(imageNamed: "map_tile_iso_v1")
            node.size = CGSize(width: Self.tileWidth, height: Self.tileHeight)
            node.anchorPoint = CGPoint(x: 0.5, y: 0.5)
            node.position = pos
            node.zPosition = tileZ
            node.name = key
            tileLayer.addChild(node)
            tileNodes[key] = node

            // Occupant sprite (priority: city > warpGate > mine > outpost > ruins)
            let occupantAsset: String? = if tile.city != nil {
                "map_city_v1"
            } else if tile.warpGate != nil {
                "map_warp_gate_v1"
            } else if tile.mine != nil {
                "map_mine_v1"
            } else if tile.outpost != nil {
                "map_outpost_v1"
            } else if tile.ruins != nil {
                "map_ruins_v1"
            } else {
                nil
            }

            if let asset = occupantAsset {
                let occ = SKSpriteNode(imageNamed: asset)
                let (sizeMul, anchor) = Self.occupantSpec(for: tile)
                occ.size = CGSize(width: Self.tileWidth * sizeMul, height: Self.tileWidth * sizeMul)
                occ.anchorPoint = anchor
                occ.position = pos
                occ.zPosition = tileZ + 1.0
                // Defeated outposts: desaturate (gray tint)
                if let outpost = tile.outpost, outpost.defeated {
                    occ.colorBlendFactor = 0.7
                    occ.color = .gray
                    occ.alpha = 0.5
                }
                tileLayer.addChild(occ)
                occupantNodes[key] = occ
            }

            // City name label
            if let cityName = tile.city?.name {
                let label = SKLabelNode(text: cityName)
                label.fontName = "AvenirNext-Medium"
                label.fontSize = 10
                label.fontColor = .white
                label.horizontalAlignmentMode = .center
                label.position = CGPoint(x: pos.x, y: pos.y + Self.tileHeight * 1.0)
                label.zPosition = tileZ + 2.0
                tileLayer.addChild(label)
                labelNodes[key] = label
            }
        }
    }

    // MARK: - Movement lines

    /// Reconciles movement linije sa trenutnim state-om.
    /// - Dodaje MovementLineNode za nove movements
    /// - Uklanja linije cija movement.id vise nije u listi
    /// - Postojece ostavlja (particle animacija nastavlja)
    func setMovements(_ movements: [TroopMovement]) {
        let activeIds = Set(movements.map { $0.id })

        // Remove lines for movements that are no longer active
        for (id, node) in movementLineNodes where !activeIds.contains(id) {
            node.removeFromParent()
            movementLineNodes.removeValue(forKey: id)
        }

        // Add new lines
        for movement in movements {
            guard movementLineNodes[movement.id] == nil else { continue }
            let start = tileToWorld(col: movement.from.x, row: movement.from.y)
            let end   = tileToWorld(col: movement.to.x,   row: movement.to.y)
            let line = MovementLineNode(movement: movement, start: start, end: end)
            movementLayer.addChild(line)
            movementLineNodes[movement.id] = line
        }
    }

    // MARK: - Occupant specs (from SpriteAlignmentTest)

    private static func occupantSpec(for tile: MapTile) -> (sizeMultiplier: CGFloat, anchor: CGPoint) {
        if tile.city != nil     { return (0.63, CGPoint(x: 0.491, y: 0.401)) }
        if tile.warpGate != nil { return (0.65, CGPoint(x: 0.489, y: 0.226)) }
        if tile.mine != nil     { return (0.55, CGPoint(x: 0.489, y: 0.291)) }
        if tile.outpost != nil  { return (0.63, CGPoint(x: 0.493, y: 0.236)) }
        if tile.ruins != nil    { return (0.55, CGPoint(x: 0.498, y: 0.408)) }
        return (0.63, CGPoint(x: 0.5, y: 0.3))
    }

    // MARK: - Gestures

    @objc private func handlePinch(_ gesture: UIPinchGestureRecognizer) {
        guard let cam = camera else { return }
        if gesture.state == .changed {
            let newScale = cam.xScale / gesture.scale
            cam.setScale(max(0.3, min(8.0, newScale)))
            gesture.scale = 1.0
        }
        if gesture.state == .ended {
            checkViewportRefetch()
        }
    }

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard let cam = camera else { return }
        let translation = gesture.translation(in: view)
        let scale = cam.xScale
        cam.position = CGPoint(
            x: cam.position.x - translation.x * scale,
            y: cam.position.y + translation.y * scale
        )
        gesture.setTranslation(.zero, in: view)

        if gesture.state == .ended {
            checkViewportRefetch()
        }
    }

    // MARK: - Tap

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: tileLayer)
        let (col, row) = worldToTile(point: location)

        if let tile = tiles.first(where: { $0.x == col && $0.y == row }) {
            onTileTapped?(tile)
        }
    }

    // MARK: - Viewport Refetch

    private func checkViewportRefetch() {
        guard let cam = camera else { return }
        let (cx, cy) = worldToTile(point: cam.position)

        let dx = abs(cx - lastFetchCenter.cx)
        let dy = abs(cy - lastFetchCenter.cy)

        if dx >= fetchThreshold || dy >= fetchThreshold {
            onViewportMoved?(cx, cy)
        }
    }
}
