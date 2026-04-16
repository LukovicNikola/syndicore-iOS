import Foundation

struct HealthResponse: Codable {
    let status: HealthStatus
    let game: String
    let db: DBStatus
    let commit: String

    enum HealthStatus: String, Codable {
        case ok
        case degraded
    }

    enum DBStatus: String, Codable {
        case ok
        case unreachable
    }
}
