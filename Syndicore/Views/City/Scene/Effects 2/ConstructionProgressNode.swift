import SpriteKit
import UIKit

/// Visible countdown + progress bar iznad zgrade koja se upgrade-uje.
final class ConstructionProgressNode: SKNode {

    private let label = SKLabelNode(fontNamed: "Menlo-Bold")
    private let barTrack: SKShapeNode
    private let barFill: SKShapeNode

    private static let barWidth: CGFloat = 80
    private static let barHeight: CGFloat = 6

    private let endsAt: Date

    var onComplete: (() -> Void)?
    private var didFireComplete = false

    init(endsAt: Date) {
        self.endsAt = endsAt

        let trackRect = CGRect(x: -Self.barWidth / 2, y: 0, width: Self.barWidth, height: Self.barHeight)
        barTrack = SKShapeNode(rect: trackRect, cornerRadius: Self.barHeight / 2)
        barTrack.fillColor = SKColor(red: 0.1, green: 0.1, blue: 0.15, alpha: 0.85)
        barTrack.strokeColor = SKColor(red: 0.0, green: 0.95, blue: 1.0, alpha: 0.5)
        barTrack.lineWidth = 1

        let fillRect = CGRect(x: 0, y: 0, width: Self.barWidth, height: Self.barHeight)
        barFill = SKShapeNode(rect: fillRect, cornerRadius: Self.barHeight / 2)
        barFill.fillColor = SKColor(red: 0.0, green: 0.95, blue: 1.0, alpha: 0.95)
        barFill.strokeColor = .clear
        barFill.position = CGPoint(x: -Self.barWidth / 2, y: 0)

        super.init()

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
            if !didFireComplete {
                didFireComplete = true
                onComplete?()
            }
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

    private func startBarAnimation() {
        let remaining = max(0, endsAt.timeIntervalSinceNow)
        guard remaining > 0 else { barFill.xScale = 0; return }
        barFill.xScale = 1
        let drain = SKAction.scaleX(to: 0, duration: remaining)
        drain.timingMode = .linear
        barFill.run(drain)
    }
}
