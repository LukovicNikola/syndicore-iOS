import SpriteKit

/// Burst particle effekt za construction-complete moment.
/// Eksplozija cyan particles iz origin tačke u svim smerovima, ~1.5s lifetime.
/// Auto-removes from parent posle završetka anim.
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

        // Burst (ne continuous) — eksplodira jednom u 0.15s
        emitter.particleBirthRate = 400
        emitter.numParticlesToEmit = 60
        emitter.particleLifetime = 1.0
        emitter.particleLifetimeRange = 0.4

        // Skala
        emitter.particleScale = 0.7
        emitter.particleScaleRange = 0.3
        emitter.particleScaleSpeed = -0.4

        // Boja
        emitter.particleColor = SKColor(red: 0, green: 0.95, blue: 1.0, alpha: 1)
        emitter.particleColorBlendFactor = 1.0
        emitter.particleBlendMode = .add

        // Speed: razletu se u svim smerovima
        emitter.particleSpeed = 110
        emitter.particleSpeedRange = 50
        emitter.emissionAngle = 0
        emitter.emissionAngleRange = .pi * 2  // 360°

        // Alpha fade
        emitter.particleAlpha = 1.0
        emitter.particleAlphaSpeed = -0.7

        // Mala gravitacija ka dole — particles padaju na kraju
        emitter.yAcceleration = -50

        addChild(emitter)
    }

    private func scheduleCleanup() {
        // Wait dok particles žive (lifetime ~1.4s + safety) onda remove
        run(.sequence([.wait(forDuration: 2.0), .removeFromParent()]))
    }
}
