import SpriteKit

final class HQNode: SKNode {
    private static let hqSize = CGSize(
        width:  Isometric.tileWidth * 1.0,
        height: Isometric.tileWidth * 1.0
    )

    init(col: Int = Isometric.hqCoord.col, row: Int = Isometric.hqCoord.row) {
        super.init()
        let sprite = SKSpriteNode(imageNamed: "hq_pyramid_v1")
        sprite.size        = Self.hqSize
        sprite.anchorPoint = CGPoint(x: 0.5, y: 0.1367)
        addChild(sprite)
        position  = Isometric.scenePosition(col: col, row: row)
        zPosition = Isometric.zDepth(col: col, row: row) + 0.5
        isUserInteractionEnabled = false
    }

    required init?(coder: NSCoder) { fatalError() }
}
