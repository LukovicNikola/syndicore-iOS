import SpriteKit

/// Dedicated scene za testiranje alignment-a novih sprite-ova.
/// Podržava live tuning anchor-a, scale-a, i camera zoom-a — rezultat je vidljiv odmah.
final class SpriteAlignmentTestScene: SKScene {

    private let worldNode = SKNode()
    private let tileSet = CityTileSet.build()
    private var tileMapNode: SKTileMapNode?

    /// Trenutno prikazani test sprite (1×1 ili HQ)
    private var testSprite: SKSpriteNode?

    private var skyboxNode: SKSpriteNode?

    // MARK: - Zoom / camera state

    private var baseScale: CGFloat = 1.0
    private var zoomMultiplier: CGFloat = 1.0
    private var userPan: CGPoint = .zero
    private var currentTargetWorldPos: CGPoint = .zero

    private static let minZoom: CGFloat = 0.3
    private static let maxZoom: CGFloat = 6.0

    /// Callback koji se poziva kad god se zoom promeni (pinch ili setZoom).
    var onZoomChanged: ((CGFloat) -> Void)?
    /// Callback koji se poziva kad god se pan promeni (drag).
    var onPanChanged: ((CGPoint) -> Void)?

    /// Gesture recognizeri koje smo mi dodali — za cleanup pri re-presentovanju.
    private var attachedGestures: [UIGestureRecognizer] = []

    override func didMove(to view: SKView) {
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        scaleMode = .resizeFill
        backgroundColor = SKColor(red: 0.04, green: 0.04, blue: 0.07, alpha: 1)

        // Skybox — idempotent
        if skyboxNode == nil {
            let skybox = SKSpriteNode(imageNamed: "hero_skybox_v1")
            skybox.position  = .zero
            skybox.zPosition = -200
            addChild(skybox)
            skyboxNode = skybox
        }
        resizeSkybox(to: view.bounds.size)

        // worldNode — idempotent
        if worldNode.parent == nil {
            addChild(worldNode)
            buildTileMap()
            addDebugOverlay()
        }

        // Gestures — uvek re-attach (ukloni stare da nema duplikata)
        attachedGestures.forEach { $0.view?.removeGestureRecognizer($0) }
        attachedGestures.removeAll()

        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        view.addGestureRecognizer(pinch)
        attachedGestures.append(pinch)

        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        pan.minimumNumberOfTouches = 2
        pan.maximumNumberOfTouches = 2
        view.addGestureRecognizer(pan)
        attachedGestures.append(pan)
    }

    override func didChangeSize(_ oldSize: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        resizeSkybox(to: size)
        recomputeBaseScale(viewSize: size)
        applyTransforms()
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

        // Ista formula kao CityScene.applyTransforms — da vrednosti iz Zoom taba
        // direktno odgovaraju izgledu na originalnom ekranu grada.
        worldNode.position = CGPoint(
            x: -currentTargetWorldPos.x * effectiveScale + userPan.x,
            y: -currentTargetWorldPos.y * effectiveScale + 40 + userPan.y
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
        // Centriraj tile map na HQ region (vidi CityScene.buildTileMap za detaljno objasnjenje)
        tileMap.position = CGPoint(x: 0, y: Isometric.hqCenterPosition.y)
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

    private func addDebugOverlay() {
        worldNode.addChild(DebugGridOverlayNode())
    }

    // MARK: - Public test API (sa live tuning-om)

    @objc private func handlePinch(_ gesture: UIPinchGestureRecognizer) {
        guard gesture.state == .changed || gesture.state == .ended else { return }
        let newZoom = zoomMultiplier * gesture.scale
        zoomMultiplier = max(Self.minZoom, min(Self.maxZoom, newZoom))
        gesture.scale = 1.0
        applyTransforms()
        onZoomChanged?(zoomMultiplier)
    }

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard let view, gesture.state == .changed else { return }
        let translation = gesture.translation(in: view)
        userPan.x += translation.x
        userPan.y -= translation.y   // UIKit y-down → SpriteKit y-up
        gesture.setTranslation(.zero, in: view)
        applyTransforms()
        onPanChanged?(userPan)
    }

    /// Kontrola camera zoom-a. 1.0 = fit-to-view, 2.0 = 2× uvecano.
    /// Resetuje i pan offset kad se zove sa resetom (zoom == 1.0).
    func setZoom(_ zoom: CGFloat) {
        zoomMultiplier = max(Self.minZoom, min(Self.maxZoom, zoom))
        if zoom == 1.0 { userPan = .zero; onPanChanged?(.zero) }
        applyTransforms()
        onZoomChanged?(zoomMultiplier)
    }

    /// Prikaži HQ 2×2 sprite sa zadatim anchor-om, scale-om, i rotacijom (stepeni).
    /// Kamera se automatski centrira na HQ centar.
    func showHQ(anchor: CGPoint, scaleMultiplier: CGFloat, rotationDegrees: CGFloat) {
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
        sprite.zRotation = rotationDegrees * .pi / 180
        sprite.position = Isometric.hqCenterPosition
        sprite.zPosition = Isometric.hqZDepth + 0.5
        worldNode.addChild(sprite)
        testSprite = sprite
        currentTargetWorldPos = Isometric.hqCenterPosition
        applyTransforms()
    }

    /// Prikaži 1×1 building sa zadatim anchor-om, scale-om, i rotacijom (stepeni).
    /// Kamera se automatski centrira na odabrani (col, row) tile.
    func showBuilding(
        _ type: BuildingType,
        col: Int,
        row: Int,
        anchor: CGPoint,
        scaleMultiplier: CGFloat,
        rotationDegrees: CGFloat
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
        sprite.zRotation = rotationDegrees * .pi / 180
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
