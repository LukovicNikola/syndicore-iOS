import SpriteKit

/// Cyan electric arc particle effect — koristi se na Power Grid building-u
/// (između dva cooling tower-a).
///
/// Implementacija:
/// - SKEmitterNode sa cyan glow dot teksturom (vidi `ParticleTextures.cyanGlowDot`)
/// - Particles spawn-uju u uskom horizontalnom range-u (simulira arc liniju)
/// - Kratki lifetime + brza scale-down + alpha-down = "treperi" efekat
/// - Plus dodatni SKShapeNode zigzag putanja koja se randomly osvežava (jasnija arc linija)
final class ElectricArcNode: SKNode {

    /// Width arc-a — koliko široko se particles raspadaju levo/desno
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

    // MARK: - Particle emitter setup

    private func setupEmitter() {
        emitter.particleTexture = ParticleTextures.cyanGlowDot
        emitter.particleBirthRate = 60
        emitter.numParticlesToEmit = 0       // 0 = beskonačno
        emitter.particleLifetime = 0.35
        emitter.particleLifetimeRange = 0.15

        // Pozicija: random horizontal jitter (simulira kretanje arc-a po dužini)
        emitter.particlePositionRange = CGVector(dx: Self.arcWidth, dy: 4)

        // Skala: krene veliko, brzo se smanji
        emitter.particleScale = 0.9
        emitter.particleScaleRange = 0.4
        emitter.particleScaleSpeed = -2.0   // shrink brzo

        // Boja: cyan
        emitter.particleColor = SKColor(red: 0, green: 0.95, blue: 1.0, alpha: 1)
        emitter.particleColorBlendFactor = 1.0
        emitter.particleBlendMode = .add

        // Alpha: krene punim, brzo fade out
        emitter.particleAlpha = 1.0
        emitter.particleAlphaSpeed = -3.0

        // Bez kretanja — particles "trepere" u mestu
        emitter.particleSpeed = 0
        emitter.particleSpeedRange = 0
    }

    // MARK: - Zigzag arc line

    /// Crta zigzag liniju između leve i desne tačke arc-a.
    /// Refresh-uje se svakih 0.06s (random putanja) — daje "živi" arc efekat.
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
            // Random Y jitter (levo-desno alternira za zigzag look)
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
