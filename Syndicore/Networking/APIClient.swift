import Foundation
import os

/// Syndicore API client — async/await, zero third-party deps.
/// Base URL i token provider se injektuju u init (AppConfig se loaduje u SyndicoreApp).
final class APIClient: @unchecked Sendable {
    let baseURL: URL
    let session: URLSession
    let tokenProvider: TokenProvider
    let decoder: JSONDecoder
    let encoder: JSONEncoder

    static let log = Logger(subsystem: "com.syndicore.ios", category: "APIClient")

    init(
        baseURL: URL,
        tokenProvider: TokenProvider = SupabaseTokenProvider(),
        session: URLSession? = nil
    ) {
        self.baseURL = baseURL
        self.tokenProvider = tokenProvider
        if let session {
            self.session = session
        } else {
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest  = 90   // Render free-tier cold start može trajati 60-90s
            config.timeoutIntervalForResource = 120
            self.session = URLSession(configuration: config)
        }
        self.decoder = .api
        self.encoder = .api
    }

    // MARK: - Generic request

    func request<T: Decodable>(_ endpoint: Endpoint, as type: T.Type, timeout: TimeInterval? = nil) async throws -> T {
        let (data, _) = try await withOptionalTimeout(timeout) {
            try await self.raw(endpoint)
        }
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            Self.log.error("Decode failure for \(endpoint.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
            throw APIError.decodingError(error)
        }
    }

    func requestVoid(_ endpoint: Endpoint, timeout: TimeInterval? = nil) async throws {
        let _ = try await withOptionalTimeout(timeout) {
            try await self.raw(endpoint)
        }
    }

    // MARK: - Timeout helper

    /// Wraps an async operation with an optional timeout. If timeout is nil, runs without timeout.
    /// URLSession already has a 90s timeout for Render cold starts; this adds a per-request cap.
    private func withOptionalTimeout<T: Sendable>(_ timeout: TimeInterval?, operation: @escaping @Sendable () async throws -> T) async throws -> T {
        guard let timeout else { return try await operation() }
        return try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask { try await operation() }
            group.addTask {
                try await Task.sleep(for: .seconds(timeout))
                throw APIError.timeout(timeout)
            }
            guard let result = try await group.next() else {
                throw APIError.timeout(timeout)
            }
            group.cancelAll()
            return result
        }
    }

    // MARK: - Private

    /// Izvrsava HTTP request sa auth header-om i 401 retry logikom.
    /// Na 401: pokusava jedan refresh token + replay. Ako i posle refresh-a dobije 401,
    /// baca APIError.unauthorized (pozivalac treba da sign-out-uje korisnika).
    private func raw(_ endpoint: Endpoint, retryingAfter401: Bool = false) async throws -> (Data, HTTPURLResponse) {
        guard let baseEndpointURL = URL(string: endpoint.path, relativeTo: baseURL),
              var components = URLComponents(url: baseEndpointURL, resolvingAgainstBaseURL: true) else {
            throw APIError.invalidURL
        }
        if !endpoint.queryItems.isEmpty {
            components.queryItems = (components.queryItems ?? []) + endpoint.queryItems
        }
        guard let url = components.url else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if endpoint.requiresAuth {
            let token: String
            if retryingAfter401 {
                token = try await tokenProvider.refreshToken()
            } else {
                token = try await tokenProvider.accessToken()
            }
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue(Device.id, forHTTPHeaderField: "X-Device-ID")
        }

        if let body = endpoint.body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try encoder.encode(AnyEncodable(body))
        }

        Self.log.debug("→ \(endpoint.method.rawValue, privacy: .public) \(endpoint.path, privacy: .public)\(retryingAfter401 ? " (retry)" : "", privacy: .public)")

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            Self.log.error("Transport error on \(endpoint.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
            throw APIError.networkError(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw APIError.unexpectedStatus(-1, data)
        }

        Self.log.debug("← \(http.statusCode) \(endpoint.path, privacy: .public) (\(data.count) bytes)")

        switch http.statusCode {
        case 200...299:
            return (data, http)
        case 401:
            // Parse error body to distinguish session errors from token errors
            if let errResp = try? decoder.decode(ErrorResponse.self, from: data) {
                switch errResp.code {
                case .sessionInvalidated:
                    // Another device claimed the session — force logout, no retry
                    throw APIError.sessionKicked
                case .noActiveSession:
                    // Session not claimed yet — caller should claim then retry
                    throw APIError.noActiveSession
                case .missingDeviceId:
                    Self.log.error("BUG: X-Device-ID header missing on \(endpoint.path, privacy: .public)")
                    throw APIError.unauthorized
                default:
                    break
                }
            }
            // Token expired — try one refresh + replay
            if endpoint.requiresAuth && !retryingAfter401 {
                Self.log.info("401 on \(endpoint.path, privacy: .public) — attempting token refresh + replay")
                do {
                    return try await raw(endpoint, retryingAfter401: true)
                } catch {
                    Self.log.info("Refresh + replay failed: \(error.localizedDescription, privacy: .public)")
                    throw APIError.unauthorized
                }
            }
            throw APIError.unauthorized
        case 404:
            if let onboarding = try? decoder.decode(OnboardingRequiredResponse.self, from: data) {
                throw APIError.onboardingRequired(onboarding)
            }
            throw APIError.notFound
        case 400:
            let err = (try? decoder.decode(ErrorResponse.self, from: data)) ?? ErrorResponse(error: "bad_request", details: nil)
            throw APIError.badRequest(err)
        case 403:
            let err = (try? decoder.decode(ErrorResponse.self, from: data)) ?? ErrorResponse(error: "forbidden", details: nil)
            throw APIError.forbidden(err)
        case 409:
            let err = (try? decoder.decode(ErrorResponse.self, from: data)) ?? ErrorResponse(error: "conflict", details: nil)
            throw APIError.conflict(err)
        case 500...599:
            let err = (try? decoder.decode(ErrorResponse.self, from: data)) ?? ErrorResponse(error: "server_error", details: nil)
            throw APIError.server(err)
        default:
            throw APIError.unexpectedStatus(http.statusCode, data)
        }
    }
}

// MARK: - Convenience methods

extension APIClient {

    // System
    func health() async throws -> HealthResponse {
        try await request(.health, as: HealthResponse.self)
    }

    // Player
    func me() async throws -> MeResponse {
        try await request(.me, as: MeResponse.self)
    }

    func onboard(username: String) async throws -> MeResponse {
        try await request(.onboarding(username: username), as: MeResponse.self)
    }

    // Session
    func claimSession() async throws -> SessionClaimResponse {
        try await request(.sessionClaim(deviceId: Device.id), as: SessionClaimResponse.self)
    }

    func clearSession() async throws -> SessionClearResponse {
        try await request(.sessionClear, as: SessionClearResponse.self)
    }

    // Device Token (APNS)
    func registerDeviceToken(_ token: String) async throws -> DeviceTokenResponse {
        try await request(.registerDeviceToken(token), as: DeviceTokenResponse.self)
    }

    func unregisterDeviceToken() async throws {
        try await requestVoid(.unregisterDeviceToken)
    }

    // Worlds
    func worlds() async throws -> [World] {
        try await request(.worlds, as: WorldsResponse.self, timeout: 30).worlds
    }

    func joinWorld(id: String, faction: Faction) async throws -> JoinWorldResponse {
        try await request(.joinWorld(id: id, faction: faction), as: JoinWorldResponse.self)
    }

    // City
    func city(id: String) async throws -> City {
        try await request(.city(id: id), as: CityResponse.self, timeout: 30).city
    }

    // Map
    func mapViewport(worldId: String, cx: Int, cy: Int, radius: Int) async throws -> MapViewport {
        try await request(.mapViewport(worldId: worldId, cx: cx, cy: cy, radius: radius), as: MapViewport.self, timeout: 30)
    }

    // Movements (paginated)
    /// Vraca jednu stranu movements-a. Za prvu stranu `before` = nil.
    /// Za sledecu stranu, prosledi `nextCursor` iz prethodne odgovora.
    func movements(worldId: String, limit: Int = 50, before: String? = nil) async throws -> PaginatedMovementsResponse {
        try await request(
            .movements(worldId: worldId, limit: limit, before: before),
            as: PaginatedMovementsResponse.self
        )
    }

    /// Convenience: vraca SAMO prvu stranu kao flat `[TroopMovement]` array.
    /// Za full listu ili kasnije strane, koristi paginirani `movements(worldId:limit:before:)`.
    func firstPageMovements(worldId: String, limit: Int = 50) async throws -> [TroopMovement] {
        try await movements(worldId: worldId, limit: limit, before: nil).items
    }

    // City actions
    func buildCost(cityId: String, buildingId: String) async throws -> BuildCostResponse {
        try await request(.buildCost(cityId: cityId, buildingId: buildingId), as: BuildCostResponse.self)
    }

    func buildUpgrade(cityId: String, buildingId: String) async throws -> BuildResponse {
        try await request(.build(cityId: cityId, body: BuildUpgradeRequest(buildingId: buildingId)), as: BuildResponse.self)
    }

    func buildNew(cityId: String, buildingType: BuildingType, slotIndex: Int? = nil) async throws -> BuildResponse {
        struct Body: Encodable { let buildingType: String; let slotIndex: Int? }
        return try await request(.build(cityId: cityId, body: Body(buildingType: buildingType.rawValue, slotIndex: slotIndex)), as: BuildResponse.self)
    }

    func train(cityId: String, unitType: String, count: Int) async throws -> TrainResponse {
        try await request(.train(cityId: cityId, unitType: unitType, count: count), as: TrainResponse.self)
    }

    func trainingJobs(cityId: String) async throws -> [TrainingJob] {
        try await request(.training(cityId: cityId), as: TrainingListResponse.self).training
    }

    // Crystal Implosion
    func implode(cityId: String) async throws -> ImplodeResponse {
        try await request(.implode(cityId: cityId), as: ImplodeResponse.self)
    }

    // Skip (instant complete — test/premium feature)
    func skipBuild(cityId: String) async throws {
        try await requestVoid(.skipBuild(cityId: cityId))
    }

    func skipTraining(cityId: String, jobId: String) async throws {
        try await requestVoid(.skipTraining(cityId: cityId, jobId: jobId))
    }

    func skipMovement(worldId: String, movementId: String) async throws {
        try await requestVoid(.skipMovement(worldId: worldId, movementId: movementId))
    }

    // Rally
    func rallies(worldId: String) async throws -> [RallyItem] {
        try await request(.rallyList(worldId: worldId), as: RallyListResponse.self).rallies
    }

    func createRally(worldId: String, targetX: Int, targetY: Int, launchAt: Date, units: [UnitType: Int]) async throws -> RallyItem {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let body = CreateRallyRequest(
            targetX: targetX,
            targetY: targetY,
            launchAt: formatter.string(from: launchAt),
            units: units.reduce(into: [:]) { $0[$1.key.rawValue] = $1.value }
        )
        return try await request(.createRally(worldId: worldId, body: body), as: CreateRallyResponse.self).rally
    }

    func joinRally(worldId: String, rallyId: String, units: [UnitType: Int]) async throws {
        let body = JoinRallyRequest(units: units.reduce(into: [:]) { $0[$1.key.rawValue] = $1.value })
        let _ = try await request(.joinRally(worldId: worldId, rallyId: rallyId, body: body), as: JoinRallyResponse.self)
    }

    func leaveRally(worldId: String, rallyId: String) async throws {
        let _ = try await request(.leaveRally(worldId: worldId, rallyId: rallyId), as: LeaveRallyResponse.self)
    }

    func cancelRally(worldId: String, rallyId: String) async throws {
        let _ = try await request(.cancelRally(worldId: worldId, rallyId: rallyId), as: CancelRallyResponse.self)
    }

    // Reinforcement recall
    func recallReinforcement(reinforcementId: String) async throws -> RecallReinforcementResponse {
        try await request(.recallReinforcement(reinforcementId: reinforcementId), as: RecallReinforcementResponse.self)
    }

    // Send Troops
    /// Šalje vojsku iz grada `cityId` na tile `(targetX, targetY)` sa tipom pokreta
    /// `movementType` (ATTACK / RAID / SCOUT / REINFORCE / TRANSPORT / SETTLE).
    /// BE vraca kreirani `TroopMovement` + `Route` (direct ili preko warp gate-ova).
    func sendTroops(
        cityId: String,
        targetX: Int,
        targetY: Int,
        units: [UnitType: Int],
        movementType: MovementType
    ) async throws -> SendTroopsResponse {
        // BE ocekuje string keys za units (UnitType rawValue-ovi)
        let stringKeyedUnits = units.reduce(into: [String: Int]()) { acc, pair in
            acc[pair.key.rawValue] = pair.value
        }
        let body = SendTroopsRequest(
            targetX: targetX,
            targetY: targetY,
            units: stringKeyedUnits,
            movementType: movementType.rawValue
        )
        return try await request(
            .sendTroops(cityId: cityId, body: body),
            as: SendTroopsResponse.self
        )
    }

    // Reports (paginated)
    /// Vraca jednu stranu battle reports-a. Za prvu stranu `before` = nil.
    /// Za sledecu stranu, prosledi `nextCursor` iz prethodne odgovora.
    func reports(worldId: String, limit: Int = 50, before: String? = nil) async throws -> PaginatedReportsResponse {
        try await request(
            .reports(worldId: worldId, limit: limit, before: before),
            as: PaginatedReportsResponse.self
        )
    }

    /// Convenience: vraca SAMO prvu stranu kao flat `[BattleReport]` array.
    func firstPageReports(worldId: String, limit: Int = 50) async throws -> [BattleReport] {
        try await reports(worldId: worldId, limit: limit, before: nil).items
    }

    // MARK: - Game constants (ETag cache)

    enum ConfigResult {
        case updated(Data, etag: String)
        case notModified
    }

    func gameConstants(etag: String?) async throws -> ConfigResult {
        guard let url = URL(string: Endpoint.gameConfig.path, relativeTo: baseURL) else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if let etag {
            request.setValue(etag, forHTTPHeaderField: "If-None-Match")
        }

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.networkError(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw APIError.unexpectedStatus(-1, data)
        }

        switch http.statusCode {
        case 304:
            return .notModified
        case 200:
            let newEtag = http.value(forHTTPHeaderField: "ETag") ?? ""
            return .updated(data, etag: newEtag)
        default:
            throw APIError.unexpectedStatus(http.statusCode, data)
        }
    }
}

// MARK: - Type-erased Encodable wrapper

private struct AnyEncodable: Encodable {
    private let encode: (Encoder) throws -> Void

    init(_ value: Encodable) {
        self.encode = value.encode
    }

    func encode(to encoder: Encoder) throws {
        try encode(encoder)
    }
}
