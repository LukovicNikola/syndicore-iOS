import SpriteKit

/// Ugaoni zidni komad — cyberpunk "L-shaped" bend koji pokriva diagonal cut
/// segment octagonal perimetra. Jedan primerak po svakom corner cutout regionu
/// (4 ukupno: N/E/S/W vertices octagonal-a).
///
/// Sprite source: 1024×1024 PNG, bend sa konkavom nagore (arms u V formaciji
/// izlaze gore-levo i gore-desno iz joint-a na dnu). zRotation-om rotiramo
/// u 4 orijentacije za N/E/S/W vertices octagonal-a.
final class WallCornerNode: SKNode {

    /// Proporcionalno skaliranje — sprite je 1:1.
    /// Anchor (0.5, 0.5) je obavezan jer se sprite rotira u 4 orijentacije:
    /// centered anchor garantuje da rotacija ne pomera vizuelni centar.
    private static let cornerSize = CGSize(
        width:  Isometric.tileWidth * 1.8,
        height: Isometric.tileWidth * 1.8
    )

    init(entry: WallLayout.WallEntry) {
        super.init()
        let sprite = SKSpriteNode(imageNamed: "wall_corner_v1")
        sprite.size        = Self.cornerSize
        sprite.anchorPoint = CGPoint(x: 0.5, y: 0.5)   // centered — critical za rotaciju
        sprite.zRotation   = entry.zRotation
        addChild(sprite)
        position  = entry.position
        zPosition = entry.zPosition
        isUserInteractionEnabled = false
    }

    required init?(coder: NSCoder) { fatalError("WallCornerNode is code-only") }
}
