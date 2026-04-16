import SwiftUI

@main
struct SyndicoreApp: App {
    @State private var gameState = GameState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(gameState)
        }
    }
}
