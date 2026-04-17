import SwiftUI

@main
struct SyndicoreApp: App {
    /// Kompaktno stanje bootstrap-a: loaduj AppConfig pre nego što GameState može da se kreira.
    /// Ako config fali → prikazi ConfigErrorView umesto crash-a.
    @State private var bootstrap: BootstrapResult = .loading

    var body: some Scene {
        WindowGroup {
            switch bootstrap {
            case .loading:
                ProgressView()
                    .task { await loadConfig() }
            case .ready(let state):
                ContentView()
                    .environment(state)
            case .failed(let message):
                ConfigErrorView(message: message) {
                    Task { await loadConfig() }
                }
            }
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
