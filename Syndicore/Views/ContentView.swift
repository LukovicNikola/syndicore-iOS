import SwiftUI

struct ContentView: View {
    @Environment(GameState.self) private var gameState

    var body: some View {
        Group {
            switch gameState.activeScreen {
            case .splash:
                SplashView()
            case .auth:
                AuthView()
            case .onboarding:
                OnboardingView()
            case .worldPicker:
                WorldPickerView()
            case .factionPicker(let world):
                FactionPickerView(world: world)
            case .mainGame:
                MainGameView()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: gameState.screenId)
    }
}
