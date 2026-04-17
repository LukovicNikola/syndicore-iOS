import SpriteKit

/// Jedan segment zida oko perimetra grida.
final class WallNode: SKNode {
    private static let wallSize = CGSize(
        width:  Isometric.tileWidth,
        height: Isometric.tileHeight * 1.5   // malo viši od tile-a da izgleda kao zid
    )

    init(entry: WallLayout.WallEntry) {
        super.init()
        let sprite = SKSpriteNode(imageNamed: "wall_segment_v1")
        sprite.size        = Self.wallSize
        sprite.xScale      = entry.xScale
        sprite.anchorPoint = CGPoint(x: 0.5, y: 0.2)
        addChild(sprite)
        position  = entry.position
        zPosition = entry.zPosition
        isUserInteractionEnabled = false
    }

    required init?(coder: NSCoder) { fatalError() }
}
