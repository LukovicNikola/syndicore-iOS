import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var appState

    @State private var showingSignOutConfirmation = false

    var body: some View {
        NavigationStack {
            List {
                if let player = appState.currentPlayer {
                    Section("Player") {
                        LabeledContent("Username", value: player.username)
                        LabeledContent("ID", value: String(player.id.uuidString.prefix(8)) + "…")
                        LabeledContent("Joined", value: player.createdAt.formatted(date: .abbreviated, time: .omitted))
                    }
                }

                Section("Game Data") {
                    LabeledContent("Constants") {
                        if appState.gameConstants.isLoaded {
                            Label("Cached", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        } else {
                            Text("Not loaded")
                                .foregroundStyle(.secondary)
                        }
                    }
                    Button("Refresh Constants") {
                        Task { await appState.gameConstants.refresh() }
                    }
                }

                Section("App") {
                    LabeledContent("Version", value: "0.1.0")
                    LabeledContent("API", value: appState.api.baseURL.host() ?? "—")
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
                    Task { await appState.signOut() }
                }
            }
        }
    }
}
