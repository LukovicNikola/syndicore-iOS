import SpriteKit

/// Debug overlay za vizuelnu verifikaciju iso alignment-a sprajtova.
///
/// Renderuje:
/// - **Cyan diamond outline** za svaki buildable tile (anchor (0.5, 0.5) → centar)
/// - **Magenta dot** na poziciji gde bi sprite anchor trebalo da bude (za default (0.5, 0.25))
/// - **Orange outline** za HQ 2×2 region (ekvivalent 4 tile-a)
/// - **Red X** na pozicijama u cornerCutouts (da vidiš šta je obrisano)
/// - **Green label** sa (col, row) brojem na svakom tile-u
///
/// Toggle preko `CityScene.setDebugOverlay(_:)` ili `SettingsView` toggle-a.
final class DebugGridOverlayNode: SKNode {

    override init() {
        super.init()
        zPosition = 1000  // iznad svega

        drawTileDiamonds()
        drawAnchorDots()
        drawHQRegionOutline()
        drawCutoutMarkers()
    }

    required init?(coder: NSCoder) { fatalError("DebugGridOverlayNode is code-only") }

    // MARK: - Drawing

    private func drawTileDiamonds() {
        let n = Isometric.gridSize
        for col in 0..<n {
            for row in 0..<n {
                guard Isometric.isBuildable(col: col, row: row) else { continue }
                let diamond = makeTileDiamond()
                diamond.position = Isometric.scenePosition(col: col, row: row)
                diamond.zPosition = 0
                addChild(diamond)

                let label = SKLabelNode(text: "\(col),\(row)")
                label.fontName = "Menlo-Bold"
                label.fontSize = 10
                label.fontColor = SKColor(red: 0.4, green: 1.0, blue: 0.4, alpha: 0.9)
                label.verticalAlignmentMode = .center
                label.horizontalAlignmentMode = .center
                label.position = Isometric.scenePosition(col: col, row: row)
                label.zPosition = 2
                addChild(label)
            }
        }
    }

    private func drawAnchorDots() {
        let n = Isometric.gridSize
        for col in 0..<n {
            for row in 0..<n {
                guard Isometric.isBuildable(col: col, row: row) else { continue }
                let dot = SKShapeNode(circleOfRadius: 3)
                dot.fillColor = SKColor(red: 1.0, green: 0.2, blue: 0.8, alpha: 1.0)
                dot.strokeColor = .clear
                dot.position = Isometric.scenePosition(col: col, row: row)
                dot.zPosition = 3
                addChild(dot)
            }
        }
    }

    private func drawHQRegionOutline() {
        // HQ pokriva 4 tile-a — nacrtaj outline koji ih obuhvata.
        let topLeft     = Isometric.scenePosition(col: Isometric.hqOriginCoord.col,     row: Isometric.hqOriginCoord.row)
        let topRight    = Isometric.scenePosition(col: Isometric.hqOriginCoord.col + 1, row: Isometric.hqOriginCoord.row)
        let bottomLeft  = Isometric.scenePosition(col: Isometric.hqOriginCoord.col,     row: Isometric.hqOriginCoord.row + 1)
        let bottomRight = Isometric.scenePosition(col: Isometric.hqOriginCoord.col + 1, row: Isometric.hqOriginCoord.row + 1)

        // Obuhvatni diamond: top vertex, right vertex, bottom vertex, left vertex
        let tw = Isometric.tileWidth
        let th = Isometric.tileHeight

        let path = CGMutablePath()
        path.move(to:    CGPoint(x: topLeft.x,    y: topLeft.y     + th / 2))  // top
        path.addLine(to: CGPoint(x: topRight.x   + tw / 2, y: topRight.y))      // right
        path.addLine(to: CGPoint(x: bottomRight.x, y: bottomRight.y - th / 2)) // bottom
        path.addLine(to: CGPoint(x: bottomLeft.x - tw / 2, y: bottomLeft.y))    // left
        path.closeSubpath()

        let outline = SKShapeNode(path: path)
        outline.strokeColor = SKColor(red: 1.0, green: 0.6, blue: 0.0, alpha: 0.9)
        outline.lineWidth = 2
        outline.fillColor = .clear
        outline.zPosition = 1
        addChild(outline)

        let label = SKLabelNode(text: "HQ 2×2")
        label.fontName = "Menlo-Bold"
        label.fontSize = 12
        label.fontColor = SKColor(red: 1.0, green: 0.6, blue: 0.0, alpha: 1.0)
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        label.position = Isometric.hqCenterPosition
        label.zPosition = 2
        addChild(label)
    }

    private func drawCutoutMarkers() {
        for cutout in Isometric.cornerCutouts {
            let marker = SKLabelNode(text: "✕")
            marker.fontName = "Menlo-Bold"
            marker.fontSize = 14
            marker.fontColor = SKColor(red: 1.0, green: 0.2, blue: 0.2, alpha: 0.6)
            marker.verticalAlignmentMode = .center
            marker.horizontalAlignmentMode = .center
            marker.position = Isometric.scenePosition(col: cutout.col, row: cutout.row)
            marker.zPosition = 2
            addChild(marker)
        }
    }

    // MARK: - Diamond builder

    private func makeTileDiamond() -> SKShapeNode {
        let tw = Isometric.tileWidth
        let th = Isometric.tileHeight

        let path = CGMutablePath()
        path.move(to:    CGPoint(x: 0,      y:  th / 2))  // top
        path.addLine(to: CGPoint(x: tw / 2, y:  0))       // right
        path.addLine(to: CGPoint(x: 0,      y: -th / 2))  // bottom
        path.addLine(to: CGPoint(x: -tw / 2, y: 0))       // left
        path.closeSubpath()

        let diamond = SKShapeNode(path: path)
        diamond.strokeColor = SKColor(red: 0.0, green: 0.88, blue: 1.0, alpha: 0.7)
        diamond.lineWidth = 1
        diamond.fillColor = .clear
        return diamond
    }
}
