import SpriteKit

/// "+X CRD" floating tekst koji se pojavi iznad zgrade i fade-out odlazi na gore.
final class ResourceTickNode: SKNode {

    enum Resource: String {
        case credits = "CRD"
        case alloys  = "ALY"
        case tech    = "TCH"
        case energy  = "NRG"

        var color: SKColor {
            switch self {
            case .credits: return SKColor(red: 1.0, green: 0.85, blue: 0.2, alpha: 1)
            case .alloys:  return SKColor(red: 0.55, green: 0.85, blue: 0.4, alpha: 1)
            case .tech:    return SKColor(red: 0.0, green: 0.95, blue: 1.0, alpha: 1)
            case .energy:  return SKColor(red: 1.0, green: 0.55, blue: 0.0, alpha: 1)
            }
        }
    }

    init(amount: Int, resource: Resource, at position: CGPoint, zPosition: CGFloat) {
        super.init()
        self.position  = position
        self.zPosition = zPosition
        self.alpha     = 0.0

        let label = SKLabelNode(fontNamed: "Menlo-Bold")
        label.text = "+\(amount) \(resource.rawValue)"
        label.fontSize = 14
        label.fontColor = resource.color
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        addChild(label)

        runFloatAnimation()
    }

    required init?(coder aDecoder: NSCoder) { fatalError("ResourceTickNode is code-only") }

    private func runFloatAnimation() {
        let fadeIn  = SKAction.fadeAlpha(to: 1.0, duration: 0.2)
        let moveUp  = SKAction.moveBy(x: 0, y: 70, duration: 1.4)
        moveUp.timingMode = .easeOut
        let fadeOut = SKAction.fadeAlpha(to: 0.0, duration: 1.4)
        let cleanup = SKAction.removeFromParent()
        run(.sequence([fadeIn, .group([moveUp, fadeOut]), cleanup]))
    }
}
