import SpriteKit

/// Dedicated scene za testiranje alignment-a novih sprite-ova.
/// Isti iso grid kao CityScene, ali:
/// - Debug overlay je UVEK uključen
/// - Renderuje JEDAN test sprite na poziciji koju odabere SwiftUI UI
/// - Nema nikakav game state, nema tap interakcija
///
/// Koristi se iz `SpriteAlignmentTestView` — pomaže da vizuelno proveriš da li
/// novogenerisani sprajt sedne na iso grid.
final class SpriteAlignmentTestScene: SKScene {

    private let worldNode = SKNode()
    private let tileSet = CityTileSet.build()
    private var tileMapNode: SKTileMapNode?

    /// Trenutno prikazani test sprite — menja se preko `showSprite(_:at:)`
    private var testSprite: SKSpriteNode?
    private var testHQ: HQNode?

    override func didMove(to view: SKView) {
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        scaleMode = .resizeFill
        backgroundColor = SKColor(red: 0.04, green: 0.04, blue: 0.07, alpha: 1)

        // Skybox samo blagi (da se vidi kontrast sa sprajtom)
        if let skybox = UIImage(named: "hero_skybox_v1") {
            let bg = SKSpriteNode(texture: SKTexture(image: skybox))
            bg.alpha = 0.3  // Smanjeni alpha da debug overlay bude vidljiv
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

    // MARK: - Layout (isto kao CityScene)

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

    // MARK: - Build layers

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
        tileMap.alpha = 0.4  // Tile bg malo providan da debug overlay bude vidljiv

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
            n.alpha = 0.4  // Providan da ne dominira
            worldNode.addChild(n)
        }
        WallLayout.pylonPositions().forEach {
            let n = CornerPylonNode(entry: $0)
            n.alpha = 0.4
            worldNode.addChild(n)
        }
    }

    private func addDebugOverlay() {
        let overlay = DebugGridOverlayNode()
        worldNode.addChild(overlay)
    }

    // MARK: - Public test API

    /// Prikaži HQ 2×2 sprite u centru grida.
    func showHQ() {
        clearTestSprites()
        let hq = HQNode()
        worldNode.addChild(hq)
        testHQ = hq
    }

    /// Prikaži 1×1 building sprajt na datoj (col, row) poziciji.
    /// Koristi SpriteCatalog za size/anchor — isto kao BuildingNode u produkciji.
    func showBuilding(_ type: BuildingType, col: Int, row: Int) {
        clearTestSprites()
        guard Isometric.isBuildable(col: col, row: row) else { return }

        let spec = SpriteCatalog.spec(for: type)
        guard SpriteCatalog.assetExists(spec) else {
            // Fallback: red X za missing asset
            let missing = SKLabelNode(text: "MISSING\n\(spec.assetName)")
            missing.fontName = "Menlo-Bold"
            missing.fontSize = 10
            missing.fontColor = .red
            missing.numberOfLines = 2
            missing.verticalAlignmentMode = .center
            missing.horizontalAlignmentMode = .center
            missing.position = Isometric.scenePosition(col: col, row: row)
            missing.zPosition = Isometric.zDepth(col: col, row: row) + 0.5
            worldNode.addChild(missing)
            testSprite = nil
            return
        }

        let sprite = SKSpriteNode(imageNamed: spec.assetName)
        sprite.size = spec.renderSize
        sprite.anchorPoint = spec.anchor
        sprite.position = Isometric.scenePosition(col: col, row: row)
        sprite.zPosition = Isometric.zDepth(col: col, row: row) + 0.5
        worldNode.addChild(sprite)
        testSprite = sprite
    }

    /// Obriši sve test sprite-ove (HQ i building).
    func clearTestSprites() {
        testSprite?.removeFromParent()
        testSprite = nil
        testHQ?.removeFromParent()
        testHQ = nil
        // Ukloni i "MISSING" label ako postoji
        worldNode.children.filter { $0 is SKLabelNode && ($0 as? SKLabelNode)?.text?.contains("MISSING") == true }
            .forEach { $0.removeFromParent() }
    }
}
