import Foundation

/// Player faction (per world). Matches Prisma enum.
enum Faction: String, Codable, CaseIterable, Identifiable {
    case reapers = "REAPERS"
    case hegemony = "HEGEMONY"
    case netrunners = "NETRUNNERS"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .reapers: "Reapers"
        case .hegemony: "Hegemony"
        case .netrunners: "Netrunners"
        }
    }

    var tagline: String {
        switch self {
        case .reapers: "Offensive faction. Fast, cheap units. Wave attacks."
        case .hegemony: "Defensive faction. Tanky, expensive units. Synergy-based defense."
        case .netrunners: "Economy/Intel faction. Information warfare, resource raids."
        }
    }

    var bonusType: String {
        switch self {
        case .reapers: "ATK"
        case .hegemony: "DEF"
        case .netrunners: "PRODUCTION"
        }
    }

    var bonusValue: Double {
        switch self {
        case .reapers: 0.15
        case .hegemony: 0.15
        case .netrunners: 0.20
        }
    }
}
