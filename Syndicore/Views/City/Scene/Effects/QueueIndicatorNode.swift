import SpriteKit

/// Mali pulse dot iznad HQ-a koji signalizira da postoji aktivna gradnja u queue-u.
/// Prikazuje se kad god `City.constructionQueue` nije nil. Auto-pulses zauvek.
final class QueueIndicatorNode: SKNode {

    private let dot: SKShapeNode
    private let icon: SKLabelNode

    override init() {
        // Mali cyan disk sa lagano outline
        dot = SKShapeNode(circleOfRadius: 9)
        dot.fillColor = SKColor(red: 0, green: 0.92, blue: 1.0, alpha: 0.9)
        dot.strokeColor = SKColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.9)
        dot.lineWidth = 1.5
        dot.glowWidth = 3.0

        // Hammer ikonica iznutra (Unicode emoji)
        icon = SKLabelNode(text: "🔨")
        icon.fontSize = 11
        icon.verticalAlignmentMode = .center
        icon.horizontalAlignmentMode = .center
        icon.position = .zero

        super.init()

        addChild(dot)
        addChild(icon)
        startPulse()
    }

    required init?(coder aDecoder: NSCoder) { fatalError("QueueIndicatorNode is code-only") }

    /// Slow scale pulse — dot "diše" 1.0 ↔ 1.15, period 1.6s.
    private func startPulse() {
        let up   = SKAction.scale(to: 1.15, duration: 0.8)
        up.timingMode = .easeInEaseOut
        let down = SKAction.scale(to: 1.00, duration: 0.8)
        down.timingMode = .easeInEaseOut
        run(.repeatForever(.sequence([up, down])), withKey: "pulse")
    }
}
