import SwiftUI

/// Glavni ekran igre posle join-a -- TabView sa CityView, MapView, ArmyView, itd.
struct MainGameView: View {
    @Environment(GameState.self) private var gameState

    var body: some View {
        TabView {
            CityPlaceholderView()
                .tabItem {
                    Label("City", systemImage: "building.2")
                }

            MapPlaceholderView()
                .tabItem {
                    Label("Map", systemImage: "map")
                }

            ArmyPlaceholderView()
                .tabItem {
                    Label("Army", systemImage: "shield")
                }

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

private struct CityPlaceholderView: View {
    @Environment(GameState.self) private var gameState

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                if let city = gameState.activeCity {
                    Text(city.name)
                        .font(.title2.bold())

                    if let resources = city.resources {
                        HStack(spacing: 16) {
                            ResourceLabel(name: "Credits", value: resources.credits)
                            ResourceLabel(name: "Alloys", value: resources.alloys)
                        }
                        HStack(spacing: 16) {
                            ResourceLabel(name: "Tech", value: resources.tech)
                            ResourceLabel(name: "Energy", value: resources.energy)
                        }
                    }

                    if let buildings = city.buildings {
                        List(buildings) { building in
                            HStack {
                                Text(building.type.rawValue)
                                    .font(.subheadline)
                                Spacer()
                                Text("Lvl \(building.level)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .listStyle(.plain)
                    }
                } else {
                    ProgressView("Loading city...")
                }
            }
            .navigationTitle("City")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Sign Out") {
                        Task { await gameState.signOut() }
                    }
                }
            }
        }
    }
}

private struct ResourceLabel: View {
    let name: String
    let value: Double

    var body: some View {
        VStack {
            Text(name)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("\(Int(value))")
                .font(.headline.monospacedDigit())
        }
        .frame(maxWidth: .infinity)
        .padding(8)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct MapPlaceholderView: View {
    var body: some View {
        NavigationStack {
            Text("Map -- coming soon")
                .foregroundStyle(.secondary)
                .navigationTitle("Map")
        }
    }
}

private struct ArmyPlaceholderView: View {
    var body: some View {
        NavigationStack {
            Text("Army -- coming soon")
                .foregroundStyle(.secondary)
                .navigationTitle("Army")
        }
    }
}

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
