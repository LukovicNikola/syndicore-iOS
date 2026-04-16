import SwiftUI

struct SplashView: View {
    @Environment(GameState.self) private var gameState

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Text("SYNDICORE")
                .font(.system(size: 42, weight: .black, design: .monospaced))
                .tracking(6)

            Text("Initializing...")
                .font(.caption)
                .foregroundStyle(.secondary)

            ProgressView()
                .tint(.white)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.black)
        .foregroundStyle(.white)
        .task {
            await gameState.bootstrap()
        }
    }
}
