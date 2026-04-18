import SpriteKit

/// Dedicated scene za testiranje alignment-a novih sprite-ova.
/// Podržava live tuning anchor-a, scale-a, i camera zoom-a — rezultat je vidljiv odmah.
final class SpriteAlignmentTestScene: SKScene {

    private let worldNode = SKNode()
    private let tileSet = CityTileSet.build()
    private var tileMapNode: SKTileMapNode?

    /// Trenutno prikazani test sprite (1×1 ili HQ)
    private var testSprite: SKSpriteNode?

    // MARK: - Zoom / camera state

    /// Fit-to-view skala izracunata u layoutWorld. Menja se samo kad se view resize-uje.
    private var baseScale: CGFloat = 1.0
    /// User-kontrolisan zoom multiplier (1.0 = fit, 2.0 = 2x uvecan)
    private var zoomMultiplier: CGFloat = 1.0
    /// Pozicija u world space-u na koju treba centrirati kameru (HQ centar ili trenutni test tile)
    private var currentTargetWorldPos: CGPoint = .zero

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
        recomputeBaseScale(viewSize: size)
        applyTransforms()
    }

    /// Izracunava baseScale (fit grid u view) — koristi se samo kad se size promeni.
    private func recomputeBaseScale(viewSize: CGSize) {
        let n = CGFloat(Isometric.gridSize)
        let gridW: CGFloat = n * Isometric.tileWidth
        let gridH: CGFloat = n * Isometric.tileHeight + 240
        let usableW = viewSize.width - 40
        let usableH = viewSize.height - 200
        baseScale = min(usableW / gridW, usableH / gridH, 1.0)
    }

    /// Primenjuje trenutni zoom + centrira worldNode na currentTargetWorldPos.
    /// Ovo se zove kad god se promeni zoom ili trenutni target sprite.
    private func applyTransforms() {
        let effectiveScale = baseScale * zoomMultiplier
        worldNode.setScale(effectiveScale)

        // Centriraj target tako da je tačno u sredini ekrana.
        // WorldNode position = -(target world position) × scale — to dovodi target na (0,0) u scene space-u.
        worldNode.position = CGPoint(
            x: -currentTargetWorldPos.x * effectiveScale,
            y: -currentTargetWorldPos.y * effectiveScale
        )
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

    /// Kontrola camera zoom-a. 1.0 = fit-to-view, 2.0 = 2× uvecano.
    func setZoom(_ zoom: CGFloat) {
        zoomMultiplier = zoom
        applyTransforms()
    }

    /// Prikaži HQ 2×2 sprite sa zadatim anchor-om i scale multiplier-om.
    /// Kamera se automatski centrira na HQ centar.
    func showHQ(anchor: CGPoint, scaleMultiplier: CGFloat) {
        clearTestSprites()
        let spec = SpriteCatalog.hq
        guard SpriteCatalog.assetExists(spec) else {
            showMissingLabel(spec.assetName, at: Isometric.hqCenterPosition)
            currentTargetWorldPos = Isometric.hqCenterPosition
            applyTransforms()
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
        currentTargetWorldPos = Isometric.hqCenterPosition
        applyTransforms()
    }

    /// Prikaži 1×1 building sa zadatim anchor-om i scale multiplier-om.
    /// Kamera se automatski centrira na odabrani (col, row) tile.
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
        let tilePos = Isometric.scenePosition(col: col, row: row)
        guard SpriteCatalog.assetExists(spec) else {
            showMissingLabel(spec.assetName, at: tilePos)
            currentTargetWorldPos = tilePos
            applyTransforms()
            return
        }
        let sprite = SKSpriteNode(imageNamed: spec.assetName)
        let finalHeight = Isometric.tileWidth * scaleMultiplier
        sprite.size = CGSize(width: finalHeight, height: finalHeight)
        sprite.anchorPoint = anchor
        sprite.position = tilePos
        sprite.zPosition = Isometric.zDepth(col: col, row: row) + 0.5
        worldNode.addChild(sprite)
        testSprite = sprite
        currentTargetWorldPos = tilePos
        applyTransforms()
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
