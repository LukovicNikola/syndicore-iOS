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

        startIdlePulse()
    }

    /// Suptilna "breathing" animacija — koristimo scale (a NE alpha jer
    /// alpha bi smanjio cyan glow LED-ova što izgleda kao gašenje).
    /// Ciklus 2.4s, varijacija ±1.5% scale-a (jedva primetno, ali daje "živi" osećaj).
    private func startIdlePulse() {
        let scaleUp   = SKAction.scale(to: 1.015, duration: 1.2)
        scaleUp.timingMode = .easeInEaseOut
        let scaleDown = SKAction.scale(to: 1.000, duration: 1.2)
        scaleDown.timingMode = .easeInEaseOut
        let cycle = SKAction.sequence([scaleUp, scaleDown])
        sprite.run(.repeatForever(cycle), withKey: "idlePulse")
    }

    /// Menja teksturu između normalnog i selected stanja.
    func setSelected(_ selected: Bool) {
        let name = selected ? "hq_pyramid_selected_v1" : SpriteCatalog.hq.assetName
        sprite.texture = SKTexture(imageNamed: name)
    }

    required init?(coder: NSCoder) { fatalError("HQNode is code-only; not decodable from XIB") }
}
