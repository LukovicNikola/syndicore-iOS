import SpriteKit
import UIKit

/// Sprite za izgrađenu zgradu (1×1 footprint). HQ ide kroz HQNode (2×2).
/// Sve dimenzije i anchor čitaju se iz `SpriteCatalog` — single source of truth.
/// Ako asset ne postoji u bundle-u, prikazuje placeholder (samo scaffold ako je u izgradnji).
final class BuildingNode: SKNode {
    let building: BuildingInfo

    /// Glavni sprite (zgrada ili scaffold). Cuvamo referencu da možemo da animiramo
    /// na tap (selection pulse).
    private let spriteNode: SKSpriteNode?

    /// Scaffold sprite size — non-uniform, prati staro ponašanje. Refaktor kad bude novi scaffold sprite.
    private static let scaffoldSize = CGSize(
        width:  Isometric.tileWidth,
        height: Isometric.tileHeight * 1.5
    )

    init(building: BuildingInfo, col: Int, row: Int) {
        self.building = building
        let spec = SpriteCatalog.spec(for: building.type)

        // Pripremi sprite pre super.init (Swift 6 init order)
        var resolvedSprite: SKSpriteNode? = nil
        if building.isUpgrading {
            let scaffold = SKSpriteNode(imageNamed: "construction_scaffold_v1")
            scaffold.size = Self.scaffoldSize
            scaffold.anchorPoint = CGPoint(x: 0.5, y: 0.0)
            resolvedSprite = scaffold
        } else if SpriteCatalog.assetExists(spec) {
            let sprite = SKSpriteNode(imageNamed: spec.assetName)
            sprite.size = spec.renderSize
            sprite.anchorPoint = spec.anchor
            sprite.zRotation = spec.rotationRadians
            resolvedSprite = sprite
        }
        self.spriteNode = resolvedSprite

        super.init()

        if let s = resolvedSprite { addChild(s) }
        // Ako tekstura ne postoji i nije u izgradnji — tile ostaje prazan

        position  = Isometric.scenePosition(col: col, row: row)
        zPosition = Isometric.zDepth(col: col, row: row) + 0.5
        isUserInteractionEnabled = false
    }

    /// Brzi scale pulse animacija — poziva se kad user tapne zgradu.
    /// Idempotent: ako je pulse već u toku, restartuje od početka.
    func playTapPulse() {
        guard let sprite = spriteNode else { return }
        sprite.removeAction(forKey: "tapPulse")
        let up   = SKAction.scale(to: 1.08, duration: 0.10)
        up.timingMode = .easeOut
        let down = SKAction.scale(to: 1.00, duration: 0.18)
        down.timingMode = .easeIn
        sprite.run(.sequence([up, down]), withKey: "tapPulse")
    }

    required init?(coder: NSCoder) { fatalError("BuildingNode is code-only; not decodable from XIB") }
}
