import SpriteKit

/// Burst particle effekt za construction-complete moment.
final class CelebrationBurstNode: SKNode {

    override init() {
        super.init()
        setupEmitter()
        scheduleCleanup()
    }

    required init?(coder aDecoder: NSCoder) { fatalError("CelebrationBurstNode is code-only") }

    private func setupEmitter() {
        let emitter = SKEmitterNode()
        emitter.particleTexture = ParticleTextures.cyanGlowDot
        emitter.particleBirthRate = 400
        emitter.numParticlesToEmit = 60
        emitter.particleLifetime = 1.0
        emitter.particleLifetimeRange = 0.4
        emitter.particleScale = 0.7
        emitter.particleScaleRange = 0.3
        emitter.particleScaleSpeed = -0.4
        emitter.particleColor = SKColor(red: 0, green: 0.95, blue: 1.0, alpha: 1)
        emitter.particleColorBlendFactor = 1.0
        emitter.particleBlendMode = .add
        emitter.particleSpeed = 110
        emitter.particleSpeedRange = 50
        emitter.emissionAngle = 0
        emitter.emissionAngleRange = .pi * 2
        emitter.particleAlpha = 1.0
        emitter.particleAlphaSpeed = -0.7
        emitter.yAcceleration = -50
        addChild(emitter)
    }

    private func scheduleCleanup() {
        run(.sequence([.wait(forDuration: 2.0), .removeFromParent()]))
    }
}
