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
    private var pingTask: Task<Void, Never>?
    private var reconnectTask: Task<Void, Never>?

    private var connectionBaseURL: URL?
    private var connectionToken: String?

    private var joinedCityRoom: String?
    private var joinedWorldRoom: String?
    private var joinedPlayerRoom: String?

    private var reconnectAttempts: Int = 0
    private var intentionalDisconnect = false

    private let decoder: JSONDecoder = .api
    private let session = URLSession(configuration: .default)

    // MARK: - Singleton

    static let shared = SocketService()
    private init() {}

    // MARK: - Connection

    /// Uspostavlja WebSocket konekciju ka BE.
    func connect(baseURL: URL, token: String) {
        intentionalDisconnect = false
        connectionBaseURL = baseURL
        connectionToken = token
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

        guard let baseURL = connectionBaseURL, let token = connectionToken else { return }

        // Build wss:// URL: /api/v1/ws?token=<jwt>
        var components = URLComponents(url: baseURL.appendingPathComponent("api/v1/ws"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "token", value: token)]
        // Force wss:// for https:// base URLs
        if components.scheme == "https" {
            components.scheme = "wss"
        } else if components.scheme == "http" {
            components.scheme = "ws"
        }

        guard let wsURL = components.url else {
            Self.log.error("Failed to build WebSocket URL from \(baseURL.absoluteString, privacy: .public)")
            return
        }

        let task = session.webSocketTask(with: wsURL)
        task.resume()
        self.webSocketTask = task

        Self.log.info("WebSocket connecting to \(wsURL.host() ?? "unknown", privacy: .public)")

        // Start receive loop
        receiveTask = Task { [weak self] in
            await self?.receiveLoop()
        }
    }

    private func tearDown() {
        receiveTask?.cancel()
        receiveTask = nil
        pingTask?.cancel()
        pingTask = nil
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
                self.startPingTimer()
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

    // MARK: - Ping timer

    private func startPingTimer() {
        pingTask?.cancel()
        // Server sends ping every 25s — we just respond in handleMessage.
        // No client-side ping needed, but we keep reference for cleanup.
    }

    // MARK: - Re-join rooms on reconnect

    private func rejoinRooms() {
        if let player = joinedPlayerRoom { send(action: "join_player", id: player) }
        if let city = joinedCityRoom { send(action: "join_city", id: city) }
        if let world = joinedWorldRoom { send(action: "join_world", id: world) }
    }

    // MARK: - Auto-reconnect

    private func scheduleReconnect() {
        guard !intentionalDisconnect else { return }
        reconnectTask?.cancel()
        reconnectTask = Task { [weak self] in
            guard let self else { return }
            let delay = self.reconnectDelay()
            Self.log.info("Reconnecting in \(delay, privacy: .public)s (attempt \(self.reconnectAttempts + 1, privacy: .public))")
            try? await Task.sleep(for: .seconds(delay))
            if Task.isCancelled { return }
            await MainActor.run {
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
