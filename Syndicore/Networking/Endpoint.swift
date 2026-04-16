import Foundation

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
}

struct Endpoint {
    let path: String
    let method: HTTPMethod
    let requiresAuth: Bool
    let body: (any Encodable & Sendable)?

    init(path: String, method: HTTPMethod = .get, requiresAuth: Bool = false, body: (any Encodable & Sendable)? = nil) {
        self.path = path
        self.method = method
        self.requiresAuth = requiresAuth
        self.body = body
    }
}

// MARK: - System

extension Endpoint {
    static let health = Endpoint(path: "/health")

    static let gameConfig = Endpoint(path: "/api/v1/config")
}

// MARK: - Player

extension Endpoint {
    static let me = Endpoint(path: "/api/v1/me", requiresAuth: true)

    static func onboarding(username: String) -> Endpoint {
        Endpoint(
            path: "/api/v1/me/onboarding",
            method: .post,
            requiresAuth: true,
            body: OnboardingRequest(username: username)
        )
    }
}

// MARK: - Worlds

extension Endpoint {
    static let worlds = Endpoint(path: "/api/v1/worlds")

    static func world(id: String) -> Endpoint {
        Endpoint(path: "/api/v1/worlds/\(id)")
    }

    static func joinWorld(id: String, faction: Faction) -> Endpoint {
        Endpoint(
            path: "/api/v1/worlds/\(id)/join",
            method: .post,
            requiresAuth: true,
            body: JoinWorldRequest(faction: faction)
        )
    }
}
