import SpriteKit

/// Ugaoni zidni komad — cyberpunk "L-shaped" bend koji pokriva diagonal cut
/// segment octagonal perimetra. Jedan primerak po svakom corner cutout regionu
/// (4 ukupno: N/E/S/W vertices octagonal-a).
///
/// Sprite source: 1024×1024 PNG, bend sa konkavom nagore (arms u V formaciji
/// izlaze gore-levo i gore-desno iz joint-a na dnu). zRotation-om rotiramo
/// u 4 orijentacije za N/E/S/W vertices octagonal-a.
final class WallCornerNode: SKNode {

    /// Proporcionalno skaliranje — sprite je 1:1, rendered kao 2.8× tileWidth
    /// (širok kao 2 tile-a + neki overlap sa cardinal walls na oba kraja).
    private static let cornerSize = CGSize(
        width:  Isometric.tileWidth * 2.8,
        height: Isometric.tileWidth * 2.8
    )

    init(entry: WallLayout.WallEntry) {
        super.init()
        let sprite = SKSpriteNode(imageNamed: "wall_corner_v1")
        sprite.size        = Self.cornerSize
        sprite.anchorPoint = CGPoint(x: 0.5, y: 0.25)
        sprite.zRotation   = entry.zRotation
        addChild(sprite)
        position  = entry.position
        zPosition = entry.zPosition
        isUserInteractionEnabled = false
    }

    required init?(coder: NSCoder) { fatalError("WallCornerNode is code-only") }
}
