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

    /// Construction progress overlay (samo za upgrading buildings).
    /// Public read-access da CityScene može da prikači onComplete callback.
    private(set) var progressNode: ConstructionProgressNode?

    init(building: BuildingInfo, col: Int, row: Int, forceScaffold: Bool = false, queueEndsAt: Date? = nil) {
        self.building = building
        let spec = SpriteCatalog.spec(for: building.type)
        let scaffoldSpec = SpriteCatalog.scaffold

        // Pripremi sprite pre super.init (Swift 6 init order)
        var resolvedSprite: SKSpriteNode? = nil
        if building.isUpgrading || forceScaffold {
            let scaffold = SKSpriteNode(imageNamed: scaffoldSpec.assetName)
            scaffold.size = scaffoldSpec.renderSize
            scaffold.anchorPoint = scaffoldSpec.anchor
            scaffold.zRotation = scaffoldSpec.rotationRadians
            resolvedSprite = scaffold
        } else if SpriteCatalog.assetExists(spec) {
            let sprite = SKSpriteNode(imageNamed: spec.assetName)
            sprite.size = spec.renderSize
            sprite.anchorPoint = spec.anchor
            sprite.zRotation = spec.rotationRadians
            resolvedSprite = sprite
        } else {
            // Asset ne postoji — prikaži placeholder tile da tile ne ostane prazan
            let placeholder = SKSpriteNode(imageNamed: "tile_empty_v1")
            placeholder.size = CGSize(width: Isometric.tileWidth, height: Isometric.tileHeight)
            placeholder.anchorPoint = CGPoint(x: 0.5, y: 0.5)
            placeholder.alpha = 0.5
            placeholder.color = .orange
            placeholder.colorBlendFactor = 0.6
            resolvedSprite = placeholder
        }
        self.spriteNode = resolvedSprite

        super.init()

        if let s = resolvedSprite { addChild(s) }
        // Ako tekstura ne postoji i nije u izgradnji — tile ostaje prazan

        // Per-building particle effekti (samo kad zgrada NIJE u izgradnji)
        if !building.isUpgrading, !forceScaffold, resolvedSprite != nil {
            attachParticleEffect(for: building.type)
        }

        // Construction progress overlay — countdown + progress bar iznad scaffold-a
        // endsAt dolazi sa building-a (upgrade) ili iz queue-a (nova gradnja, forceScaffold).
        let effectiveEndsAt = building.endsAt ?? queueEndsAt
        if (building.isUpgrading || forceScaffold), let endsAt = effectiveEndsAt {
            let progress = ConstructionProgressNode(endsAt: endsAt)
            // Pozicija iznad scaffold-a — vrh scaffold-a je renderHeight × (1 - anchorY) iznad anchor-a
            let scaffoldTop = scaffoldSpec.renderHeight * (1 - scaffoldSpec.anchor.y)
            progress.position = CGPoint(x: 0, y: scaffoldTop + 8)
            progress.zPosition = 0.5  // iznad scaffold-a u istom node-u
            progress.isHidden = true
            addChild(progress)
            self.progressNode = progress
        }

        position  = Isometric.scenePosition(col: col, row: row)
        zPosition = Isometric.zDepth(col: col, row: row) + 0.5
        isUserInteractionEnabled = false
    }

    /// Dodaje per-building particle efekt iznad sprite-a (npr. electric arc za Power Grid).
    /// Pozicije su tunirane manuelno — vidi komentare za svaki case.
    private func attachParticleEffect(for type: BuildingType) {
        switch type {
        case .POWER_GRID:
            // Arc lebdi između dva cooling tower-a (vrh sprite-a, malo ulevo od centra).
            let arc = ElectricArcNode()
            arc.position = CGPoint(x: 0, y: Isometric.tileWidth * 0.55)
            arc.zPosition = 0.1   // iznad sprite-a u istom node-u
            addChild(arc)
        default:
            break
        }
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
