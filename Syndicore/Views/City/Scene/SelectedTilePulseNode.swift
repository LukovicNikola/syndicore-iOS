import SpriteKit

/// Cyan diamond outline koji pulsira iznad trenutno selektovanog tile-a.
/// Daje vizuelni "diše" feedback umesto statičke selected texture.
///
/// Koristi se iz CityScene.touchesEnded — na svaki tile select kreiramo nov,
/// na deselect uklanjamo. Animacija se pokrece automatski u init-u.
final class SelectedTilePulseNode: SKShapeNode {

    init(at position: CGPoint, zPosition: CGFloat) {
        super.init()

        // Diamond outline — match CityTileSet.tileSize (128 × 64)
        let tw = Isometric.tileWidth
        let th = Isometric.tileHeight
        let path = CGMutablePath()
        path.move(to:    CGPoint(x:  0,        y:  th / 2))
        path.addLine(to: CGPoint(x:  tw / 2,   y:  0))
        path.addLine(to: CGPoint(x:  0,        y: -th / 2))
        path.addLine(to: CGPoint(x: -tw / 2,   y:  0))
        path.closeSubpath()

        self.path = path
        strokeColor = SKColor(red: 0, green: 0.92, blue: 1.0, alpha: 1.0)
        lineWidth   = 2.5
        fillColor   = SKColor(red: 0, green: 0.92, blue: 1.0, alpha: 0.0)
        glowWidth   = 4.0

        self.position  = position
        self.zPosition = zPosition

        startPulse()
    }

    /// Repeating pulse: alpha 0.5 ↔ 1.0 + scale 1.0 ↔ 1.06, period 1.4s.
    private func startPulse() {
        let fadeOut = SKAction.fadeAlpha(to: 0.45, duration: 0.7)
        fadeOut.timingMode = .easeInEaseOut
        let fadeIn  = SKAction.fadeAlpha(to: 1.00, duration: 0.7)
        fadeIn.timingMode = .easeInEaseOut

        let scaleUp   = SKAction.scale(to: 1.06, duration: 0.7)
        scaleUp.timingMode = .easeInEaseOut
        let scaleDown = SKAction.scale(to: 1.00, duration: 0.7)
        scaleDown.timingMode = .easeInEaseOut

        let pulse = SKAction.sequence([
            .group([fadeOut, scaleUp]),
            .group([fadeIn,  scaleDown])
        ])
        run(.repeatForever(pulse), withKey: "pulse")
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("SelectedTilePulseNode is code-only")
    }
}
