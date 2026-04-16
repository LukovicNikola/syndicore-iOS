import SwiftUI

struct CodexView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        NavigationStack {
            Group {
                if let gameData = appState.gameConstants.gameData {
                    List {
                        Section("Factions & Units") {
                            NavigationLink {
                                UnitsView(gameData: gameData)
                            } label: {
                                Label("Units", systemImage: "person.3.fill")
                            }
                        }

                        Section("Infrastructure") {
                            NavigationLink {
                                BuildingsView(gameData: gameData)
                            } label: {
                                Label("Buildings", systemImage: "building.2.fill")
                            }
                            NavigationLink {
                                TechTreeView(gameData: gameData)
                            } label: {
                                Label("Tech Tree", systemImage: "cpu")
                            }
                        }

                        Section("World") {
                            NavigationLink {
                                MapInfoView(gameData: gameData)
                            } label: {
                                Label("Map & Terrain", systemImage: "map.fill")
                            }
                        }
                    }
                } else {
                    ContentUnavailableView(
                        "No Game Data",
                        systemImage: "doc.questionmark",
                        description: Text("Game constants haven't loaded yet. Pull to retry.")
                    )
                }
            }
            .navigationTitle("Codex")
            .refreshable {
                await appState.gameConstants.refresh()
            }
        }
    }
}
