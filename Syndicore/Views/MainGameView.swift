import SwiftUI

/// Glavni ekran igre posle join-a -- TabView sa CityView, MapView, ArmyView, itd.
struct MainGameView: View {
    @Environment(GameState.self) private var gameState

    var body: some View {
        TabView {
            CityView()
                .tabItem {
                    Label("City", systemImage: "building.2")
                }

            MapView()
                .tabItem {
                    Label("Map", systemImage: "map")
                }

            ArmyView()
                .tabItem {
                    Label("Army", systemImage: "shield")
                }
                .badge(gameState.activeMovements.count)

            SyndikatPlaceholderView()
                .tabItem {
                    Label("Syndikat", systemImage: "person.3")
                }

            ResearchPlaceholderView()
                .tabItem {
                    Label("Research", systemImage: "flask")
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
        .preferredColorScheme(.dark)
        .task {
            await gameState.gameConstants.refresh()
        }
    }
}

// MARK: - Placeholder Views

private struct SyndikatPlaceholderView: View {
    var body: some View {
        NavigationStack {
            Text("Syndikat -- coming soon")
                .foregroundStyle(.secondary)
                .navigationTitle("Syndikat")
        }
    }
}

private struct ResearchPlaceholderView: View {
    var body: some View {
        NavigationStack {
            Text("Research -- coming soon")
                .foregroundStyle(.secondary)
                .navigationTitle("Research")
        }
    }
}
