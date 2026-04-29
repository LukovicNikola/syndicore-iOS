import SwiftUI

@main
struct SyndicoreApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    /// Kompaktno stanje bootstrap-a: loaduj AppConfig pre nego što GameState može da se kreira.
    /// Ako config fali → prikazi ConfigErrorView umesto crash-a.
    @State private var bootstrap: BootstrapResult = .loading

    /// Prati background/foreground tranzicije — koristi se da WebSocket
    /// suspend-uje na background (iOS gasi WS posle ~30s u suspend stanju),
    /// pa resume-uje na povratak.
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            switch bootstrap {
            case .loading:
                ProgressView()
                    .task { await loadConfig() }
            case .ready(let state):
                ContentView()
                    .environment(state)
                    .onChange(of: scenePhase) { _, newPhase in
                        Task { await handleScenePhase(newPhase, state: state) }
                    }
            case .failed(let message):
                ConfigErrorView(message: message) {
                    Task { await loadConfig() }
                }
            }
        }
    }

    @MainActor
    private func handleScenePhase(_ phase: ScenePhase, state: GameState) async {
        switch phase {
        case .background:
            // Skini WS pre nego sto iOS suspend-uje proces — sprečava reconnect storm
            // kad iOS ubije socket i tek pri foreground-u app primeti.
            state.socket.suspend()
        case .active:
            // Vrati WS — koristi cached connectionToken iz prethodne sesije.
            // Ako je istekao, scheduleReconnect će probati refresh.
            state.socket.resume()
        case .inactive:
            break
        @unknown default:
            break
        }
    }

    @MainActor
    private func loadConfig() async {
        do {
            let config = try AppConfig.load()
            let state = GameState(config: config)
            bootstrap = .ready(state)
        } catch {
            bootstrap = .failed(error.localizedDescription)
        }
    }

    enum BootstrapResult {
        case loading
        case ready(GameState)
        case failed(String)
    }
}

/// Prikazuje se ako Config.plist fali ili je nevalidan — pre svega na dev mašinama
/// gde programer nije kopirao Config.example.plist u Config.plist.
private struct ConfigErrorView: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.yellow)
            Text("Konfiguracija fali")
                .font(.title2)
                .bold()
            Text(message)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .foregroundStyle(.secondary)
            Button("Pokušaj ponovo", action: retry)
                .buttonStyle(.borderedProminent)
                .padding(.top, 8)
        }
        .padding()
        .preferredColorScheme(.dark)
    }
}
