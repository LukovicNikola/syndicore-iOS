import SpriteKit

final class MapScene: SKScene {

    // MARK: - Constants

    static let tileSize: CGFloat = 48

    private static let ringColors: [String: SKColor] = [
        "FRINGE": SKColor(red: 0.88, green: 0.88, blue: 0.88, alpha: 1),
        "GRID":   SKColor(red: 1.00, green: 0.55, blue: 0.00, alpha: 1),
        "CORE":   SKColor(red: 0.86, green: 0.08, blue: 0.24, alpha: 1),
        "NEXUS":  SKColor(red: 0.61, green: 0.19, blue: 1.00, alpha: 1),
    ]

    private static let terrainColors: [String: SKColor] = [
        "FLATLAND":    SKColor(red: 0.30, green: 0.60, blue: 0.30, alpha: 1),
        "QUARRY":      SKColor(red: 0.55, green: 0.40, blue: 0.25, alpha: 1),
        "RUINS":       SKColor(red: 0.35, green: 0.35, blue: 0.35, alpha: 1),
        "GEOTHERMAL":  SKColor(red: 0.85, green: 0.40, blue: 0.15, alpha: 1),
        "HILLTOP":     SKColor(red: 0.65, green: 0.55, blue: 0.40, alpha: 1),
        "RIVERSIDE":   SKColor(red: 0.25, green: 0.50, blue: 0.75, alpha: 1),
        "CROSSROADS":  SKColor(red: 0.80, green: 0.75, blue: 0.30, alpha: 1),
        "WASTELAND":   SKColor(red: 0.25, green: 0.25, blue: 0.28, alpha: 1),
    ]

    // MARK: - State

    private let cameraNode = SKCameraNode()
    private var tileNodes: [String: SKNode] = [:]
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

        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        view.addGestureRecognizer(pinch)

        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        pan.minimumNumberOfTouches = 1
        pan.maximumNumberOfTouches = 1
        view.addGestureRecognizer(pan)
    }

    // MARK: - Public API

    func loadTiles(_ newTiles: [MapTile], center: (cx: Int, cy: Int)) {
        lastFetchCenter = center
        tiles = newTiles

        for (key, node) in tileNodes {
            if !newTiles.contains(where: { tileKey($0) == key }) {
                node.removeFromParent()
                tileNodes.removeValue(forKey: key)
            }
        }

        gatePositions.removeAll()

        for tile in newTiles {
            let key = tileKey(tile)
            if tileNodes[key] != nil { continue }

            let node = createTileNode(tile)
            let pos = tilePosition(x: tile.x, y: tile.y)
            node.position = pos
            addChild(node)
            tileNodes[key] = node

            if tile.warpGate != nil {
                gatePositions.append(pos)
            }
        }

        drawGateLines()
    }

    // MARK: - Tile Creation

    private func createTileNode(_ tile: MapTile) -> SKNode {
        let container = SKNode()
        let size = Self.tileSize

        let bg = SKSpriteNode(color: colorForTile(tile), size: CGSize(width: size - 1, height: size - 1))
        container.addChild(bg)

        if tile.rarity.rawValue == "UNCOMMON" {
            let border = SKShapeNode(rectOf: CGSize(width: size, height: size), cornerRadius: 2)
            border.strokeColor = SKColor(red: 0.4, green: 0.6, blue: 1.0, alpha: 0.5)
            border.lineWidth = 1
            border.fillColor = .clear
            container.addChild(border)
        } else if tile.rarity.rawValue == "RARE" {
            let border = SKShapeNode(rectOf: CGSize(width: size, height: size), cornerRadius: 2)
            border.strokeColor = SKColor(red: 1.0, green: 0.84, blue: 0.0, alpha: 0.7)
            border.lineWidth = 1.5
            border.fillColor = .clear
            container.addChild(border)
        }

        if let occupantIcon = occupantEmoji(tile) {
            let label = SKLabelNode(text: occupantIcon)
            label.fontSize = size * 0.45
            label.verticalAlignmentMode = .center
            label.horizontalAlignmentMode = .center
            container.addChild(label)
        }

        if let city = tile.city {
            let nameLabel = SKLabelNode(text: city.owner)
            nameLabel.fontSize = 8
            nameLabel.fontColor = .white
            nameLabel.verticalAlignmentMode = .top
            nameLabel.horizontalAlignmentMode = .center
            nameLabel.position = CGPoint(x: 0, y: -(size * 0.35))
            container.addChild(nameLabel)
        }

        container.name = tileKey(tile)
        return container
    }

    private func colorForTile(_ tile: MapTile) -> SKColor {
        let terrainColor = Self.terrainColors[tile.terrain.rawValue] ?? SKColor.darkGray
        let ringColor = Self.ringColors[tile.ring.rawValue] ?? SKColor.gray
        return terrainColor.blended(withFraction: 0.25, of: ringColor) ?? terrainColor
    }

    private func occupantEmoji(_ tile: MapTile) -> String? {
        if tile.city != nil { return "🏠" }
        if tile.outpost != nil { return "💀" }
        if tile.mine != nil { return "💎" }
        if tile.warpGate != nil { return "🌀" }
        if tile.ruins != nil { return "🏚️" }
        return nil
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
