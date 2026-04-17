import SpriteKit

/// Ugaoni pilon — prikazuje se na 4 ćoška zidnog perimetra.
final class CornerPylonNode: SKNode {
    // Proporcionalno skaliranje (width = height) da se sprite ne izobličuje.
    // Pylon je po prirodi visok u svom 1024×1024 canvas-u, pa proporcionalno
    // skaliranje na 1.4× zadržava iso ugao i daje dovoljno širine za seam.
    private static let pylonSize = CGSize(
        width:  Isometric.tileWidth  * 1.4,
        height: Isometric.tileWidth  * 1.4
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
