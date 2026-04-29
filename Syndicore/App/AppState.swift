import Foundation
import Observation
import UIKit
import UserNotifications
import os

/// Centralno stanje aplikacije.
/// Prati gde se korisnik nalazi u flow-u: splash -> auth -> onboarding -> worldPicker -> factionPicker -> mainGame.
@Observable
@MainActor
final class GameState {

    nonisolated static let log = Logger(subsystem: "com.syndicore.ios", category: "GameState")

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

    /// Tab unutar MainGameView — driven from SpriteKit nav buttons or SwiftUI.
    enum GameTab: String, CaseIterable {
        case city, map, army, syndikat, research, codex, settings
    }
    var selectedTab: GameTab = .city

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
    /// Premium currency — stub, will be populated when BE endpoint is ready.
    var premium: Int = 0
    /// Unread counts for side menu badges — stubs, will be wired to real data later.
    var unreadEmailCount: Int = 2
    var unreadNotificationCount: Int = 3

    /// Paginated movements — accumulated preko vise stranica.
    var activeMovements: [TroopMovement] = []
    /// Cursor za sledecu stranu movements-a. nil = nema vise stranica ili se jos nije fetch-ovalo.
    var movementsNextCursor: String?
    var movementsHasMore: Bool = false

    /// Paginated reports — accumulated preko vise stranica.
    var activeReports: [BattleReport] = []
    var reportsNextCursor: String?
    var reportsHasMore: Bool = false

    /// Rally list — fetched from GET /rally, auto-refresh on socket events.
    var activeRallies: [RallyItem] = []

    /// Guards against double-fire on infinite scroll (rapid onAppear triggers).
    private var isLoadingMoreMovements = false
    private var isLoadingMoreReports = false

    /// Observer for APNS device token delivery (from AppDelegate).
    private var deviceTokenObserver: NSObjectProtocol?

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

            // 3. Claim session (safe no-op if same device)
            await claimSession()

            // 4. Register for push notifications (after session claim)
            await registerForPush()

            // 5. Ako ima worlds, proveri da li je već join-ovao
            if let worlds = response.player.worlds, !worlds.isEmpty {
                let pw = worlds[0]
                activePlayerWorld = pw

                let allWorlds = try await api.worlds()
                activeWorld = allWorlds.first { $0.id == pw.worldId }

                if let city = pw.city {
                    do {
                        activeCity = try await api.city(id: city.id)
                    } catch {
                        Self.log.info("City fetch failed in bootstrap, using /me fallback: \(error.localizedDescription, privacy: .public)")
                        activeCity = City(id: city.id, name: city.name, resources: city.resources, tile: city.tile, buildings: city.buildings, troops: city.troops, reinforcements: city.reinforcements, constructionQueue: city.constructionQueue)
                    }
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
            case .unauthorized, .sessionKicked:
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

    // MARK: - Session

    /// Claims this device as the active session. Safe to call multiple times
    /// (same device = no-op on BE side, no kick emitted).
    private func claimSession() async {
        do {
            let _ = try await api.claimSession()
            Self.log.info("Session claimed for device \(Device.id, privacy: .public)")
        } catch {
            Self.log.error("Session claim failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Push Notifications (APNS)

    /// Requests push notification permission, registers for remote notifications,
    /// and sends the device token to BE. Called after successful session claim.
    func registerForPush() async {
        let center = UNUserNotificationCenter.current()
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            guard granted else {
                Self.log.info("Push notifications denied by user")
                return
            }
        } catch {
            Self.log.error("Push authorization error: \(error.localizedDescription, privacy: .public)")
            return
        }

        // Listen for token delivery from AppDelegate
        observeDeviceToken()

        // Trigger APNS registration (token arrives async via AppDelegate callback)
        await MainActor.run {
            UIApplication.shared.registerForRemoteNotifications()
        }

        // If token was already delivered before we started observing, send it now
        if let token = AppDelegate.pendingDeviceToken {
            await sendDeviceTokenToBE(token)
        }
    }

    /// Observes NotificationCenter for APNS token delivery and sends to BE.
    private func observeDeviceToken() {
        // Remove previous observer to avoid duplicates
        if let observer = deviceTokenObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        deviceTokenObserver = NotificationCenter.default.addObserver(
            forName: .didReceiveDeviceToken,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let token = notification.object as? String else { return }
            Task { [weak self] in
                await self?.sendDeviceTokenToBE(token)
            }
        }
    }

    /// Sends the APNS device token hex string to BE. Best-effort, no retry.
    private func sendDeviceTokenToBE(_ token: String) async {
        do {
            let _ = try await api.registerDeviceToken(token)
            Self.log.info("Device token registered with BE")
        } catch {
            Self.log.error("Device token registration failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Unregisters device token from BE. Called before signOut.
    private func unregisterDeviceToken() async {
        do {
            try await api.unregisterDeviceToken()
            Self.log.info("Device token unregistered from BE")
        } catch {
            Self.log.info("Device token unregister failed (continuing): \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Called when BE sends `session_kicked` via Socket.IO or when a REST call
    /// returns 401 `session_invalidated`. Force-logout the user.
    func handleSessionKicked(reason: String? = nil) async {
        Self.log.info("Session kicked: \(reason ?? "unknown", privacy: .public)")
        lastCompletionNotice = CompletionNotice(
            kind: .sessionKicked,
            title: "Signed Out",
            subtitle: "Your account was opened on another device"
        )
        await signOut()
    }

    // MARK: - Navigation Actions

    func didSignIn() async {
        await bootstrap()
    }

    func didOnboard(player: Player) async {
        currentPlayer = player
        await claimSession()
        await registerForPush()
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
            if let playerId = currentPlayer?.id {
                socket.joinPlayerRoom(playerId: playerId)
            }
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
        socket.onSessionKicked = { [weak self] event in
            Task { [weak self] in await self?.handleSessionKicked(reason: event.reason) }
        }
        socket.onRallyLaunched = { [weak self] event in
            Task { [weak self] in await self?.handleRallyLaunched(event) }
        }
        socket.onRallyResolved = { [weak self] event in
            Task { [weak self] in await self?.handleRallyResolved(event) }
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

    private func handleRallyLaunched(_ event: RallyLaunchedEvent) async {
        lastCompletionNotice = CompletionNotice(
            kind: .rallyLaunched,
            title: "Rally launched!",
            subtitle: "Troops are on the move"
        )
        await refreshRallies()
        await refreshMovements()
    }

    private func handleRallyResolved(_ event: RallyResolvedEvent) async {
        lastCompletionNotice = CompletionNotice(
            kind: .rallyResolved,
            title: "Rally combat finished",
            subtitle: "Check Reports for details"
        )
        await refreshRallies()
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

    // MARK: - Player refresh

    /// Re-fetch GET /me and update currentPlayer + activePlayerWorld.
    /// Useful after syndikat join/leave/role changes.
    func refreshMe() async throws {
        let meResponse = try await api.me()
        currentPlayer = meResponse.player
        if let pw = meResponse.player.worlds?.first(where: { $0.worldId == activeWorld?.id }) {
            activePlayerWorld = pw
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
        guard movementsHasMore, let cursor = movementsNextCursor, !isLoadingMoreMovements else { return }
        isLoadingMoreMovements = true
        defer { isLoadingMoreMovements = false }
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
        guard reportsHasMore, let cursor = reportsNextCursor, !isLoadingMoreReports else { return }
        isLoadingMoreReports = true
        defer { isLoadingMoreReports = false }
        do {
            let page = try await api.reports(worldId: worldId, limit: limit, before: cursor)
            activeReports.append(contentsOf: page.items)
            reportsNextCursor = page.nextCursor
            reportsHasMore = page.hasMore
        } catch {
            Self.log.info("Reports pagination failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Rallies

    func refreshRallies() async {
        guard let worldId = activePlayerWorld?.worldId ?? activeWorld?.id else { return }
        do {
            activeRallies = try await api.rallies(worldId: worldId)
        } catch {
            Self.log.info("Rallies refresh failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Crystal Implosion

    /// Pozvan nakon uspešnog `POST /cities/:id/implode`.
    /// Switchuje na novi grad (novi ID, novi ring), refreshuje sve, prikazuje toast.
    func handleImplodeSuccess(_ response: ImplodeResponse) async {
        // Fetch novi grad sa BE-a koristeći newCity.id
        do {
            activeCity = try await api.city(id: response.newCity.id)
        } catch {
            Self.log.error("Failed to fetch new city after implode: \(error.localizedDescription, privacy: .public)")
        }

        // Refresh player data (crystals array se menja posle implosion-a)
        do {
            let meResponse = try await api.me()
            currentPlayer = meResponse.player
            if let pw = meResponse.player.worlds?.first(where: { $0.worldId == activeWorld?.id }) {
                activePlayerWorld = pw
            }
        } catch {
            Self.log.error("Failed to refresh player after implode: \(error.localizedDescription, privacy: .public)")
        }

        // Reconnect socket na novi city room
        if let cityId = activeCity?.id {
            socket.joinCityRoom(cityId: cityId)
        }

        // Refresh movements (stari movements su nestali sa starim gradom)
        activeMovements = []
        movementsNextCursor = nil
        movementsHasMore = false

        // Toast
        let ringName = response.newRing.rawValue.capitalized
        lastCompletionNotice = CompletionNotice(
            kind: .implosion,
            title: "Crystal Implosion!",
            subtitle: "Relocated to \(ringName) ring"
        )
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    func signOut() async {
        // 1. Unregister device token from BE (best-effort, before session clear)
        await unregisterDeviceToken()
        // 2. Clear session on BE (best-effort)
        do { let _ = try await api.clearSession() } catch {
            Self.log.info("Session clear failed (continuing signOut): \(error.localizedDescription, privacy: .public)")
        }
        // 3. Disconnect Socket.IO
        socket.disconnect()
        // 4. Sign out from Supabase
        do { try await auth.signOut() } catch { }
        // 5. Remove token observer
        if let observer = deviceTokenObserver {
            NotificationCenter.default.removeObserver(observer)
            deviceTokenObserver = nil
        }
        AppDelegate.pendingDeviceToken = nil
        // 6. Clear local state
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
