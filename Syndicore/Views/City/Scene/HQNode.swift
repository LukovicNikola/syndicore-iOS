import SpriteKit

/// HQ piramida — uvek na centru grida (col 2, row 2).
final class HQNode: SKNode {
    // HQ je veći od standardnog tile-a — piramida koja dominira centrom grida
    private static let hqSize = CGSize(
        width:  Isometric.tileWidth  * 1.4,
        height: Isometric.tileWidth  * 1.4
    )

    init(col: Int = Isometric.hqCoord.col, row: Int = Isometric.hqCoord.row) {
        super.init()
        let sprite = SKSpriteNode(imageNamed: "hq_pyramid_v1")
        sprite.size        = Self.hqSize
        sprite.anchorPoint = CGPoint(x: 0.5, y: 0.35)
        addChild(sprite)
        position  = Isometric.scenePosition(col: col, row: row)
        zPosition = Isometric.zDepth(col: col, row: row) + 0.5
        isUserInteractionEnabled = false
    }

    required init?(coder: NSCoder) { fatalError() }
}
