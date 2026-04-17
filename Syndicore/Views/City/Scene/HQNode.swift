import SpriteKit

/// HQ piramida — uvek na centru grida (col 2, row 2).
final class HQNode: SKNode {
    // HQ sprite — baza 0.9× tile (lagano uža da ne "curi" preko diamond ivica
    // jer je sprite rendirovan u Tripo pod malo strmijim uglom od 2:1 iso),
    // visina 1.25× za piramidu koja ostaje dominantna.
    private static let hqSize = CGSize(
        width:  Isometric.tileWidth * 0.9,
        height: Isometric.tileWidth * 1.25
    )

    init(col: Int = Isometric.hqCoord.col, row: Int = Isometric.hqCoord.row) {
        super.init()
        let sprite = SKSpriteNode(imageNamed: "hq_pyramid_v1")
        sprite.size        = Self.hqSize
        sprite.anchorPoint = CGPoint(x: 0.5, y: 0.2)
        addChild(sprite)
        position  = Isometric.scenePosition(col: col, row: row)
        zPosition = Isometric.zDepth(col: col, row: row) + 0.5
        isUserInteractionEnabled = false
    }

    required init?(coder: NSCoder) { fatalError() }
}
