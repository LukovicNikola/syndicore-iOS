import SpriteKit
import UIKit

/// Reusable cyan glow dot textura — generišemo jednom (lazy), koristimo svuda.
/// Korisno za particle effects (electric arc, sparks, itd.) i HUD efekte.
enum ParticleTextures {

    /// Mali soft cyan glow disc (16×16 px) sa transparent fade ka ivicama.
    static let cyanGlowDot: SKTexture = {
        let size = CGSize(width: 16, height: 16)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            let cg = ctx.cgContext
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let colors = [
                UIColor(red: 0.0, green: 0.95, blue: 1.0, alpha: 1.0).cgColor,
                UIColor(red: 0.0, green: 0.95, blue: 1.0, alpha: 0.0).cgColor
            ]
            let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: colors as CFArray,
                locations: [0.0, 1.0]
            )!
            cg.drawRadialGradient(
                gradient,
                startCenter: center, startRadius: 0,
                endCenter: center, endRadius: size.width / 2,
                options: []
            )
        }
        return SKTexture(image: image)
    }()
}
