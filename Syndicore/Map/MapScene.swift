import SpriteKit
import UIKit

/// World map scena. Optimizacija: SKTileMapNode za terrain/ring background (jedan node umesto 10k),
/// plus odvojen occupant layer za tile-ove koji imaju city/outpost/mine/gate/ruins
/// (tipicno <5% viewport-a). Warp gate linije stoje kao jedan compound SKShapeNode.
final class MapScene: SKScene {

    // MARK: - Constants

    static let tileSize: CGFloat = 48

    /// 8 terrain × 4 ring = 32 kombinacije blended boja → cache-ovane kao SKTileGroup.
    private static let ringColors: [Ring: SKColor] = [
        .fringe: SKColor(red: 0.88, green: 0.88, blue: 0.88, alpha: 1),
        .grid:   SKColor(red: 1.00, green: 0.55, blue: 0.00, alpha: 1),
        .core:   SKColor(red: 0.86, green: 0.08, blue: 0.24, alpha: 1),
        .nexus:  SKColor(red: 0.61, green: 0.19, blue: 1.00, alpha: 1),
    ]

    private static let terrainColors: [Terrain: SKColor] = [
        .FLATLAND:    SKColor(red: 0.30, green: 0.60, blue: 0.30, alpha: 1),
        .QUARRY:      SKColor(red: 0.55, green: 0.40, blue: 0.25, alpha: 1),
        .RUINS:       SKColor(red: 0.35, green: 0.35, blue: 0.35, alpha: 1),
        .GEOTHERMAL:  SKColor(red: 0.85, green: 0.40, blue: 0.15, alpha: 1),
        .HILLTOP:     SKColor(red: 0.65, green: 0.55, blue: 0.40, alpha: 1),
        .RIVERSIDE:   SKColor(red: 0.25, green: 0.50, blue: 0.75, alpha: 1),
        .CROSSROADS:  SKColor(red: 0.80, green: 0.75, blue: 0.30, alpha: 1),
        .WASTELAND:   SKColor(red: 0.25, green: 0.25, blue: 0.28, alpha: 1),
    ]

    /// Maksimalni map radius (cap sa BE). Columns/rows = 2 * maxRadius + 1.
    private static let maxRadius = 50
    private static var tileMapColumns: Int { maxRadius * 2 + 1 }
    private static var tileMapRows: Int { maxRadius * 2 + 1 }

    // MARK: - State

    private let cameraNode = SKCameraNode()

    /// Background tile map sa svim terrain/ring bojama. Jedan node za ceo grid.
    private var backgroundTileMap: SKTileMapNode!

    /// Layer za occupant ikonice (city/outpost/mine/gate/ruins) — samo tile-ovi koji imaju okupant-e.
    private let occupantLayer = SKNode()

    /// Layer za rarity border-e (UNCOMMON/RARE) — samo za tile-ove koji nisu COMMON.
    private let rarityLayer = SKNode()

    /// Key (x,y) → occupant node, za cleanup na loadTiles.
    private var occupantNodes: [String: SKNode] = [:]
    private var rarityNodes: [String: SKNode] = [:]

    /// Cache tile grupa po (terrain, ring) — kreira se jednom pri setup-u.
    private var tileGroupCache: [String: SKTileGroup] = [:]

    private var gatePositions: [CGPoint] = []
    private var gateLineNode: SKShapeNode?
    private var lastFetchCenter = (cx: 0, cy: 0)
    private let fetchThreshold = 10

    var onTileTapped: ((MapTile) -> Void)?
    var onViewportMoved: ((Int, Int) -> Void)?

    private var tiles: [MapTile] = []

    // MARK: - Setup

    override func didMove(to view: SKView) {
        backgroundColor = SKColor(red: 0.08, green: 0.08, blue: 0.10, alpha: 1)
        anchorPoint = CGPoint(x: 0.5, y: 0.5)

        camera = cameraNode
        addChild(cameraNode)
        cameraNode.setScale(1.0)

        setupTileMap()
        addChild(rarityLayer)
        addChild(occupantLayer)

        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        view.addGestureRecognizer(pinch)

        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        pan.minimumNumberOfTouches = 1
        pan.maximumNumberOfTouches = 1
        view.addGestureRecognizer(pan)
    }

    private func setupTileMap() {
        let tileSet = SKTileSet(tileGroups: buildTileGroups())
        backgroundTileMap = SKTileMapNode(
            tileSet: tileSet,
            columns: Self.tileMapColumns,
            rows: Self.tileMapRows,
            tileSize: CGSize(width: Self.tileSize, height: Self.tileSize)
        )
        backgroundTileMap.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        backgroundTileMap.zPosition = -10
        addChild(backgroundTileMap)
    }

    /// Kreira 32 tile grupe — jednu za svaku (terrain × ring) kombinaciju sa blended bojom.
    private func buildTileGroups() -> [SKTileGroup] {
        var groups: [SKTileGroup] = []
        for terrain in Terrain.allCases {
            guard let terrainColor = Self.terrainColors[terrain] else { continue }
            for ring in [Ring.fringe, .grid, .core, .nexus] {
                guard let ringColor = Self.ringColors[ring] else { continue }
                let blended = terrainColor.blended(withFraction: 0.25, of: ringColor) ?? terrainColor
                let texture = Self.colorTexture(blended, size: CGSize(width: Self.tileSize, height: Self.tileSize))
                let def = SKTileDefinition(texture: texture)
                let group = SKTileGroup(tileDefinition: def)
                group.name = Self.groupKey(terrain: terrain, ring: ring)
                groups.append(group)
                tileGroupCache[group.name!] = group
            }
        }
        return groups
    }

    private static func groupKey(terrain: Terrain, ring: Ring) -> String {
        "\(terrain.rawValue)|\(ring.rawValue)"
    }

    /// UIImage sa solid fill — koristi se kao textura za SKTileDefinition.
    private static func colorTexture(_ color: SKColor, size: CGSize) -> SKTexture {
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            color.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }
        return SKTexture(image: image)
    }

    // MARK: - Public API

    func loadTiles(_ newTiles: [MapTile], center: (cx: Int, cy: Int)) {
        lastFetchCenter = center
        tiles = newTiles

        // 1. Background tile map: set group za svaki novi tile (O(n), no allocations)
        for tile in newTiles {
            guard let group = tileGroupCache[Self.groupKey(terrain: tile.terrain, ring: tile.ring)] else { continue }
            let (col, row) = tileMapCoord(x: tile.x, y: tile.y)
            guard col >= 0, col < Self.tileMapColumns, row >= 0, row < Self.tileMapRows else { continue }
            backgroundTileMap.setTileGroup(group, forColumn: col, row: row)
        }

        // 2. Rarity border overlay: samo UNCOMMON/RARE
        pruneNodes(&rarityNodes, keepingKeysFrom: newTiles)
        for tile in newTiles where tile.rarity != .COMMON {
            let key = tileKey(tile)
            if rarityNodes[key] != nil { continue }
            let node = makeRarityBorder(for: tile)
            node.position = tilePosition(x: tile.x, y: tile.y)
            rarityLayer.addChild(node)
            rarityNodes[key] = node
        }

        // 3. Occupant overlay: samo tile-ovi sa city/outpost/mine/gate/ruins
        pruneNodes(&occupantNodes, keepingKeysFrom: newTiles)
        gatePositions.removeAll()
        for tile in newTiles where tile.hasOccupant {
            let key = tileKey(tile)
            let pos = tilePosition(x: tile.x, y: tile.y)
            if occupantNodes[key] == nil {
                let node = makeOccupantNode(for: tile)
                node.position = pos
                occupantLayer.addChild(node)
                occupantNodes[key] = node
            }
            if tile.warpGate != nil {
                gatePositions.append(pos)
            }
        }

        drawGateLines()
    }

    // MARK: - Overlay factories

    private func makeRarityBorder(for tile: MapTile) -> SKNode {
        let border = SKShapeNode(rectOf: CGSize(width: Self.tileSize, height: Self.tileSize), cornerRadius: 2)
        switch tile.rarity {
        case .UNCOMMON:
            border.strokeColor = SKColor(red: 0.4, green: 0.6, blue: 1.0, alpha: 0.5)
            border.lineWidth = 1
        case .RARE:
            border.strokeColor = SKColor(red: 1.0, green: 0.84, blue: 0.0, alpha: 0.7)
            border.lineWidth = 1.5
        case .COMMON:
            break
        }
        border.fillColor = .clear
        border.name = tileKey(tile)
        return border
    }

    private func makeOccupantNode(for tile: MapTile) -> SKNode {
        let container = SKNode()
        container.name = tileKey(tile)

        let label = SKLabelNode(text: occupantIcon(tile))
        label.fontSize = Self.tileSize * 0.45
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        container.addChild(label)

        if let city = tile.city {
            let nameLabel = SKLabelNode(text: city.owner)
            nameLabel.fontSize = 8
            nameLabel.fontColor = .white
            nameLabel.verticalAlignmentMode = .top
            nameLabel.horizontalAlignmentMode = .center
            nameLabel.position = CGPoint(x: 0, y: -(Self.tileSize * 0.35))
            container.addChild(nameLabel)
        }

        return container
    }

    private func occupantIcon(_ tile: MapTile) -> String {
        // TODO: zameniti emoji sprite asset-ima (.imageset) za consistent-n stil sa CityView
        if tile.city != nil { return "🏠" }
        if tile.outpost != nil { return "💀" }
        if tile.mine != nil { return "💎" }
        if tile.warpGate != nil { return "🌀" }
        if tile.ruins != nil { return "🏚️" }
        return "?"
    }

    /// Uklanja stare occupant/rarity nodes za tile-ove koji više nisu u viewport-u.
    private func pruneNodes(_ nodes: inout [String: SKNode], keepingKeysFrom newTiles: [MapTile]) {
        let keepSet = Set(newTiles.map { tileKey($0) })
        for (key, node) in nodes where !keepSet.contains(key) {
            node.removeFromParent()
            nodes.removeValue(forKey: key)
        }
    }

    // MARK: - Warp Gate Lines

    private func drawGateLines() {
        gateLineNode?.removeFromParent()
        guard gatePositions.count >= 2 else { return }

        let path = CGMutablePath()
        for i in 0..<gatePositions.count {
            for j in (i + 1)..<gatePositions.count {
                path.move(to: gatePositions[i])
                path.addLine(to: gatePositions[j])
            }
        }

        let lineNode = SKShapeNode(path: path)
        lineNode.strokeColor = SKColor(red: 0.61, green: 0.19, blue: 1.0, alpha: 0.3)
        lineNode.lineWidth = 1
        lineNode.zPosition = -1
        addChild(lineNode)
        gateLineNode = lineNode
    }

    // MARK: - Gestures

    @objc private func handlePinch(_ gesture: UIPinchGestureRecognizer) {
        guard let cam = camera else { return }
        if gesture.state == .changed {
            let newScale = cam.xScale / gesture.scale
            cam.setScale(max(0.3, min(3.0, newScale)))
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
        let location = touch.location(in: self)

        let x = Int(round(location.x / Self.tileSize))
        let y = Int(round(location.y / Self.tileSize))

        if let tile = tiles.first(where: { $0.x == x && $0.y == y }) {
            onTileTapped?(tile)
        }
    }

    // MARK: - Viewport Refetch

    private func checkViewportRefetch() {
        guard let cam = camera else { return }
        let cx = Int(round(cam.position.x / Self.tileSize))
        let cy = Int(round(cam.position.y / Self.tileSize))

        let dx = abs(cx - lastFetchCenter.cx)
        let dy = abs(cy - lastFetchCenter.cy)

        if dx >= fetchThreshold || dy >= fetchThreshold {
            onViewportMoved?(cx, cy)
        }
    }

    // MARK: - Helpers

    private func tilePosition(x: Int, y: Int) -> CGPoint {
        CGPoint(x: CGFloat(x) * Self.tileSize, y: CGFloat(y) * Self.tileSize)
    }

    /// Pretvara world koordinate (x/y od -maxRadius..+maxRadius) u SKTileMapNode col/row (0..columns-1).
    private func tileMapCoord(x: Int, y: Int) -> (col: Int, row: Int) {
        let col = x + Self.maxRadius
        let row = y + Self.maxRadius
        return (col, row)
    }

    private func tileKey(_ tile: MapTile) -> String {
        "\(tile.x),\(tile.y)"
    }
}

private extension SKColor {
    func blended(withFraction fraction: CGFloat, of color: SKColor) -> SKColor? {
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        color.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        return SKColor(
            red: r1 + (r2 - r1) * fraction,
            green: g1 + (g2 - g1) * fraction,
            blue: b1 + (b2 - b1) * fraction,
            alpha: a1 + (a2 - a1) * fraction
        )
    }
}
