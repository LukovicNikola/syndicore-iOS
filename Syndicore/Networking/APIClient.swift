import Foundation

/// Syndicore API client — async/await, zero third-party deps.
final class APIClient: Sendable {
    let baseURL: URL
    let session: URLSession
    let tokenProvider: TokenProvider
    let decoder: JSONDecoder
    let encoder: JSONEncoder

    init(
        baseURL: URL,
        tokenProvider: TokenProvider = StubTokenProvider(),
        session: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.tokenProvider = tokenProvider
        self.session = session

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder
    }

    // MARK: - Generic request

    func request<T: Decodable>(_ endpoint: Endpoint, as type: T.Type) async throws -> T {
        let (data, _) = try await raw(endpoint)
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }

    func requestVoid(_ endpoint: Endpoint) async throws {
        let _ = try await raw(endpoint)
    }

    // MARK: - Private

    private func raw(_ endpoint: Endpoint) async throws -> (Data, HTTPURLResponse) {
        guard let url = URL(string: endpoint.path, relativeTo: baseURL) else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if endpoint.requiresAuth {
            let token = try await tokenProvider.accessToken()
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body = endpoint.body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try encoder.encode(AnyEncodable(body))
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
        case 200...299:
            return (data, http)
        case 401:
            throw APIError.unauthorized
        case 404:
            if let onboarding = try? decoder.decode(OnboardingRequiredResponse.self, from: data) {
                throw APIError.onboardingRequired(onboarding)
            }
            throw APIError.notFound
        case 400:
            let err = (try? decoder.decode(ErrorResponse.self, from: data)) ?? ErrorResponse(error: "bad_request", details: nil)
            throw APIError.badRequest(err)
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
    func health() async throws -> HealthResponse {
        try await request(.health, as: HealthResponse.self)
    }

    func me() async throws -> MeResponse {
        try await request(.me, as: MeResponse.self)
    }

    func onboard(username: String) async throws -> MeResponse {
        try await request(.onboarding(username: username), as: MeResponse.self)
    }

    func worlds() async throws -> [WorldSummary] {
        try await request(.worlds, as: WorldsResponse.self).worlds
    }

    func world(id: String) async throws -> WorldSummary {
        try await request(.world(id: id), as: WorldSummary.self)
    }

    func joinWorld(id: String, faction: Faction) async throws {
        try await requestVoid(.joinWorld(id: id, faction: faction))
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
