import SwiftUI

struct WorldDetailView: View {
    @Environment(AppState.self) private var appState

    let worldId: String

    @State private var world: WorldSummary?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showJoin = false

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
            } else if let world {
                List {
                    Section("World") {
                        LabeledContent("Name", value: world.name)
                        LabeledContent("Status", value: world.status)
                        LabeledContent("Speed", value: "\(world.speedMultiplier, specifier: "%.0f")x")
                        LabeledContent("Map Radius", value: "\(world.mapRadius)")
                    }

                    Section("Players") {
                        LabeledContent("Current", value: "\(world.playerCount)")
                        LabeledContent("Max", value: "\(world.maxPlayers)")
                        ProgressView(value: Double(world.playerCount), total: Double(world.maxPlayers))
                            .tint(world.playerCount > world.maxPlayers * 9 / 10 ? .red : .green)
                    }

                    if world.status == "OPEN" {
                        Section {
                            Button("Join World") {
                                showJoin = true
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                }
                .sheet(isPresented: $showJoin) {
                    FactionPickerView(world: world) {
                        Task { await loadWorld() }
                    }
                }
            } else if let errorMessage {
                ContentUnavailableView(
                    "Error",
                    systemImage: "exclamationmark.triangle",
                    description: Text(errorMessage)
                )
            }
        }
        .navigationTitle(world?.name ?? "World")
        .task { await loadWorld() }
    }

    private func loadWorld() async {
        isLoading = true
        do {
            world = try await appState.api.world(id: worldId)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
