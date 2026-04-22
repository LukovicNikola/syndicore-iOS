import Foundation
import Observation
import os
#if canImport(SocketIO)
import SocketIO
#endif

/// Socket.IO klijent za Syndicore BE real-time events.
///
/// **Zahteva SPM dependency:**
///   `.package(url: "https://github.com/socketio/socket.io-client-swift", from: "16.1.0")`
///
/// Ako dependency nije dodat u Xcode project, `import SocketIO` će fail-ovati i
/// SocketService će biti stub koji loguje upozorenje ali ne radi ništa.
/// Ostatak app-a radi normalno — real-time features su "optional" until dep is added.
///
/// **Lifecycle:**
/// 1. `connect(baseURL:token:)` — pozvan iz GameState.bootstrap nakon uspešnog login-a.
/// 2. `joinCityRoom(cityId:)` — posle join world-a, pretplata na city events (incoming_attack,
///    building_complete, training_complete).
/// 3. `joinWorldRoom(worldId:)` — za world events (troops_arrived).
/// 4. `disconnect()` — na signOut.
///
/// **UI rule:** events su refresh triggeri. UI observira @Observable properties
/// (`lastIncomingAttack`, `lastBuildingComplete`, itd.) i refetch-uje REST state.
@Observable
@MainActor
final class SocketService {

    static let log = Logger(subsystem: "com.syndicore.ios", category: "SocketService")

    // MARK: - Published state (Observable via @Observable)

    private(set) var isConnected: Bool = false
    private(set) var lastIncomingAttack: IncomingAttackEvent?
    private(set) var lastBuildingComplete: BuildingCompleteEvent?
    private(set) var lastTrainingComplete: TrainingCompleteEvent?
    private(set) var lastTroopsArrived: TroopsArrivedEvent?

    // MARK: - Optional callbacks (za view-ove koje žele direktan handler umesto @Observable)

    var onIncomingAttack:   ((IncomingAttackEvent)   -> Void)?
    var onBuildingComplete: ((BuildingCompleteEvent) -> Void)?
    var onTrainingComplete: ((TrainingCompleteEvent) -> Void)?
    var onTroopsArrived:    ((TroopsArrivedEvent)    -> Void)?

    // MARK: - Internal state

    #if canImport(SocketIO)
    private var manager: SocketManager?
    private var socket: SocketIOClient?
    #endif

    private var joinedCityRoom: String?
    private var joinedWorldRoom: String?

    private let decoder: JSONDecoder = .api

    // MARK: - Singleton

    static let shared = SocketService()
    private init() {}

    // MARK: - Connection

    /// Uspostavlja Socket.IO konekciju. Pozvati nakon uspešnog auth-a.
    /// - Parameter baseURL: BE root URL (isti kao API, npr. https://syndicore-be-staging.onrender.com)
    /// - Parameter token: JWT access token iz Supabase session-a
    func connect(baseURL: URL, token: String) {
        #if canImport(SocketIO)
        disconnect()  // idempotent — clean up any previous connection

        let mgr = SocketManager(
            socketURL: baseURL,
            config: [
                .log(false),
                .compress,
                .connectParams(["token": token]),
                .reconnects(true),
                .reconnectAttempts(-1),   // beskonačni retry
                .reconnectWait(2),
                .reconnectWaitMax(30)
            ]
        )
        let sock = mgr.defaultSocket

        attachHandlers(to: sock)
        sock.connect()

        self.manager = mgr
        self.socket = sock
        Self.log.info("Socket connecting to \(baseURL.absoluteString, privacy: .public)")
        #else
        Self.log.warning("SocketIO not imported — real-time events disabled. Add socket.io-client-swift SPM dep to enable.")
        #endif
    }

    func disconnect() {
        #if canImport(SocketIO)
        socket?.disconnect()
        socket = nil
        manager = nil
        #endif
        joinedCityRoom = nil
        joinedWorldRoom = nil
        isConnected = false
        onIncomingAttack = nil
        onBuildingComplete = nil
        onTrainingComplete = nil
        onTroopsArrived = nil
    }

    // MARK: - Room joining

    /// Pretplata na per-city events. Zove se posle `connect(...)` + kad se aktivna city promeni.
    func joinCityRoom(cityId: String) {
        #if canImport(SocketIO)
        guard let socket else { return }
        // Ako smo već u toj sobi, skip
        if joinedCityRoom == cityId { return }
        // Leave prethodnu sobu
        if let prev = joinedCityRoom {
            socket.emit("leave_city", prev)
        }
        socket.emit("join_city", cityId)
        joinedCityRoom = cityId
        Self.log.info("Joined city room: \(cityId, privacy: .public)")
        #endif
    }

    /// Reset-uje lastIncomingAttack — pozvan iz UI-ja kad user dismiss-uje banner ili
    /// kad countdown dođe na 0.
    func clearIncomingAttack() {
        lastIncomingAttack = nil
    }

    /// Pretplata na world-wide events (troops_arrived). Zove se posle connect + kad se world promeni.
    func joinWorldRoom(worldId: String) {
        #if canImport(SocketIO)
        guard let socket else { return }
        if joinedWorldRoom == worldId { return }
        if let prev = joinedWorldRoom {
            socket.emit("leave_world", prev)
        }
        socket.emit("join_world", worldId)
        joinedWorldRoom = worldId
        Self.log.info("Joined world room: \(worldId, privacy: .public)")
        #endif
    }

    // MARK: - Event handlers

    #if canImport(SocketIO)
    private func attachHandlers(to socket: SocketIOClient) {
        socket.on(clientEvent: .connect) { [weak self] _, _ in
            Task { @MainActor in
                self?.isConnected = true
                Self.log.info("Socket connected")
                // Re-join rooms ako smo imali prethodne (reconnect scenario)
                if let city = self?.joinedCityRoom { socket.emit("join_city", city) }
                if let world = self?.joinedWorldRoom { socket.emit("join_world", world) }
            }
        }

        socket.on(clientEvent: .disconnect) { [weak self] _, _ in
            Task { @MainActor in
                self?.isConnected = false
                Self.log.info("Socket disconnected")
            }
        }

        socket.on(clientEvent: .error) { data, _ in
            Self.log.error("Socket error: \(String(describing: data), privacy: .public)")
        }

        // Incoming attack (city room)
        socket.on("incoming_attack") { [weak self] data, _ in
            self?.handleEvent(IncomingAttackEvent.self, from: data) { event in
                self?.lastIncomingAttack = event
                self?.onIncomingAttack?(event)
            }
        }

        // Building complete (city room)
        socket.on("building_complete") { [weak self] data, _ in
            self?.handleEvent(BuildingCompleteEvent.self, from: data) { event in
                self?.lastBuildingComplete = event
                self?.onBuildingComplete?(event)
            }
        }

        // Training complete (city room)
        socket.on("training_complete") { [weak self] data, _ in
            self?.handleEvent(TrainingCompleteEvent.self, from: data) { event in
                self?.lastTrainingComplete = event
                self?.onTrainingComplete?(event)
            }
        }

        // Troops arrived (world room)
        socket.on("troops_arrived") { [weak self] data, _ in
            self?.handleEvent(TroopsArrivedEvent.self, from: data) { event in
                self?.lastTroopsArrived = event
                self?.onTroopsArrived?(event)
            }
        }
    }

    /// Decode helper — Socket.IO prosleđuje `[Any]` sa payload JSON-om u prvom elementu.
    private func handleEvent<T: Decodable>(
        _ type: T.Type,
        from data: [Any],
        onSuccess: @escaping @MainActor (T) -> Void
    ) {
        guard let first = data.first else { return }
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: first, options: [])
            let event = try decoder.decode(T.self, from: jsonData)
            Task { @MainActor in onSuccess(event) }
        } catch {
            Self.log.error("Failed to decode \(String(describing: T.self), privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }
    #endif
}
