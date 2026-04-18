import SwiftUI

struct SettingsView: View {
    @Environment(GameState.self) private var gameState

    @State private var showingSignOutConfirmation = false

    // MARK: - Debug toggles (dev-only, persistirano preko UserDefaults)

    @AppStorage("debug.cityGridOverlay") private var debugCityGridOverlay: Bool = false

    var body: some View {
        NavigationStack {
            List {
                if let player = gameState.currentPlayer {
                    Section("Player") {
                        LabeledContent("Username", value: player.username)
                        LabeledContent("ID", value: String(player.id.prefix(8)) + "…")
                        LabeledContent("Joined", value: player.createdAt.formatted(date: .abbreviated, time: .omitted))
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

                #if DEBUG
                Section {
                    Toggle("City Grid Overlay", isOn: $debugCityGridOverlay)
                    NavigationLink("Sprite Alignment Test") {
                        SpriteAlignmentTestView()
                    }
                } header: {
                    Text("Debug")
                } footer: {
                    Text("Cyan dijamanti + magenta tačke pokazuju gde se očekuju sprite anchor-i. Test screen ti omogućava da proveriš sprajtove pre nego što ih staviš u produkciju.")
                        .font(.footnote)
                }
                #endif

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
