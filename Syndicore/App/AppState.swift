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
    let socket: SocketService

    init(config: AppConfig) {
        SupabaseManager.configure(config: config)
        let api = APIClient(baseURL: config.apiBaseURL)
        self.api = api
        self.auth = SupabaseManager.shared
        self.gameConstants = GameConstantsManager(api: api)
        self.socket = SocketService.shared
    }

    // MARK: - Player Data

    var currentPlayer: Player?
    var activeWorld: World?
    var activePlayerWorld: PlayerWorld?
    var activeCity: City?
    var activeTrainingJobs: [TrainingJob] = []

    /// Paginated movements — accumulated preko vise stranica.
    var activeMovements: [TroopMovement] = []
    /// Cursor za sledecu stranu movements-a. nil = nema vise stranica ili se jos nije fetch-ovalo.
    var movementsNextCursor: String?
    var movementsHasMore: Bool = false

    /// Paginated reports — accumulated preko vise stranica.
    var activeReports: [BattleReport] = []
    var reportsNextCursor: String?
    var reportsHasMore: Bool = false

    // MARK: - Transient UI Error State
    // Non-fatal greške iz background refresh poziva koje UI prikazuje kao banner/toast.
    // Views treba da resetuju ovo na nil nakon prikaza (ili na .task retry-u).

    /// Poslednja greska iz refreshCity() koju CityView treba da prikaze.
    var cityRefreshError: String?

    /// Poslednja greska iz map viewport fetch-a koju MapView treba da prikaze.
    var mapFetchError: String?

    // MARK: - Realtime completion notices (Socket.IO triggered)
    // Transient poruke koje MainGameView prikazuje kao success toast banner.
    // Auto-dismiss posle 3s ili kad user tapne "X".

    /// "Barracks upgraded to L3" / "10 Grunts ready" — toast iznad TabView-a.
    var lastCompletionNotice: CompletionNotice?

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
                await connectRealtime()
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
        activeCity = response.city ?? response.playerWorld.city
        activeScreen = .mainGame
        Task { await connectRealtime() }
    }

    // MARK: - Realtime (Socket.IO)

    /// Uspostavlja Socket.IO konekciju + pretplata na city i world rooms.
    /// Zove se posle uspešnog bootstrap-a (postoji aktivna sesija + join-ovan svet).
    /// Idempotent — ako je socket već konektovan, samo re-join-uje rooms.
    private func connectRealtime() async {
        do {
            let token = try await auth.accessToken()
            socket.connect(baseURL: api.baseURL, token: token)
            wireSocketEventHandlers()
            if let cityId = activeCity?.id {
                socket.joinCityRoom(cityId: cityId)
            }
            if let worldId = activePlayerWorld?.worldId ?? activeWorld?.id {
                socket.joinWorldRoom(worldId: worldId)
            }
        } catch {
            Self.log.info("Realtime connect skipped (no token): \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Prikači event callback-ove na SocketService. Svaki event triggeruje
    /// odgovarajući refresh + optional toast notice + haptic.
    /// Idempotent — svaki reconnect ponovo setuje closure (nema akumulacije).
    private func wireSocketEventHandlers() {
        socket.onBuildingComplete = { [weak self] event in
            Task { [weak self] in await self?.handleBuildingComplete(event) }
        }
        socket.onTrainingComplete = { [weak self] event in
            Task { [weak self] in await self?.handleTrainingComplete(event) }
        }
        socket.onTroopsArrived = { [weak self] event in
            Task { [weak self] in await self?.handleTroopsArrived(event) }
        }
    }

    // MARK: - Socket event handlers

    /// `building_complete` — gradnja/upgrade završen. Prikaz toast + refresh city.
    /// Napomena: CityScene već ima lokalni countdown koji trigger-uje celebration
    /// burst. Ovaj handler je backup + authoritative source-of-truth iz BE-a
    /// (device clock drift je moguć).
    private func handleBuildingComplete(_ event: BuildingCompleteEvent) async {
        let displayName = event.type.rawValue
            .replacingOccurrences(of: "_", with: " ")
            .capitalized
        lastCompletionNotice = CompletionNotice(
            kind: .building,
            title: "\(displayName) ready",
            subtitle: "Level \(event.newLevel)"
        )
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        await refreshCity()
    }

    /// `training_complete` — training job završen. Prikaz toast + refresh city + training jobs.
    private func handleTrainingComplete(_ event: TrainingCompleteEvent) async {
        let unitName = event.unitType.rawValue.capitalized
        let plural = event.count == 1 ? unitName : "\(unitName)s"
        lastCompletionNotice = CompletionNotice(
            kind: .training,
            title: "\(event.count) \(plural) ready",
            subtitle: "Garrisoned at home"
        )
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        await refreshCity()
    }

    /// `troops_arrived` — movement stigao na cilj (attack kompletiran ili return leg).
    /// Silently refresh-uje movements + reports + city.
    /// Ako je ATTACK/RAID stigao, BE je verovatno vec kreirao battle report — user
    /// će ga videti u Reports tabu.
    /// Ako je RETURN stigao, trupe su se vratile u garrison — city refresh ih pokazuje.
    private func handleTroopsArrived(_ event: TroopsArrivedEvent) async {
        // Tih toast — samo za "nešto se desilo" indikator, detalji u Reports
        let typeName = event.type.rawValue.capitalized
        lastCompletionNotice = CompletionNotice(
            kind: .troopsArrived,
            title: "\(typeName) completed",
            subtitle: "at (\(event.targetX), \(event.targetY))"
        )
        // Nema haptic-a — inace bi spam-ovao igrača koji ima više movements-a
        await refreshMovements()
        await refreshReports()
        await refreshCity()
    }

    /// Briše trenutni notice — pozvano iz banner dismiss dugmeta ili auto-timeout-a.
    func clearCompletionNotice() {
        lastCompletionNotice = nil
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

    // MARK: - Movements (paginated)

    /// Fetch-uje PRVU stranu movements-a. Resetuje accumulated list + cursor.
    /// Pozvati pri prvom load-u ili pull-to-refresh.
    func refreshMovements(limit: Int = 50) async {
        guard let worldId = activePlayerWorld?.worldId ?? activeWorld?.id else { return }
        do {
            let page = try await api.movements(worldId: worldId, limit: limit, before: nil)
            activeMovements = page.items
            movementsNextCursor = page.nextCursor
            movementsHasMore = page.hasMore
        } catch {
            Self.log.info("Movements refresh failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Fetch-uje SLEDECU stranu movements-a i appenduje na accumulated list.
    /// Pozvati kad user scroll-uje na dno liste (infinite scroll) ili klikne "Load more".
    /// No-op ako `movementsHasMore == false` ili nema cursor-a.
    func loadMoreMovements(limit: Int = 50) async {
        guard let worldId = activePlayerWorld?.worldId ?? activeWorld?.id else { return }
        guard movementsHasMore, let cursor = movementsNextCursor else { return }
        do {
            let page = try await api.movements(worldId: worldId, limit: limit, before: cursor)
            activeMovements.append(contentsOf: page.items)
            movementsNextCursor = page.nextCursor
            movementsHasMore = page.hasMore
        } catch {
            Self.log.info("Movements pagination failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Reports (paginated)

    /// Fetch-uje PRVU stranu battle reports-a. Resetuje accumulated list + cursor.
    func refreshReports(limit: Int = 50) async {
        guard let worldId = activePlayerWorld?.worldId ?? activeWorld?.id else { return }
        do {
            let page = try await api.reports(worldId: worldId, limit: limit, before: nil)
            activeReports = page.items
            reportsNextCursor = page.nextCursor
            reportsHasMore = page.hasMore
        } catch {
            Self.log.info("Reports refresh failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Fetch-uje SLEDECU stranu reports-a i appenduje na accumulated list.
    func loadMoreReports(limit: Int = 50) async {
        guard let worldId = activePlayerWorld?.worldId ?? activeWorld?.id else { return }
        guard reportsHasMore, let cursor = reportsNextCursor else { return }
        do {
            let page = try await api.reports(worldId: worldId, limit: limit, before: cursor)
            activeReports.append(contentsOf: page.items)
            reportsNextCursor = page.nextCursor
            reportsHasMore = page.hasMore
        } catch {
            Self.log.info("Reports pagination failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func signOut() async {
        do {
            try await auth.signOut()
        } catch {
            // Ignore sign out errors
        }
        socket.disconnect()
        currentPlayer = nil
        activeWorld = nil
        activePlayerWorld = nil
        activeCity = nil
        activeTrainingJobs = []
        activeMovements = []
        activeReports = []
        activeScreen = .auth
    }
}
