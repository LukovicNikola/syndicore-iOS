import SpriteKit

/// HQ node — sedi na 2×2 region centriran na (2,2)-(3,3) u 6×6 gridu.
/// Sprite spec: vidi `SpriteCatalog.hq` (2048×1536 source, 256×256 render).
final class HQNode: SKNode {

    init() {
        super.init()
        let spec = SpriteCatalog.hq
        let sprite = SKSpriteNode(imageNamed: spec.assetName)
        sprite.size = spec.renderSize
        sprite.anchorPoint = spec.anchor
        addChild(sprite)

        // Position na centru 2×2 regiona (između 4 HQ tile-a)
        position = Isometric.hqCenterPosition
        // zDepth tako da je iznad svih HQ tile-ova
        zPosition = Isometric.hqZDepth + 0.5
        isUserInteractionEnabled = false
    }

    required init?(coder: NSCoder) { fatalError("HQNode is code-only; not decodable from XIB") }
}
