import SpriteKit

/// Skele u izgradnji za prazne slotove koji su "queued" (reservation bez zgrade).
/// Normalno se ne koristi — scaffold overlay je deo BuildingNode kad je isUpgrading.
/// Ovaj node se koristi ako BE u budućnosti vrati "slot reserved but not started".
final class ScaffoldNode: SKNode {
    init(col: Int, row: Int) {
        super.init()
        let spec = SpriteCatalog.scaffold
        let sprite = SKSpriteNode(imageNamed: spec.assetName)
        sprite.size = spec.renderSize
        sprite.anchorPoint = spec.anchor
        sprite.zRotation = spec.rotationRadians
        addChild(sprite)
        position  = Isometric.scenePosition(col: col, row: row)
        zPosition = Isometric.zDepth(col: col, row: row) + 0.5
        isUserInteractionEnabled = false
    }

    required init?(coder: NSCoder) { fatalError() }
}
