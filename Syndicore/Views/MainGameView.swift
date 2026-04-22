import SwiftUI

/// Glavni ekran igre posle join-a -- TabView sa CityView, MapView, ArmyView, itd.
/// Plus globalni overlay za incoming attack banner (Socket.IO event).
struct MainGameView: View {
    @Environment(GameState.self) private var gameState

    var body: some View {
        tabView
            .overlay(alignment: .top) {
                if let attack = gameState.socket.lastIncomingAttack {
                    IncomingAttackBanner(
                        event: attack,
                        onDismiss: {
                            withAnimation { gameState.socket.clearIncomingAttack() }
                        },
                        onTap: {
                            // TODO: navigate to CityView / open defense overview
                            // Trenutno samo dismiss — kad ArmyView/CityView imaju defense screen,
                            // ovo može da ih otvori preko bindinga.
                        }
                    )
                    .padding(.top, 4)
                    .onAppear {
                        // Haptic warning kad se banner pojavi — iritira, ali igrač mora da vidi
                        UINotificationFeedbackGenerator().notificationOccurred(.warning)
                        // Auto-refresh: napad dolazi — city state je možda već ažuriran
                        Task { await gameState.refreshCity() }
                    }
                }
            }
            .animation(.spring(duration: 0.35), value: gameState.socket.lastIncomingAttack?.arrivesAt)
    }

    private var tabView: some View {
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
