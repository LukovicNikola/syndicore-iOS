import SwiftUI

struct WorldListView: View {
    @Environment(AppState.self) private var appState

    @State private var worlds: [WorldSummary] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var selectedWorld: WorldSummary?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView()
                } else if let errorMessage {
                    VStack(spacing: 12) {
                        Text(errorMessage)
                            .foregroundStyle(.secondary)
                        Button("Retry") { Task { await loadWorlds() } }
                    }
                } else {
                    List(worlds) { world in
                        WorldRow(world: world)
                            .onTapGesture { selectedWorld = world }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Worlds")
            .sheet(item: $selectedWorld) { world in
                FactionPickerView(world: world)
            }
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
