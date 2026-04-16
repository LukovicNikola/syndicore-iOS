import Foundation
import Observation

/// Centralno stanje aplikacije.
/// Prati gde se korisnik nalazi u flow-u: splash -> auth -> onboarding -> worldPicker -> factionPicker -> mainGame.
@Observable
@MainActor
final class GameState {

    // MARK: - Navigation

    enum Screen {
        case splash
        case auth
        case onboarding
        case worldPicker
        case factionPicker(World)
        case mainGame
    }

    var activeScreen: Screen = .splash

    /// Za SwiftUI animaciju tranzicija između ekrana
    var screenId: String {
        switch activeScreen {
        case .splash: "splash"
        case .auth: "auth"
        case .onboarding: "onboarding"
        case .worldPicker: "worldPicker"
        case .factionPicker: "factionPicker"
        case .mainGame: "mainGame"
        }
    }

    // MARK: - Dependencies

    let api = APIClient()
    let auth = SupabaseManager.shared

    // MARK: - Player Data

    var currentPlayer: Player?
    var activeWorld: World?
    var activePlayerWorld: PlayerWorld?
    var activeCity: City?

    // MARK: - Bootstrap

    /// Splash screen poziva ovo. Proverava sesiju i određuje početni ekran.
    func bootstrap() async {
        // 1. Probaj da restore-uješ Supabase sesiju
        await auth.restoreSession()

        guard auth.isAuthenticated else {
            activeScreen = .auth
            return
        }

        // 2. Probaj GET /me — da li je korisnik onboard-ovan?
        do {
            let response = try await api.me()
            currentPlayer = response.player

            // 3. Ako ima worlds, proveri da li je već join-ovao
            if let worlds = response.player.worlds, !worlds.isEmpty {
                let pw = worlds[0]
                activePlayerWorld = pw

                let allWorlds = try await api.worlds()
                activeWorld = allWorlds.first { $0.id == pw.worldId }

                if let city = pw.city {
                    activeCity = try await api.city(id: city.id)
                }
                activeScreen = .mainGame
            } else {
                activeScreen = .worldPicker
            }
        } catch let error as APIError {
            switch error {
            case .onboardingRequired:
                activeScreen = .onboarding
            case .unauthorized:
                activeScreen = .auth
            default:
                activeScreen = .auth
            }
        } catch {
            activeScreen = .auth
        }
    }

    // MARK: - Navigation Actions

    func didSignIn() async {
        await bootstrap()
    }

    func didOnboard(player: Player) {
        currentPlayer = player
        activeScreen = .worldPicker
    }

    func didSelectWorld(_ world: World) {
        activeWorld = world
        activeScreen = .factionPicker(world)
    }

    func didJoinWorld(response: JoinWorldResponse) {
        activePlayerWorld = response.playerWorld
        activeCity = response.city
        activeScreen = .mainGame
    }

    func signOut() async {
        do {
            try await auth.signOut()
        } catch {
            // Ignore sign out errors
        }
        currentPlayer = nil
        activeWorld = nil
        activePlayerWorld = nil
        activeCity = nil
        activeScreen = .auth
    }
}
