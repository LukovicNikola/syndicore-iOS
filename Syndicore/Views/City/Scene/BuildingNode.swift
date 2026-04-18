import SpriteKit
import UIKit

/// Sprite za izgrađenu zgradu (1×1 footprint). HQ ide kroz HQNode (2×2).
/// Sve dimenzije i anchor čitaju se iz `SpriteCatalog` — single source of truth.
/// Ako asset ne postoji u bundle-u, prikazuje placeholder (samo scaffold ako je u izgradnji).
final class BuildingNode: SKNode {
    let building: BuildingInfo

    /// Scaffold sprite size — non-uniform, prati staro ponašanje. Refaktor kad bude novi scaffold sprite.
    private static let scaffoldSize = CGSize(
        width:  Isometric.tileWidth,
        height: Isometric.tileHeight * 1.5
    )

    init(building: BuildingInfo, col: Int, row: Int) {
        self.building = building
        super.init()

        let spec = SpriteCatalog.spec(for: building.type)

        if building.isUpgrading {
            // Zgrada u izgradnji — prikaži scaffold (placeholder dok se ne izgradi)
            let scaffold = SKSpriteNode(imageNamed: "construction_scaffold_v1")
            scaffold.size = Self.scaffoldSize
            scaffold.anchorPoint = CGPoint(x: 0.5, y: 0.0)
            addChild(scaffold)
        } else if SpriteCatalog.assetExists(spec) {
            // Tekstura postoji u catalogu — prikaži zgradu
            let sprite = SKSpriteNode(imageNamed: spec.assetName)
            sprite.size = spec.renderSize
            sprite.anchorPoint = spec.anchor
            addChild(sprite)
        }
        // Ako tekstura ne postoji i nije u izgradnji — tile ostaje prazan

        position  = Isometric.scenePosition(col: col, row: row)
        zPosition = Isometric.zDepth(col: col, row: row) + 0.5
        isUserInteractionEnabled = false
    }

    required init?(coder: NSCoder) { fatalError("BuildingNode is code-only; not decodable from XIB") }
}
