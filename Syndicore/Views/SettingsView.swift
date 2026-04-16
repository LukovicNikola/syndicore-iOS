import SwiftUI

struct SettingsView: View {
    @Environment(GameState.self) private var gameState

    @State private var showingSignOutConfirmation = false

    var body: some View {
        NavigationStack {
            List {
                if let player = gameState.currentPlayer {
                    Section("Player") {
                        LabeledContent("Username", value: player.username)
                        LabeledContent("ID", value: String(player.id.prefix(8)) + "…")
                        LabeledContent("Joined", value: player.createdAt)
                    }
                }

                Section("Game Data") {
                    LabeledContent("Constants") {
                        if gameState.gameConstants.isLoaded {
                            Label("Cached", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        } else {
                            Text("Not loaded")
                                .foregroundStyle(.secondary)
                        }
                    }
                    Button("Refresh Constants") {
                        Task { await gameState.gameConstants.refresh() }
                    }
                }

                Section {
                    Button("Sign Out", role: .destructive) {
                        showingSignOutConfirmation = true
                    }
                }
            }
            .navigationTitle("Settings")
            .confirmationDialog("Sign out of Syndicore?", isPresented: $showingSignOutConfirmation, titleVisibility: .visible) {
                Button("Sign Out", role: .destructive) {
                    Task { await gameState.signOut() }
                }
            }
        }
    }
}
