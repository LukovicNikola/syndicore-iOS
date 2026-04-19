import SpriteKit
import UIKit

/// Floating info tooltip koji se prikazuje iznad zgrade na long-press.
/// Sadrži building name + level + sprite preview. Auto-dismisses posle 2.5s
/// ili kad user tapne van nje.
final class BuildingTooltipNode: SKNode {

    private let bg: SKShapeNode
    private let label: SKLabelNode

    private static let padding: CGFloat = 8
    private static let cornerRadius: CGFloat = 6

    init(building: BuildingInfo) {
        // Format: "BARRACKS — L3" ili "BARRACKS — L3 → L4 (upgrading)"
        let displayName = building.type.rawValue.replacingOccurrences(of: "_", with: " ")
        var text = "\(displayName) — L\(building.currentLevel)"
        if let target = building.targetLevel {
            text += " → L\(target)"
        }

        // Label (dimensions determine bg size)
        let lbl = SKLabelNode(fontNamed: "Menlo-Bold")
        lbl.text = text
        lbl.fontSize = 12
        lbl.fontColor = .white
        lbl.verticalAlignmentMode = .center
        lbl.horizontalAlignmentMode = .center
        self.label = lbl

        // Background sized to label + padding
        let w = lbl.frame.width + Self.padding * 2
        let h = lbl.frame.height + Self.padding * 2
        let bgRect = CGRect(x: -w / 2, y: -h / 2, width: w, height: h)
        let bg = SKShapeNode(rect: bgRect, cornerRadius: Self.cornerRadius)
        bg.fillColor = SKColor(red: 0.08, green: 0.08, blue: 0.12, alpha: 0.92)
        bg.strokeColor = SKColor(red: 0.0, green: 0.92, blue: 1.0, alpha: 0.8)
        bg.lineWidth = 1
        self.bg = bg

        super.init()

        addChild(bg)
        addChild(lbl)
        alpha = 0.0

        runShowThenDismiss()
    }

    required init?(coder: NSCoder) { fatalError("BuildingTooltipNode is code-only") }

    private func runShowThenDismiss() {
        // Fade in → hold 2.5s → fade out → remove
        let fadeIn  = SKAction.fadeAlpha(to: 1.0, duration: 0.15)
        let hold    = SKAction.wait(forDuration: 2.5)
        let fadeOut = SKAction.fadeAlpha(to: 0.0, duration: 0.3)
        let cleanup = SKAction.removeFromParent()
        run(.sequence([fadeIn, hold, fadeOut, cleanup]))
    }
}
