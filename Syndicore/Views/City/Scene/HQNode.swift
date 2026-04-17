import SpriteKit

/// HQ piramida — uvek na centru grida (col 2, row 2).
final class HQNode: SKNode {
    // HQ je dominantna piramida u centru grida — ~1.8× veća od tile-a
    private static let hqSize = CGSize(
        width:  Isometric.tileWidth  * 1.8,
        height: Isometric.tileWidth  * 1.8
    )

    init(col: Int = Isometric.hqCoord.col, row: Int = Isometric.hqCoord.row) {
        super.init()
        let sprite = SKSpriteNode(imageNamed: "hq_pyramid_v1")
        sprite.size        = Self.hqSize
        sprite.anchorPoint = CGPoint(x: 0.5, y: 0.4)
        addChild(sprite)
        position  = Isometric.scenePosition(col: col, row: row)
        zPosition = Isometric.zDepth(col: col, row: row) + 0.5
        isUserInteractionEnabled = false
    }

    required init?(coder: NSCoder) { fatalError() }
}
