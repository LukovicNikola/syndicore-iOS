import SpriteKit

/// "+X CRD" floating tekst koji se pojavi iznad zgrade i fade-out odlazi na gore.
/// Spawn-uje se iz CityScene.configure(with:) kad se primeti pozitivan delta na resources.
final class ResourceTickNode: SKLabelNode {

    enum Resource: String {
        case credits = "CRD"
        case alloys  = "ALY"
        case tech    = "TCH"
        case energy  = "NRG"

        var color: SKColor {
            switch self {
            case .credits: return SKColor(red: 1.0, green: 0.85, blue: 0.2, alpha: 1)  // gold/yellow
            case .alloys:  return SKColor(red: 0.55, green: 0.85, blue: 0.4, alpha: 1) // green
            case .tech:    return SKColor(red: 0.0, green: 0.95, blue: 1.0, alpha: 1)  // cyan
            case .energy:  return SKColor(red: 1.0, green: 0.55, blue: 0.0, alpha: 1)  // orange
            }
        }
    }

    init(amount: Int, resource: Resource, at position: CGPoint, zPosition: CGFloat) {
        super.init(fontNamed: "Menlo-Bold")
        text = "+\(amount) \(resource.rawValue)"
        fontSize = 14
        fontColor = resource.color
        verticalAlignmentMode = .center
        horizontalAlignmentMode = .center
        self.position = position
        self.zPosition = zPosition
        alpha = 0.0  // krene od 0, fade in u animaciji

        runFloatAnimation()
    }

    required init?(coder aDecoder: NSCoder) { fatalError("ResourceTickNode is code-only") }

    /// Animation: fade in (0.2s) → float up + fade out (1.4s) → ukloni se iz scene.
    private func runFloatAnimation() {
        let fadeIn  = SKAction.fadeAlpha(to: 1.0, duration: 0.2)
        let moveUp  = SKAction.moveBy(x: 0, y: 70, duration: 1.4)
        moveUp.timingMode = .easeOut
        let fadeOut = SKAction.fadeAlpha(to: 0.0, duration: 1.4)
        let cleanup = SKAction.removeFromParent()

        run(.sequence([
            fadeIn,
            .group([moveUp, fadeOut]),
            cleanup
        ]))
    }
}
