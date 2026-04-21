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
    let queryItems: [URLQueryItem]

    init(path: String, method: HTTPMethod = .get, requiresAuth: Bool = false, body: (any Encodable & Sendable)? = nil, queryItems: [URLQueryItem] = []) {
        self.path = path
        self.method = method
        self.requiresAuth = requiresAuth
        self.body = body
        self.queryItems = queryItems
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

    static func joinWorld(id: String, faction: Faction) -> Endpoint {
        Endpoint(
            path: "/api/v1/worlds/\(id)/join",
            method: .post,
            requiresAuth: true,
            body: JoinWorldRequest(faction: faction)
        )
    }
}

// MARK: - City

extension Endpoint {
    static func city(id: String) -> Endpoint {
        Endpoint(path: "/api/v1/cities/\(id)", requiresAuth: true)
    }

    static func build(cityId: String, body: any Encodable & Sendable) -> Endpoint {
        Endpoint(path: "/api/v1/cities/\(cityId)/build", method: .post, requiresAuth: true, body: body)
    }

    static func buildCost(cityId: String, buildingId: String) -> Endpoint {
        Endpoint(
            path: "/api/v1/cities/\(cityId)/build-cost",
            requiresAuth: true,
            queryItems: [URLQueryItem(name: "buildingId", value: buildingId)]
        )
    }

    static func train(cityId: String, unitType: String, count: Int) -> Endpoint {
        Endpoint(
            path: "/api/v1/cities/\(cityId)/train",
            method: .post,
            requiresAuth: true,
            body: TrainRequest(unitType: unitType, count: count)
        )
    }

    static func training(cityId: String) -> Endpoint {
        Endpoint(path: "/api/v1/cities/\(cityId)/training", requiresAuth: true)
    }

    static func skipBuild(cityId: String) -> Endpoint {
        Endpoint(path: "/api/v1/cities/\(cityId)/build/skip", method: .post, requiresAuth: true)
    }

    static func skipTraining(cityId: String, jobId: String) -> Endpoint {
        Endpoint(path: "/api/v1/cities/\(cityId)/train/\(jobId)/skip", method: .post, requiresAuth: true)
    }
}

// MARK: - Movements

extension Endpoint {
    static func skipMovement(worldId: String, movementId: String) -> Endpoint {
        Endpoint(path: "/api/v1/worlds/\(worldId)/movements/\(movementId)/skip", method: .post, requiresAuth: true)
    }
}

// MARK: - Map

extension Endpoint {
    static func mapViewport(worldId: String, cx: Int, cy: Int, radius: Int) -> Endpoint {
        Endpoint(
            path: "/api/v1/worlds/\(worldId)/map",
            requiresAuth: true,
            queryItems: [
                URLQueryItem(name: "cx", value: String(cx)),
                URLQueryItem(name: "cy", value: String(cy)),
                URLQueryItem(name: "r", value: String(radius))
            ]
        )
    }
}

// MARK: - Troops & Movement

extension Endpoint {
    static func sendTroops(cityId: String, body: any Encodable & Sendable) -> Endpoint {
        Endpoint(path: "/api/v1/cities/\(cityId)/send", method: .post, requiresAuth: true, body: body)
    }

    static func movements(worldId: String) -> Endpoint {
        Endpoint(path: "/api/v1/worlds/\(worldId)/movements", requiresAuth: true)
    }
}

// MARK: - Reports

extension Endpoint {
    static func reports(worldId: String) -> Endpoint {
        Endpoint(path: "/api/v1/worlds/\(worldId)/reports", requiresAuth: true)
    }
}

// MARK: - Request Bodies

struct TrainRequest: Codable, Sendable {
    let unitType: String
    let count: Int
}

struct BuildUpgradeRequest: Codable, Sendable {
    let buildingId: String
}

struct SendTroopsRequest: Codable, Sendable {
    let targetX: Int
    let targetY: Int
    let units: [String: Int]
    let movementType: String
}
