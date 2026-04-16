import SwiftUI

struct UnitsView: View {
    let gameData: GameData
    @State private var selectedFaction: Faction = .reapers

    private var units: [(name: String, stats: UnitStats)] {
        let key = selectedFaction.rawValue.lowercased()
        guard let factionUnits = gameData.units[key] else { return [] }
        return factionUnits.map { (name: $0.key, stats: $0.value) }
            .sorted { $0.stats.energy < $1.stats.energy }
    }

    var body: some View {
        List {
            Picker("Faction", selection: $selectedFaction) {
                ForEach(Faction.allCases) { faction in
                    Text(faction.displayName).tag(faction)
                }
            }
            .pickerStyle(.segmented)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
            .padding(.horizontal)

            ForEach(units, id: \.name) { unit in
                NavigationLink {
                    UnitDetailView(name: unit.name, stats: unit.stats, faction: selectedFaction)
                } label: {
                    UnitRow(name: unit.name, stats: unit.stats)
                }
            }
        }
        .navigationTitle("Units")
    }
}

// MARK: - Unit Row

private struct UnitRow: View {
    let name: String
    let stats: UnitStats

    private var displayName: String {
        name.replacingOccurrences(of: "_", with: " ").capitalized
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(displayName)
                    .font(.headline)
                Text(stats.role.capitalized)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            HStack(spacing: 12) {
                StatBadge(label: "ATK", value: stats.atk, color: .red)
                StatBadge(label: "DEF", value: stats.def, color: .blue)
                StatBadge(label: "SPD", value: stats.spd, color: .green)
            }
        }
        .padding(.vertical, 2)
    }
}

private struct StatBadge: View {
    let label: String
    let value: Int
    let color: Color

    var body: some View {
        VStack(spacing: 1) {
            Text("\(value)")
                .font(.subheadline.bold().monospacedDigit())
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
        }
        .frame(width: 36)
    }
}
