import SpriteKit

/// Dev scene za tuniranje map tile dimenzija i occupant placement-a.
/// Renderuje 7x7 grid `map_tile_iso_v1` tile-ova sa podesivim width/height/color blend.
/// Centralni tile (0,0) prikazuje occupant sprite sa live tuning-om.
final class MapTileTestScene: SKScene {

    private let worldNode = SKNode()
    private var tileNodes: [SKSpriteNode] = []

    private var currentTileWidth:  CGFloat = 88
    private var currentTileHeight: CGFloat = 50
    private var currentSpacingX:   CGFloat = -4.9
    private var currentSpacingY:   CGFloat = -10.8
    private var currentColorBlend: CGFloat = 0.0

    // Occupant state
    private var occupantNode: SKSpriteNode?
    private var currentOccAsset: String = "map_city_v1"
    private var currentOccScale: CGFloat = 1.4
    private var currentOccAnchorX: CGFloat = 0.5
    private var currentOccAnchorY: CGFloat = 0.12

    private static let gridRadius = 3  // 7x7 grid (-3..3)

    override func didMove(to view: SKView) {
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        scaleMode = .resizeFill
        backgroundColor = SKColor(red: 0.05, green: 0.05, blue: 0.08, alpha: 1)

        if worldNode.parent == nil {
            addChild(worldNode)
        }

        rebuildTiles()
        rebuildOccupant()

        // Pinch zoom
        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        view.addGestureRecognizer(pinch)

        // Pan
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        pan.minimumNumberOfTouches = 1
        pan.maximumNumberOfTouches = 1
        view.addGestureRecognizer(pan)
    }

    // MARK: - Public

    func updateTiles(tileWidth: CGFloat, tileHeight: CGFloat, spacingX: CGFloat, spacingY: CGFloat, colorBlend: CGFloat) {
        currentTileWidth = tileWidth
        currentTileHeight = tileHeight
        currentSpacingX = spacingX
        currentSpacingY = spacingY
        currentColorBlend = colorBlend
        rebuildTiles()
        rebuildOccupant()
    }

    func updateOccupant(assetName: String, scale: CGFloat, anchorX: CGFloat, anchorY: CGFloat) {
        currentOccAsset = assetName
        currentOccScale = scale
        currentOccAnchorX = anchorX
        currentOccAnchorY = anchorY
        rebuildOccupant()
    }

    // MARK: - Tile grid

    private func tileToWorld(col: Int, row: Int) -> CGPoint {
        let stepX = currentTileWidth / 2.0 + currentSpacingX
        let stepY = currentTileHeight / 2.0 + currentSpacingY
        let x = CGFloat(col - row) * stepX
        let y = CGFloat(col + row) * (-stepY)
        return CGPoint(x: x, y: y)
    }

    private func rebuildTiles() {
        tileNodes.forEach { $0.removeFromParent() }
        tileNodes.removeAll()

        let r = Self.gridRadius
        for col in -r...r {
            for row in -r...r {
                let node = SKSpriteNode(imageNamed: "map_tile_iso_v1")
                node.size = CGSize(width: currentTileWidth, height: currentTileHeight)
                node.anchorPoint = CGPoint(x: 0.5, y: 0.5)
                node.position = tileToWorld(col: col, row: row)
                node.zPosition = CGFloat(col + row) * 0.1

                if currentColorBlend > 0 {
                    node.color = SKColor(white: 0.3, alpha: 1.0)
                    node.colorBlendFactor = currentColorBlend
                }

                worldNode.addChild(node)
                tileNodes.append(node)
            }
        }
    }

    private func rebuildOccupant() {
        occupantNode?.removeFromParent()
        occupantNode = nil

        let pos = tileToWorld(col: 0, row: 0)
        let tileZ: CGFloat = 0  // col+row = 0 for center tile

        let occ = SKSpriteNode(imageNamed: currentOccAsset)
        let side = currentTileWidth * currentOccScale
        occ.size = CGSize(width: side, height: side)
        occ.anchorPoint = CGPoint(x: currentOccAnchorX, y: currentOccAnchorY)
        occ.position = pos
        occ.zPosition = tileZ + 1.0
        worldNode.addChild(occ)
        occupantNode = occ
    }

    // MARK: - Gestures

    @objc private func handlePinch(_ gesture: UIPinchGestureRecognizer) {
        if gesture.state == .changed {
            let newScale = worldNode.xScale * gesture.scale
            worldNode.setScale(max(0.3, min(5.0, newScale)))
            gesture.scale = 1.0
        }
    }

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard let view else { return }
        if gesture.state == .changed {
            let translation = gesture.translation(in: view)
            worldNode.position = CGPoint(
                x: worldNode.position.x + translation.x,
                y: worldNode.position.y - translation.y
            )
            gesture.setTranslation(.zero, in: view)
        }
    }
}
