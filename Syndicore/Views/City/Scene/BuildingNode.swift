import SpriteKit
import UIKit

/// Sprite za izgrađenu zgradu. Ako je `isUpgrading`, prikazuje scaffold overlay.
/// Ako tekstura za tip zgrade ne postoji u asset katalogu, prikazuje samo scaffold placeholder.
final class BuildingNode: SKNode {
    let building: BuildingInfo

    private static let buildingSize = CGSize(
        width:  Isometric.tileWidth,
        height: Isometric.tileWidth
    )
    private static let scaffoldSize = CGSize(
        width:  Isometric.tileWidth,
        height: Isometric.tileHeight * 1.5
    )

    init(building: BuildingInfo, col: Int, row: Int) {
        self.building = building
        super.init()

        let textureName = building.type.rawValue.lowercased() + "_v1"

        if building.isUpgrading {
            // Zgrada u izgradnji — prikaži scaffold
            let scaffold = SKSpriteNode(imageNamed: "construction_scaffold_v1")
            scaffold.size        = Self.scaffoldSize
            scaffold.anchorPoint = CGPoint(x: 0.5, y: 0.0)
            addChild(scaffold)
        } else if UIImage(named: textureName) != nil {
            // Tekstura postoji — prikaži zgradu
            let sprite = SKSpriteNode(imageNamed: textureName)
            sprite.size        = Self.buildingSize
            sprite.anchorPoint = CGPoint(x: 0.5, y: 0.25)
            addChild(sprite)
        }
        // Ako tekstura ne postoji i nije u izgradnji — tile ostaje prazan (ništa ne dodajemo)

        position  = Isometric.scenePosition(col: col, row: row)
        zPosition = Isometric.zDepth(col: col, row: row) + 0.5
        isUserInteractionEnabled = false
    }

    required init?(coder: NSCoder) { fatalError() }
}
