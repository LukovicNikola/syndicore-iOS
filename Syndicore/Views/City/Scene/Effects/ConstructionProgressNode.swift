import SpriteKit
import UIKit

/// Visible countdown + progress bar iznad zgrade koja se upgrade-uje.
///
/// Sastoji se od:
/// - **SKLabelNode** sa countdown tekstom ("MM:SS" ili "Hh Mm" za duže) — refresh-uje se svake sekunde
/// - **SKShapeNode** progress bar (cyan fill + dark gray track) — animira fill width pomoću SKAction
///
/// Zelimo da bar fill ide sa duration = trenutni endsAt - now (linearno do 0).
/// Posto ne znamo TOTAL duration upgrade-a (ne čuvamo startedAt), bar je
/// "remaining-time" indikator: na momentu init-a bar pokazuje 100%, do endsAt
/// linearno dolazi do 0%.
final class ConstructionProgressNode: SKNode {

    private let label = SKLabelNode(fontNamed: "Menlo-Bold")
    private let barTrack: SKShapeNode
    private let barFill: SKShapeNode

    private static let barWidth: CGFloat = 80
    private static let barHeight: CGFloat = 6

    private let endsAt: Date

    init(endsAt: Date) {
        self.endsAt = endsAt

        // Bar track (background)
        let trackRect = CGRect(
            x: -Self.barWidth / 2,
            y: 0,
            width: Self.barWidth,
            height: Self.barHeight
        )
        barTrack = SKShapeNode(rect: trackRect, cornerRadius: Self.barHeight / 2)
        barTrack.fillColor = SKColor(red: 0.1, green: 0.1, blue: 0.15, alpha: 0.85)
        barTrack.strokeColor = SKColor(red: 0.0, green: 0.95, blue: 1.0, alpha: 0.5)
        barTrack.lineWidth = 1

        // Bar fill (cyan, anchored levo da scale-X ide od leve ivice)
        let fillRect = CGRect(
            x: 0,
            y: 0,
            width: Self.barWidth,
            height: Self.barHeight
        )
        barFill = SKShapeNode(rect: fillRect, cornerRadius: Self.barHeight / 2)
        barFill.fillColor = SKColor(red: 0.0, green: 0.95, blue: 1.0, alpha: 0.95)
        barFill.strokeColor = .clear
        // SKShapeNode rect je drawn from fillRect.x — postavljamo node pozicije
        // tako da je leva ivica na -barWidth/2 (isto kao track)
        barFill.position = CGPoint(x: -Self.barWidth / 2, y: 0)

        super.init()

        // Label iznad bara
        label.fontSize = 12
        label.fontColor = .white
        label.verticalAlignmentMode = .bottom
        label.horizontalAlignmentMode = .center
        label.position = CGPoint(x: 0, y: Self.barHeight + 4)

        addChild(barTrack)
        addChild(barFill)
        addChild(label)

        startCountdown()
        startBarAnimation()
    }

    required init?(coder: NSCoder) { fatalError("ConstructionProgressNode is code-only") }

    // MARK: - Countdown text refresh

    /// Update label svake sekunde sa MM:SS / HhMm format.
    private func startCountdown() {
        updateLabel()
        let tick = SKAction.run { [weak self] in self?.updateLabel() }
        let wait = SKAction.wait(forDuration: 1.0)
        run(.repeatForever(.sequence([tick, wait])), withKey: "countdown")
    }

    private func updateLabel() {
        let remaining = max(0, endsAt.timeIntervalSinceNow)
        if remaining <= 0 {
            label.text = "READY"
            label.fontColor = SKColor(red: 0.5, green: 1.0, blue: 0.5, alpha: 1)
            removeAction(forKey: "countdown")
            return
        }
        label.text = formatRemaining(remaining)
    }

    private func formatRemaining(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 { return String(format: "%dh %02dm", h, m) }
        return String(format: "%02d:%02d", m, s)
    }

    // MARK: - Bar fill animation

    /// Bar fill se linearno smanjuje od 100% do 0% za remaining vreme.
    /// xScale 1.0 → 0.0 sa duration = remaining seconds.
    private func startBarAnimation() {
        let remaining = max(0, endsAt.timeIntervalSinceNow)
        guard remaining > 0 else {
            barFill.xScale = 0
            return
        }
        barFill.xScale = 1
        let drain = SKAction.scaleX(to: 0, duration: remaining)
        drain.timingMode = .linear
        barFill.run(drain)
    }
}
