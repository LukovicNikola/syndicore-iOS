import SpriteKit

/// Animirana linija na mapi koja povezuje start i end točku movement-a.
/// Sadrži:
/// - Glavnu stroke liniju sa glow-om (color per movement type)
/// - Mali "particle" dot koji putuje duž linije ka cilju (pokazuje smer)
///
/// Lifecycle: kreira se u MapScene.setMovements(), uklanja kad movement.id
/// nestane iz aktivne liste (BE je kompletirao ili poslat return leg).
final class MovementLineNode: SKNode {

    let movementId: String
    private let line: SKShapeNode
    private let particle: SKSpriteNode

    init(movement: TroopMovement, start: CGPoint, end: CGPoint) {
        self.movementId = movement.id

        // Glavna linija
        let path = CGMutablePath()
        path.move(to: start)
        path.addLine(to: end)
        let ln = SKShapeNode(path: path)
        ln.strokeColor = Self.color(for: movement.type)
        ln.lineWidth = 2.0
        ln.glowWidth = 3.5
        ln.lineCap = .round
        // Dashed pattern za smer — solid za return leg
        if !movement.isReturning {
            let dashed = path.copy(dashingWithPhase: 0, lengths: [6, 4])
            ln.path = dashed
        }
        self.line = ln

        // Particle dot koji putuje po liniji (cyan glow)
        let dot = SKSpriteNode(texture: ParticleTextures.cyanGlowDot)
        dot.size = CGSize(width: 10, height: 10)
        dot.colorBlendFactor = 1.0
        dot.color = Self.color(for: movement.type)
        dot.blendMode = .add
        dot.zPosition = 1
        self.particle = dot

        super.init()

        addChild(line)
        addChild(dot)

        startParticleAnimation(from: start, to: end)
    }

    required init?(coder aDecoder: NSCoder) { fatalError("MovementLineNode is code-only") }

    /// Particle se kreće od start ka end u loop-u (svakih 1.8s).
    /// Nije ekzaktni sync sa stvarnim arrival time-om — cisto vizuelni indikator smera.
    private func startParticleAnimation(from start: CGPoint, to end: CGPoint) {
        particle.position = start
        let travel = SKAction.move(to: end, duration: 1.8)
        travel.timingMode = .easeInEaseOut
        let reset = SKAction.move(to: start, duration: 0)  // instant jump
        let hide  = SKAction.fadeOut(withDuration: 0.1)
        let show  = SKAction.fadeIn(withDuration: 0.1)
        let pause = SKAction.wait(forDuration: 0.3)
        let cycle = SKAction.sequence([travel, hide, reset, show, pause])
        particle.run(.repeatForever(cycle), withKey: "travel")
    }

    // MARK: - Styling

    private static func color(for type: MovementType) -> SKColor {
        switch type {
        case .ATTACK:    return SKColor(red: 1.0, green: 0.3, blue: 0.3, alpha: 0.9)
        case .RAID:      return SKColor(red: 1.0, green: 0.6, blue: 0.2, alpha: 0.9)
        case .SCOUT:     return SKColor(red: 0.0, green: 0.88, blue: 1.0, alpha: 0.9)
        case .REINFORCE: return SKColor(red: 0.4, green: 1.0, blue: 0.4, alpha: 0.9)
        case .TRANSPORT: return SKColor(red: 0.5, green: 0.6, blue: 1.0, alpha: 0.9)
        case .SETTLE:    return SKColor(red: 1.0, green: 0.9, blue: 0.3, alpha: 0.9)
        case .RETURN:    return SKColor(white: 0.7, alpha: 0.7)
        }
    }
}
