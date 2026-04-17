import SpriteKit

/// Ugaoni pilon — prikazuje se na 4 ćoška zidnog perimetra.
final class CornerPylonNode: SKNode {
    private static let pylonSize = CGSize(
        width:  Isometric.tileWidth  * 1.0,
        height: Isometric.tileWidth  * 1.5   // veći da prirodno premoste šav između dve strane zida
    )

    init(entry: WallLayout.WallEntry) {
        super.init()
        let sprite = SKSpriteNode(imageNamed: "corner_pylon_v1")
        sprite.size        = Self.pylonSize
        sprite.xScale      = entry.xScale
        sprite.anchorPoint = CGPoint(x: 0.5, y: 0.15)
        addChild(sprite)
        position  = entry.position
        zPosition = entry.zPosition
        isUserInteractionEnabled = false
    }

    required init?(coder: NSCoder) { fatalError() }
}
