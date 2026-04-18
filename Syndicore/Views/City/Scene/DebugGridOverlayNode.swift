import SpriteKit

/// Debug overlay za vizuelnu verifikaciju iso alignment-a.
/// Crta cyan diamond outline za svaki buildable tile + magenta dot na anchor pozicijama.
/// Toggle preko `CityScene.setDebugOverlay(_:)`.
///
/// **TODO:** implementacija ide u Phase 3a (vidi CLAUDE.md TODO listu).
/// Trenutno je stub — instancira se ali ne renderuje ništa dok se ne završi.
final class DebugGridOverlayNode: SKNode {
    override init() {
        super.init()
        zPosition = 1000  // iznad svega
        // TODO Phase 3a: dodati SKShapeNode za svaki tile (cyan diamond outline)
        //                + SKShapeNode dot na svakoj anchor poziciji (magenta)
    }

    required init?(coder: NSCoder) { fatalError("DebugGridOverlayNode is code-only") }
}
