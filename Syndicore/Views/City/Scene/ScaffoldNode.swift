import SpriteKit

/// Skele u izgradnji za prazne slotove koji su "queued" (reservation bez zgrade).
/// Normalno se ne koristi — scaffold overlay je deo BuildingNode kad je isUpgrading.
/// Ovaj node se koristi ako BE u budućnosti vrati "slot reserved but not started".
final class ScaffoldNode: SKNode {
    init(col: Int, row: Int) {
        super.init()
        let sprite = SKSpriteNode(imageNamed: "construction_scaffold_v1")
        addChild(sprite)
        position  = Isometric.scenePosition(col: col, row: row)
        zPosition = Isometric.zDepth(col: col, row: row) + 0.5
        isUserInteractionEnabled = false
    }

    required init?(coder: NSCoder) { fatalError() }
}
