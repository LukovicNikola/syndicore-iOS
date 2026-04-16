import Foundation

/// Map ring — progression order: FRINGE → GRID → CORE → NEXUS.
enum Ring: String, Codable, CaseIterable {
    case fringe = "FRINGE"
    case grid = "GRID"
    case core = "CORE"
    case nexus = "NEXUS"

    var displayName: String {
        switch self {
        case .fringe: "Fringe"
        case .grid: "Grid"
        case .core: "Core"
        case .nexus: "Nexus"
        }
    }
}
