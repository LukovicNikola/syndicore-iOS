import SwiftUI
import SpriteKit

/// SwiftUI wrapper oko CityScene (UIViewRepresentable da bi mogli da update-ujemo scenu).
struct CitySceneView: UIViewRepresentable {
    let city: City?
    var onTapHQ:        () -> Void
    var onTapBuilding:  (BuildingInfo) -> Void
    var onTapEmptySlot: (Int) -> Void

    /// Pozvan iz scene kad construction timer (countdown na zgradi) dođe na 0.
    /// Parent SwiftUI view treba da pozove refreshCity() da povuče novi state sa BE-a.
    var onConstructionComplete: () -> Void = {}

    /// One-shot trigger za reset kamere — increment-uj iz parent SwiftUI view-a (npr. recenter dugme).
    /// updateUIView detektuje promenu vrednosti i poziva scene.resetCamera().
    var cameraResetCounter: Int = 0

    /// Toggle debug grid overlay (cyan diamonds + anchor dots).
    /// Menja se iz SettingsView preko `@AppStorage("debug.cityGridOverlay")`.
    @AppStorage("debug.cityGridOverlay") private var debugOverlay: Bool = false

    // MARK: - Coordinator

    final class Coordinator {
        var scene: CityScene?
        var lastResetCounter: Int = 0
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    // MARK: - UIViewRepresentable

    func makeUIView(context: Context) -> SKView {
        let skView = SKView()
        skView.ignoresSiblingOrder = true
        skView.allowsTransparency  = false
        skView.backgroundColor     = .clear

        let scene = CityScene()
        scene.onTapHQ                = onTapHQ
        scene.onTapBuilding          = onTapBuilding
        scene.onTapEmptySlot         = onTapEmptySlot
        scene.onConstructionComplete = onConstructionComplete
        context.coordinator.scene = scene
        context.coordinator.lastResetCounter = cameraResetCounter

        skView.presentScene(scene)

        if let city { scene.configure(with: city) }
        scene.setDebugOverlay(debugOverlay)

        return skView
    }

    func updateUIView(_ uiView: SKView, context: Context) {
        guard let scene = context.coordinator.scene else { return }

        // Update callback-ova svaki put (da bi SwiftUI state bio svjež)
        scene.onTapHQ                = onTapHQ
        scene.onTapBuilding          = onTapBuilding
        scene.onTapEmptySlot         = onTapEmptySlot
        scene.onConstructionComplete = onConstructionComplete

        if let city { scene.configure(with: city) }
        scene.setDebugOverlay(debugOverlay)

        // One-shot reset kamere ako je counter inkrementovan
        if cameraResetCounter != context.coordinator.lastResetCounter {
            scene.resetCamera()
            context.coordinator.lastResetCounter = cameraResetCounter
        }
    }
}
