import SpriteKit

/// Dedicated scene za testiranje alignment-a novih sprite-ova.
/// Podržava live tuning anchor-a i scale-a — rezultat je vidljiv odmah.
final class SpriteAlignmentTestScene: SKScene {

    private let worldNode = SKNode()
    private let tileSet = CityTileSet.build()
    private var tileMapNode: SKTileMapNode?

    /// Trenutno prikazani test sprite (1×1 ili HQ)
    private var testSprite: SKSpriteNode?

    override func didMove(to view: SKView) {
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        scaleMode = .resizeFill
        backgroundColor = SKColor(red: 0.04, green: 0.04, blue: 0.07, alpha: 1)

        if let skybox = UIImage(named: "hero_skybox_v1") {
            let bg = SKSpriteNode(texture: SKTexture(image: skybox))
            bg.alpha = 0.3
            bg.zPosition = -200
            addChild(bg)
        }

        addChild(worldNode)
        buildTileMap()
        buildWallLayer()
        addDebugOverlay()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        layoutWorld(viewSize: size)
    }

    private func layoutWorld(viewSize: CGSize) {
        guard viewSize.width > 0 else { return }
        let n = CGFloat(Isometric.gridSize)
        let gridW: CGFloat = n * Isometric.tileWidth
        let gridH: CGFloat = n * Isometric.tileHeight + 240
        let usableW = viewSize.width - 40
        let usableH = viewSize.height - 200
        let scale = min(usableW / gridW, usableH / gridH, 1.0)
        worldNode.setScale(scale)
        let hqOffsetY = -Isometric.hqCenterPosition.y * scale
        worldNode.position = CGPoint(x: 0, y: hqOffsetY + 40)
    }

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
        let centerY = -CGFloat(Isometric.gridSize - 1) * Isometric.tileHeight / 2
        tileMap.position = CGPoint(x: 0, y: centerY + Isometric.hqCenterPosition.y / 2)
        tileMap.zPosition = 0
        tileMap.alpha = 0.4

        if let empty = CityTileSet.emptyGroup(in: tileSet) {
            for col in 0..<n {
                for row in 0..<n {
                    guard Isometric.isBuildable(col: col, row: row) else { continue }
                    tileMap.setTileGroup(empty, forColumn: col, row: tmRow(row))
                }
            }
        }
        worldNode.addChild(tileMap)
        tileMapNode = tileMap
    }

    private func buildWallLayer() {
        WallLayout.wallPositions().forEach  {
            let n = WallNode(entry: $0)
            n.alpha = 0.4
            worldNode.addChild(n)
        }
        WallLayout.pylonPositions().forEach {
            let n = CornerPylonNode(entry: $0)
            n.alpha = 0.4
            worldNode.addChild(n)
        }
    }

    private func addDebugOverlay() {
        worldNode.addChild(DebugGridOverlayNode())
    }

    // MARK: - Public test API (sa live tuning-om)

    /// Prikaži HQ 2×2 sprite sa zadatim anchor-om i scale multiplier-om.
    /// baseRenderHeight = 2 × tileWidth = 256 (default za HQ).
    /// Final renderHeight = baseRenderHeight × scaleMultiplier.
    func showHQ(anchor: CGPoint, scaleMultiplier: CGFloat) {
        clearTestSprites()
        let spec = SpriteCatalog.hq
        guard SpriteCatalog.assetExists(spec) else {
            showMissingLabel(spec.assetName, at: Isometric.hqCenterPosition)
            return
        }
        let sprite = SKSpriteNode(imageNamed: spec.assetName)
        let finalHeight = Isometric.tileWidth * 2 * scaleMultiplier
        sprite.size = CGSize(width: finalHeight, height: finalHeight)
        sprite.anchorPoint = anchor
        sprite.position = Isometric.hqCenterPosition
        sprite.zPosition = Isometric.hqZDepth + 0.5
        worldNode.addChild(sprite)
        testSprite = sprite
    }

    /// Prikaži 1×1 building sa zadatim anchor-om i scale multiplier-om.
    /// baseRenderHeight = tileWidth = 128.
    func showBuilding(
        _ type: BuildingType,
        col: Int,
        row: Int,
        anchor: CGPoint,
        scaleMultiplier: CGFloat
    ) {
        clearTestSprites()
        guard Isometric.isBuildable(col: col, row: row) else { return }
        let spec = SpriteCatalog.spec(for: type)
        guard SpriteCatalog.assetExists(spec) else {
            showMissingLabel(spec.assetName, at: Isometric.scenePosition(col: col, row: row))
            return
        }
        let sprite = SKSpriteNode(imageNamed: spec.assetName)
        let finalHeight = Isometric.tileWidth * scaleMultiplier
        sprite.size = CGSize(width: finalHeight, height: finalHeight)
        sprite.anchorPoint = anchor
        sprite.position = Isometric.scenePosition(col: col, row: row)
        sprite.zPosition = Isometric.zDepth(col: col, row: row) + 0.5
        worldNode.addChild(sprite)
        testSprite = sprite
    }

    func clearTestSprites() {
        testSprite?.removeFromParent()
        testSprite = nil
        worldNode.children
            .filter { ($0 as? SKLabelNode)?.text?.contains("MISSING") == true }
            .forEach { $0.removeFromParent() }
    }

    private func showMissingLabel(_ assetName: String, at point: CGPoint) {
        let label = SKLabelNode(text: "MISSING\n\(assetName)")
        label.fontName = "Menlo-Bold"
        label.fontSize = 10
        label.fontColor = .red
        label.numberOfLines = 2
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        label.position = point
        label.zPosition = 999
        worldNode.addChild(label)
    }
}
