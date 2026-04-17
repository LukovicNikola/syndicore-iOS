import SpriteKit

/// Jedan tile na iso gridu — prikazuje prazan tile ili selected state.
final class TileNode: SKNode {
    private let baseSprite:     SKSpriteNode
    private let selectedSprite: SKSpriteNode

    let col: Int
    let row: Int

    private static let tileSize = CGSize(width: Isometric.tileWidth, height: Isometric.tileHeight)

    init(col: Int, row: Int) {
        self.col = col
        self.row = row
        baseSprite     = SKSpriteNode(imageNamed: "tile_empty_v1")
        selectedSprite = SKSpriteNode(imageNamed: "tile_selected_v1")
        super.init()

        baseSprite.size     = Self.tileSize
        selectedSprite.size = Self.tileSize
        selectedSprite.alpha = 0

        addChild(baseSprite)
        addChild(selectedSprite)

        position  = Isometric.scenePosition(col: col, row: row)
        zPosition = Isometric.zDepth(col: col, row: row)
        isUserInteractionEnabled = false
    }

    required init?(coder: NSCoder) { fatalError() }

    var isSelected: Bool = false { didSet { applySelection() } }

    private func applySelection() {
        if isSelected {
            selectedSprite.alpha = 1
            let pulse = SKAction.sequence([
                SKAction.fadeAlpha(to: 0.35, duration: 0.45),
                SKAction.fadeAlpha(to: 1.0,  duration: 0.45)
            ])
            selectedSprite.run(.repeatForever(pulse), withKey: "pulse")
        } else {
            selectedSprite.removeAction(forKey: "pulse")
            selectedSprite.alpha = 0
        }
    }
}
