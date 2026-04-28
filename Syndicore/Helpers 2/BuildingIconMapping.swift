import SwiftUI

// MARK: - BuildingType Icon, Name & Color Mapping

extension BuildingType {

    /// Asset name for the building's icon sprite (Build Queue, Building Menu, etc).
    var iconAssetName: String {
        switch self {
        // Resource buildings
        case .DATA_BANK:    return "building_icon_data_bank_v1"
        case .FOUNDRY:      return "building_icon_foundry_v1"
        case .TECH_LAB:     return "building_icon_tech_lab_v1"
        case .POWER_GRID:   return "building_icon_power_grid_v1"
        // Fixed buildings
        case .HQ:           return "building_icon_hq_v1"
        case .BARRACKS:     return "building_icon_barracks_v1"
        case .MOTOR_POOL:   return "building_icon_motor_pool_v1"
        case .OPS_CENTER:   return "building_icon_ops_center_v1"
        case .WAREHOUSE:    return "building_icon_warehouse_v1"
        case .WALL:         return "building_icon_wall_v1"
        case .WATCHTOWER:   return "building_icon_watchtower_v1"
        case .RALLY_POINT:  return "building_icon_rally_point_v1"
        case .TRADE_POST:   return "building_icon_trade_post_v1"
        case .RESEARCH_LAB: return "building_icon_research_lab_v1"
        }
    }

    /// Human-readable display name.
    var displayName: String {
        switch self {
        case .DATA_BANK:    return "Data Bank"
        case .FOUNDRY:      return "Foundry"
        case .TECH_LAB:     return "Tech Lab"
        case .POWER_GRID:   return "Power Grid"
        case .HQ:           return "Headquarters"
        case .BARRACKS:     return "Barracks"
        case .MOTOR_POOL:   return "Motor Pool"
        case .OPS_CENTER:   return "Ops Center"
        case .WAREHOUSE:    return "Warehouse"
        case .WALL:         return "Wall"
        case .WATCHTOWER:   return "Watchtower"
        case .RALLY_POINT:  return "Rally Point"
        case .TRADE_POST:   return "Trade Post"
        case .RESEARCH_LAB: return "Research Lab"
        }
    }

    /// Accent color for progress bars and highlights.
    var accentColor: Color {
        switch self {
        case .DATA_BANK:    return Color(red: 0.0, green: 0.9, blue: 1.0)   // cyan
        case .FOUNDRY:      return Color(red: 1.0, green: 0.55, blue: 0.1)  // orange-amber
        case .TECH_LAB:     return Color(red: 0.7, green: 0.3, blue: 1.0)   // purple
        case .POWER_GRID:   return Color(red: 1.0, green: 0.85, blue: 0.1)  // yellow
        case .HQ:           return Color(red: 1.0, green: 0.55, blue: 0.1)  // orange-amber
        case .BARRACKS:     return Color(red: 1.0, green: 0.3, blue: 0.3)   // red
        case .MOTOR_POOL:   return Color(red: 1.0, green: 0.5, blue: 0.1)   // orange
        case .OPS_CENTER:   return Color(red: 0.3, green: 1.0, blue: 0.4)   // green
        case .WAREHOUSE:    return Color(red: 0.0, green: 0.9, blue: 1.0)   // cyan
        case .WALL:         return Color(red: 0.3, green: 0.5, blue: 1.0)   // blue
        case .WATCHTOWER:   return Color(red: 0.0, green: 0.9, blue: 1.0)   // cyan
        case .RALLY_POINT:  return Color(red: 1.0, green: 0.3, blue: 0.9)   // magenta
        case .TRADE_POST:   return Color(red: 1.0, green: 0.85, blue: 0.1)  // gold-yellow
        case .RESEARCH_LAB: return Color(red: 0.7, green: 0.3, blue: 1.0)   // purple-violet
        }
    }
}
