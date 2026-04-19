import SpriteKit

/// HQ node — sedi na 2×2 region centriran na (2,2)-(3,3) u 6×6 gridu.
/// Sprite spec: vidi `SpriteCatalog.hq` (2048×1536 source, 256×256 render).
final class HQNode: SKNode {

    private let sprite: SKSpriteNode

    override init() {
        let spec = SpriteCatalog.hq
        sprite = SKSpriteNode(imageNamed: spec.assetName)
        super.init()
        sprite.size        = spec.renderSize
        sprite.anchorPoint = spec.anchor
        sprite.zRotation   = spec.rotationRadians
        addChild(sprite)
        position  = Isometric.hqCenterPosition
        zPosition = Isometric.hqZDepth + 0.5
        isUserInteractionEnabled = false
    }

    /// Menja teksturu između normalnog i selected stanja.
    func setSelected(_ selected: Bool) {
        let name = selected ? "hq_pyramid_selected_v1" : SpriteCatalog.hq.assetName
        sprite.texture = SKTexture(imageNamed: name)
    }

    required init?(coder: NSCoder) { fatalError("HQNode is code-only; not decodable from XIB") }
}
