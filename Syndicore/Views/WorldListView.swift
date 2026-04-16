import SwiftUI

struct WorldPickerView: View {
    @Environment(GameState.self) private var gameState

    @State private var worlds: [World] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

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
                            .onTapGesture {
                                gameState.didSelectWorld(world)
                            }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Choose a World")
            .task { await loadWorlds() }
        }
        .preferredColorScheme(.dark)
    }

    private func loadWorlds() async {
        isLoading = true
        errorMessage = nil
        do {
            worlds = try await gameState.api.worlds()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

// MARK: - World Row

private struct WorldRow: View {
    let world: World

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
