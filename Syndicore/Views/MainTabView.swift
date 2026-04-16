import SwiftUI

struct MainTabView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        TabView {
            WorldListView()
                .tabItem {
                    Label("Worlds", systemImage: "globe")
                }

            CodexView()
                .tabItem {
                    Label("Codex", systemImage: "book.closed.fill")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
        .task {
            await appState.gameConstants.refresh()
        }
    }
}
