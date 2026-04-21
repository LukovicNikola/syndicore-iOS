import Foundation
import Observation
import os

/// Centralno stanje aplikacije.
/// Prati gde se korisnik nalazi u flow-u: splash -> auth -> onboarding -> worldPicker -> factionPicker -> mainGame.
@Observable
@MainActor
final class GameState {

    static let log = Logger(subsystem: "com.syndicore.ios", category: "GameState")

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

    let api: APIClient
    let auth: SupabaseManager
    let gameConstants: GameConstantsManager

    init(config: AppConfig) {
        SupabaseManager.configure(config: config)
        let api = APIClient(baseURL: config.apiBaseURL)
        self.api = api
        self.auth = SupabaseManager.shared
        self.gameConstants = GameConstantsManager(api: api)
    }

    // MARK: - Player Data

    var currentPlayer: Player?
    var activeWorld: World?
    var activePlayerWorld: PlayerWorld?
    var activeCity: City?
    var activeTrainingJobs: [TrainingJob] = []

    // MARK: - Transient UI Error State
    // Non-fatal greške iz background refresh poziva koje UI prikazuje kao banner/toast.
    // Views treba da resetuju ovo na nil nakon prikaza (ili na .task retry-u).

    /// Poslednja greska iz refreshCity() koju CityView treba da prikaze.
    var cityRefreshError: String?

    /// Poslednja greska iz map viewport fetch-a koju MapView treba da prikaze.
    var mapFetchError: String?

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
                await autoSelectWorld()
            }
        } catch let error as APIError {
            switch error {
            case .onboardingRequired:
                activeScreen = .onboarding
            case .unauthorized:
                activeScreen = .auth
            default:
                Self.log.error("Bootstrap APIError: \(error.localizedDescription, privacy: .public)")
                activeScreen = .auth
            }
        } catch {
            Self.log.error("Bootstrap unexpected error: \(error.localizedDescription, privacy: .public)")
            activeScreen = .auth
        }
    }

    // MARK: - Navigation Actions

    func didSignIn() async {
        await bootstrap()
    }

    func didOnboard(player: Player) async {
        currentPlayer = player
        await autoSelectWorld()
    }

    func didSelectWorld(_ world: World) {
        activeWorld = world
        activeScreen = .factionPicker(world)
    }

    // Automatski bira prvi dostupan svet (samo jedan u staging-u)
    private func autoSelectWorld() async {
        do {
            let allWorlds = try await api.worlds()
            guard let world = allWorlds.first else {
                activeScreen = .worldPicker
                return
            }
            activeWorld = world
            activeScreen = .factionPicker(world)
        } catch {
            activeScreen = .worldPicker
        }
    }

    func didJoinWorld(response: JoinWorldResponse) {
        activePlayerWorld = response.playerWorld
        activeCity = response.city
        activeScreen = .mainGame
    }

    func refreshCity() async {
        guard let cityId = activeCity?.id else { return }
        do {
            async let cityTask = api.city(id: cityId)
            async let trainingTask = api.trainingJobs(cityId: cityId)
            let (city, jobs) = try await (cityTask, trainingTask)
            activeCity = city
            activeTrainingJobs = jobs
            cityRefreshError = nil
        } catch {
            // Zadrzi stale data ali upozori UI — korisnik mora da zna da je refresh otkazao.
            Self.log.info("City refresh failed: \(error.localizedDescription, privacy: .public)")
            cityRefreshError = error.localizedDescription
        }
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
