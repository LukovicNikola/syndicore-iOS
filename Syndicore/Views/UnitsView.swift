import SwiftUI

struct UnitsView: View {
    let gameData: GameData
    private var units: [(name: String, stats: UnitStats)] {
        gameData.units.map { (name: $0.key, stats: $0.value) }
            .sorted { $0.stats.energy < $1.stats.energy }
    }

    var body: some View {
        List {
            ForEach(units, id: \.name) { unit in
                NavigationLink {
                    UnitDetailView(name: unit.name, stats: unit.stats)
                } label: {
                    UnitRow(name: unit.name, stats: unit.stats)
                }
            }
        }
        .navigationTitle("Units")
    }
}

private struct UnitRow: View {
    let name: String
    let stats: UnitStats

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(name.replacingOccurrences(of: "_", with: " ").capitalized)
                    .font(.headline)
                Text("Trains at \(stats.trainsAt.replacingOccurrences(of: "_", with: " ").capitalized)")
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
