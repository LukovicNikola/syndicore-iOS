import SwiftUI

struct WorldListView: View {
    @Environment(AppState.self) private var appState

    @State private var worlds: [WorldSummary] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView()
                } else if let errorMessage {
                    ContentUnavailableView {
                        Label("Connection Error", systemImage: "wifi.exclamationmark")
                    } description: {
                        Text(errorMessage)
                    } actions: {
                        Button("Retry") { Task { await loadWorlds() } }
                            .buttonStyle(.borderedProminent)
                    }
                } else if worlds.isEmpty {
                    ContentUnavailableView(
                        "No Worlds",
                        systemImage: "globe",
                        description: Text("No worlds available yet. Check back soon.")
                    )
                } else {
                    List(worlds) { world in
                        NavigationLink {
                            WorldDetailView(worldId: world.id)
                        } label: {
                            WorldRow(world: world)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Worlds")
            .refreshable { await loadWorlds() }
            .task { await loadWorlds() }
        }
    }

    private func loadWorlds() async {
        isLoading = true
        errorMessage = nil
        do {
            worlds = try await appState.api.worlds()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

// MARK: - World Row

private struct WorldRow: View {
    let world: WorldSummary

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(world.name)
                    .font(.headline)
                Text(world.status)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(world.playerCount)/\(world.maxPlayers)")
                    .font(.subheadline)
                    .monospacedDigit()
                Text("\(world.speedMultiplier, specifier: "%.0f")x")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
