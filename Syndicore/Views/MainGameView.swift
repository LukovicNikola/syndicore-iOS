import SwiftUI

/// Glavni ekran igre posle join-a — navigacija je preko SpriteKit dugmića u CityScene
/// i programskog prebacivanja `gameState.selectedTab`.
/// Plus globalni overlay za incoming attack banner (Socket.IO event).
struct MainGameView: View {
    @Environment(GameState.self) private var gameState

    var body: some View {
        @Bindable var gameState = gameState
        ZStack {
            switch gameState.selectedTab {
            case .city:
                CityView()
            case .map:
                MapView()
            case .army:
                ArmyView()
            case .syndikat:
                SyndikatView()
            case .research:
                ResearchView()
            case .codex:
                CodexView()
            case .settings:
                SettingsView()
            }
        }
        .overlay(alignment: .top) {
            VStack(spacing: 4) {
                // Incoming attack — najvišeg prioriteta, crveno-narandžasto
                if let attack = gameState.socket.lastIncomingAttack {
                    IncomingAttackBanner(
                        event: attack,
                        onDismiss: {
                            withAnimation { gameState.socket.clearIncomingAttack() }
                        },
                        onTap: {
                            // TODO: navigate to CityView / open defense overview
                        }
                    )
                    .onAppear {
                        UINotificationFeedbackGenerator().notificationOccurred(.warning)
                        Task { await gameState.refreshCity() }
                    }
                }
                // Completion notice — building/training/arrival success toast
                if let notice = gameState.lastCompletionNotice {
                    CompletionNoticeBanner(
                        notice: notice,
                        onDismiss: {
                            withAnimation { gameState.clearCompletionNotice() }
                        }
                    )
                }
            }
        }
        .animation(.spring(duration: 0.35), value: gameState.socket.lastIncomingAttack?.arrivesAt)
        .animation(.spring(duration: 0.35), value: gameState.lastCompletionNotice?.id)
        .preferredColorScheme(.dark)
        .task {
            await gameState.gameConstants.refresh()
        }
    }
}
