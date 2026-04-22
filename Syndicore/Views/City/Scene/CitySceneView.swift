import SwiftUI
import SpriteKit

/// SwiftUI wrapper oko CityScene (UIViewRepresentable da bi mogli da update-ujemo scenu).
struct CitySceneView: UIViewRepresentable {
    let city: City?
    var onTapHQ:        () -> Void
    var onTapBuilding:  (BuildingInfo) -> Void
    var onTapEmptySlot: (TappedSlot) -> Void

    /// Pozvan iz scene kad construction timer (countdown na zgradi) dođe na 0.
    /// Parent SwiftUI view treba da pozove refreshCity() da povuče novi state sa BE-a.
    var onConstructionComplete: () -> Void = {}

    /// Toggle debug grid overlay (cyan diamonds + anchor dots).
    /// Menja se iz SettingsView preko `@AppStorage("debug.cityGridOverlay")`.
    @AppStorage("debug.cityGridOverlay") private var debugOverlay: Bool = false

    // MARK: - Coordinator

    final class Coordinator {
        var scene: CityScene?
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
    }
}
