import Foundation
import Observation
import os

/// Native WebSocket klijent za Syndicore BE real-time events.
///
/// Koristi `URLSessionWebSocketTask` — zero external dependencies.
/// BE endpoint: `GET /api/v1/ws?token=<jwt>` (plain WebSocket, JSON messages).
///
/// **Lifecycle:**
/// 1. `connect(baseURL:token:)` — pozvan iz GameState.bootstrap nakon uspešnog login-a.
/// 2. `joinCityRoom(cityId:)` — pretplata na city events (incoming_attack, building_complete, training_complete).
/// 3. `joinWorldRoom(worldId:)` — za world events (troops_arrived, rally_launched, rally_resolved).
/// 4. `joinPlayerRoom(playerId:)` — za player events (session_kicked).
/// 5. `disconnect()` — na signOut.
///
/// **UI rule:** events su SAMO refresh triggeri — UI observira @Observable properties
/// i refetch-uje REST state posle event-a.
@Observable
@MainActor
final class SocketService {

    nonisolated static let log = Logger(subsystem: "com.syndicore.ios", category: "SocketService")

    // MARK: - Published state

    private(set) var isConnected: Bool = false
    private(set) var lastIncomingAttack: IncomingAttackEvent?
    private(set) var lastBuildingComplete: BuildingCompleteEvent?
    private(set) var lastTrainingComplete: TrainingCompleteEvent?
    private(set) var lastTroopsArrived: TroopsArrivedEvent?

    // MARK: - Optional callbacks

    var onIncomingAttack:   ((IncomingAttackEvent)   -> Void)?
    var onBuildingComplete: ((BuildingCompleteEvent) -> Void)?
    var onTrainingComplete: ((TrainingCompleteEvent) -> Void)?
    var onTroopsArrived:    ((TroopsArrivedEvent)    -> Void)?
    var onSessionKicked:    ((SessionKickedEvent)    -> Void)?
    var onRallyLaunched:    ((RallyLaunchedEvent)    -> Void)?
    var onRallyResolved:    ((RallyResolvedEvent)    -> Void)?

    // MARK: - Internal state

    private var webSocketTask: URLSessionWebSocketTask?
    private var receiveTask: Task<Void, Never>?
    private var reconnectTask: Task<Void, Never>?

    private var connectionBaseURL: URL?
    /// Token provider used to fetch a fresh JWT on every (re)connect — eliminates
    /// the "stale-token reconnect storm" failure mode where a long-lived cached
    /// token expires mid-reconnect-loop and every retry rejects with 401.
    private var tokenProvider: TokenProvider?

    private var joinedCityRoom: String?
    private var joinedWorldRoom: String?
    private var joinedPlayerRoom: String?

    private var reconnectAttempts: Int = 0
    private var intentionalDisconnect = false
    /// Set when the app goes background — keeps connection state for resume()
    /// without triggering reconnect storms during suspension.
    private var isSuspended = false

    private let decoder: JSONDecoder = .api
    private let session = URLSession(configuration: .default)

    // MARK: - Singleton

    static let shared = SocketService()
    private init() {}

    // MARK: - Connection

    /// Uspostavlja WebSocket konekciju ka BE. `tokenProvider` se zove na svakom
    /// (re)connect-u tako da reconnect posle expire-a token-a koristi svežu vrednost.
    func connect(baseURL: URL, tokenProvider: TokenProvider) {
        intentionalDisconnect = false
        isSuspended = false
        connectionBaseURL = baseURL
        self.tokenProvider = tokenProvider
        reconnectAttempts = 0

        establishConnection()
    }

    /// Background-suspend — drži konekcione parametre, ali zatvara WS pre nego
    /// što iOS sam ubije proces. Spreciti reconnect storm kad app dolazi nazad.
    func suspend() {
        guard !intentionalDisconnect else { return }
        isSuspended = true
        tearDown()
        isConnected = false
    }

    /// Foreground-resume — ako smo bili suspendovani, otvori novi WS sa svežim
    /// JWT-om iz tokenProvider-a.
    func resume() {
        guard isSuspended, !intentionalDisconnect else { return }
        isSuspended = false
        reconnectAttempts = 0
        establishConnection()
    }

    func disconnect() {
        intentionalDisconnect = true
        tearDown()
        joinedCityRoom = nil
        joinedWorldRoom = nil
        joinedPlayerRoom = nil
        isConnected = false
        clearHandlers()
        tokenProvider = nil
        connectionBaseURL = nil
    }

    /// Skida sve registered event callback-e bez gašenja konekcije. Razdvojeno od
    /// `disconnect()` — zovni kad menjaš handler ownership (npr. user logout pa
    /// nov GameState init), ali konekciju zatvori posebno.
    func clearHandlers() {
        onIncomingAttack = nil
        onBuildingComplete = nil
        onTrainingComplete = nil
        onTroopsArrived = nil
        onSessionKicked = nil
        onRallyLaunched = nil
        onRallyResolved = nil
    }

    // MARK: - Room joining

    func joinCityRoom(cityId: String) {
        if joinedCityRoom == cityId { return }
        if let prev = joinedCityRoom {
            send(action: "leave_city", id: prev)
        }
        send(action: "join_city", id: cityId)
        joinedCityRoom = cityId
        Self.log.info("Joined city room: \(cityId, privacy: .public)")
    }

    func joinWorldRoom(worldId: String) {
        if joinedWorldRoom == worldId { return }
        if let prev = joinedWorldRoom {
            send(action: "leave_world", id: prev)
        }
        send(action: "join_world", id: worldId)
        joinedWorldRoom = worldId
        Self.log.info("Joined world room: \(worldId, privacy: .public)")
    }

    func joinPlayerRoom(playerId: String) {
        if joinedPlayerRoom == playerId { return }
        if let prev = joinedPlayerRoom {
            send(action: "leave_player", id: prev)
        }
        send(action: "join_player", id: playerId)
        joinedPlayerRoom = playerId
        Self.log.info("Joined player room: \(playerId, privacy: .public)")
    }

    func clearIncomingAttack() {
        lastIncomingAttack = nil
    }

    // MARK: - Connection internals

    private func establishConnection() {
        tearDown()

        guard let baseURL = connectionBaseURL, let provider = tokenProvider else { return }

        // Fetch fresh JWT (Supabase SDK auto-refresh-uje ako je blizu expire-a) pa
        // tek onda gradi URL i konekciju.
        receiveTask = Task { [weak self] in
            guard let self else { return }
            let token: String
            do {
                token = try await provider.accessToken()
            } catch {
                await MainActor.run {
                    Self.log.error("WebSocket token fetch failed: \(error.localizedDescription, privacy: .public)")
                    self.scheduleReconnect()
                }
                return
            }

            guard let url = await self.buildWebSocketURL(baseURL: baseURL, token: token) else {
                return
            }

            await MainActor.run {
                let task = self.session.webSocketTask(with: url)
                task.resume()
                self.webSocketTask = task
                Self.log.info("WebSocket connecting to \(url.host() ?? "unknown", privacy: .public)")
            }

            await self.receiveLoop()
        }
    }

    private func buildWebSocketURL(baseURL: URL, token: String) async -> URL? {
        guard var components = URLComponents(url: baseURL.appendingPathComponent("api/v1/ws"), resolvingAgainstBaseURL: false) else {
            await MainActor.run {
                Self.log.error("Invalid baseURL for WebSocket: \(baseURL.absoluteString, privacy: .public)")
            }
            return nil
        }
        components.queryItems = [URLQueryItem(name: "token", value: token)]
        if components.scheme == "https" {
            components.scheme = "wss"
        } else if components.scheme == "http" {
            components.scheme = "ws"
        }
        if let url = components.url {
            return url
        }
        await MainActor.run {
            Self.log.error("Failed to build WebSocket URL from \(baseURL.absoluteString, privacy: .public)")
        }
        return nil
    }

    private func tearDown() {
        receiveTask?.cancel()
        receiveTask = nil
        reconnectTask?.cancel()
        reconnectTask = nil
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
    }

    // MARK: - Send

    private func send(action: String, id: String? = nil) {
        guard let ws = webSocketTask else { return }
        var dict: [String: String] = ["action": action]
        if let id { dict["id"] = id }
        guard let data = try? JSONSerialization.data(withJSONObject: dict),
              let str = String(data: data, encoding: .utf8) else { return }
        ws.send(.string(str)) { error in
            if let error {
                Self.log.error("WS send error: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    // MARK: - Receive loop

    private func receiveLoop() async {
        guard let ws = webSocketTask else { return }

        while !Task.isCancelled {
            do {
                let message = try await ws.receive()
                switch message {
                case .string(let text):
                    await handleMessage(text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        await handleMessage(text)
                    }
                @unknown default:
                    break
                }
            } catch {
                // Connection lost
                if !Task.isCancelled {
                    await MainActor.run {
                        self.isConnected = false
                        Self.log.info("WebSocket disconnected: \(error.localizedDescription, privacy: .public)")
                        self.scheduleReconnect()
                    }
                }
                return
            }
        }
    }

    // MARK: - Message handling

    private func handleMessage(_ text: String) async {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let event = json["event"] as? String else { return }

        let payload = json["data"]

        await MainActor.run {
            switch event {
            case "connected":
                self.isConnected = true
                self.reconnectAttempts = 0
                Self.log.info("WebSocket connected")
                self.rejoinRooms()

            case "ping":
                self.send(action: "pong")

            case "incoming_attack":
                self.decodeAndDispatch(IncomingAttackEvent.self, from: payload) { ev in
                    self.lastIncomingAttack = ev
                    self.onIncomingAttack?(ev)
                }

            case "building_complete":
                self.decodeAndDispatch(BuildingCompleteEvent.self, from: payload) { ev in
                    self.lastBuildingComplete = ev
                    self.onBuildingComplete?(ev)
                }

            case "training_complete":
                self.decodeAndDispatch(TrainingCompleteEvent.self, from: payload) { ev in
                    self.lastTrainingComplete = ev
                    self.onTrainingComplete?(ev)
                }

            case "troops_arrived":
                self.decodeAndDispatch(TroopsArrivedEvent.self, from: payload) { ev in
                    self.lastTroopsArrived = ev
                    self.onTroopsArrived?(ev)
                }

            case "session_kicked":
                self.decodeAndDispatch(SessionKickedEvent.self, from: payload) { ev in
                    self.onSessionKicked?(ev)
                }

            case "rally_launched":
                self.decodeAndDispatch(RallyLaunchedEvent.self, from: payload) { ev in
                    self.onRallyLaunched?(ev)
                }

            case "rally_resolved":
                self.decodeAndDispatch(RallyResolvedEvent.self, from: payload) { ev in
                    self.onRallyResolved?(ev)
                }

            default:
                Self.log.debug("Unknown WS event: \(event, privacy: .public)")
            }
        }
    }

    private func decodeAndDispatch<T: Decodable>(_ type: T.Type, from payload: Any?, handler: (T) -> Void) {
        guard let payload else { return }
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: payload)
            let event = try decoder.decode(T.self, from: jsonData)
            handler(event)
        } catch {
            Self.log.error("Failed to decode \(String(describing: T.self), privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Ping
    // Server šalje ping svakih 25s; mi samo odgovaramo u handleMessage("ping").
    // Nema client-side timer-a.

    // MARK: - Re-join rooms on reconnect

    private func rejoinRooms() {
        if let player = joinedPlayerRoom { send(action: "join_player", id: player) }
        if let city = joinedCityRoom { send(action: "join_city", id: city) }
        if let world = joinedWorldRoom { send(action: "join_world", id: world) }
    }

    // MARK: - Auto-reconnect

    private func scheduleReconnect() {
        guard !intentionalDisconnect, !isSuspended else { return }
        reconnectTask?.cancel()
        reconnectTask = Task { [weak self] in
            guard let self else { return }
            let delay = self.reconnectDelay()
            Self.log.info("Reconnecting in \(delay, privacy: .public)s (attempt \(self.reconnectAttempts + 1, privacy: .public))")
            try? await Task.sleep(for: .seconds(delay))
            if Task.isCancelled { return }
            await MainActor.run {
                guard !self.intentionalDisconnect, !self.isSuspended else { return }
                self.reconnectAttempts += 1
                self.establishConnection()
            }
        }
    }

    /// Exponential backoff: 2s, 4s, 8s, 16s, max 30s
    private func reconnectDelay() -> Double {
        min(Double(2 << min(reconnectAttempts, 4)), 30.0)
    }
}
