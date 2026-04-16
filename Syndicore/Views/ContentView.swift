import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        Group {
            switch appState.activeScreen {
            case .loading:
                ProgressView("Loading...")
                    .task { await appState.bootstrap() }
            case .login:
                LoginView()
            case .worldList:
                WorldListView()
            case .onboarding:
                OnboardingView()
            }
        }
        .preferredColorScheme(.dark)
    }
}
