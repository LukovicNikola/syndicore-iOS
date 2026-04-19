import SpriteKit

/// Cyan electric arc particle effect — koristi se na Power Grid building-u.
final class ElectricArcNode: SKNode {

    private static let arcWidth: CGFloat = 22

    private let emitter = SKEmitterNode()
    private let zigzag = SKShapeNode()

    override init() {
        super.init()
        setupEmitter()
        setupZigzag()
        addChild(emitter)
        addChild(zigzag)
        startZigzagRefresh()
    }

    required init?(coder aDecoder: NSCoder) { fatalError("ElectricArcNode is code-only") }

    private func setupEmitter() {
        emitter.particleTexture = ParticleTextures.cyanGlowDot
        emitter.particleBirthRate = 60
        emitter.numParticlesToEmit = 0
        emitter.particleLifetime = 0.35
        emitter.particleLifetimeRange = 0.15
        emitter.particlePositionRange = CGVector(dx: Self.arcWidth, dy: 4)
        emitter.particleScale = 0.9
        emitter.particleScaleRange = 0.4
        emitter.particleScaleSpeed = -2.0
        emitter.particleColor = SKColor(red: 0, green: 0.95, blue: 1.0, alpha: 1)
        emitter.particleColorBlendFactor = 1.0
        emitter.particleBlendMode = .add
        emitter.particleAlpha = 1.0
        emitter.particleAlphaSpeed = -3.0
        emitter.particleSpeed = 0
        emitter.particleSpeedRange = 0
    }

    private func setupZigzag() {
        zigzag.strokeColor = SKColor(red: 0.6, green: 0.98, blue: 1.0, alpha: 0.85)
        zigzag.lineWidth = 1.5
        zigzag.glowWidth = 2.0
        zigzag.lineCap = .round
        regenerateZigzagPath()
    }

    private func regenerateZigzagPath() {
        let path = CGMutablePath()
        let segments = 5
        let halfWidth = Self.arcWidth
        let startX = -halfWidth
        let endX = halfWidth
        let stepX = (endX - startX) / CGFloat(segments)
        path.move(to: CGPoint(x: startX, y: 0))
        for i in 1...segments {
            let x = startX + stepX * CGFloat(i)
            let y = (i == segments) ? 0 : CGFloat.random(in: -4...4)
            path.addLine(to: CGPoint(x: x, y: y))
        }
        zigzag.path = path
    }

    private func startZigzagRefresh() {
        let regenerate = SKAction.run { [weak self] in self?.regenerateZigzagPath() }
        let wait = SKAction.wait(forDuration: 0.06)
        run(.repeatForever(.sequence([regenerate, wait])), withKey: "zigzag")
    }
}
