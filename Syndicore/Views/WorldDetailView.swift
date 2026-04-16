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
                        if world.maxPlayers > 0 {
                            ProgressView(value: Double(world.playerCount), total: Double(world.maxPlayers))
                                .tint(Double(world.playerCount) > Double(world.maxPlayers) * 0.9 ? .red : .green)
                        }
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
                ContentUnavailableView {
                    Label("Error", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(errorMessage)
                } actions: {
                    Button("Retry") { Task { await loadWorld() } }
                        .buttonStyle(.borderedProminent)
                }
            }
        }
        .navigationTitle(world?.name ?? "World")
        .task { await loadWorld() }
    }

    private func loadWorld() async {
        isLoading = true
        errorMessage = nil
        do {
            world = try await appState.api.world(id: worldId)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
