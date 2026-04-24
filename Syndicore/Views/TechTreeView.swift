import SwiftUI

struct TechTreeView: View {
    let gameData: GameData

    private var allBranches: [(name: String, branch: TechBranchData, isUniversal: Bool)] {
        let universal = gameData.techTree.universal.map { (name: $0.key, branch: $0.value, isUniversal: true) }
        let faction = gameData.techTree.faction.map { (name: $0.key, branch: $0.value, isUniversal: false) }
        return (universal + faction).sorted { $0.name < $1.name }
    }

    var body: some View {
        List {
            ForEach(allBranches, id: \.name) { item in
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(item.name.displayName)
                                .font(.headline)
                            Spacer()
                            if let faction = item.branch.faction {
                                Text(faction)
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                            } else {
                                Text("Universal")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Text("\(item.branch.maxLevel) levels")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        // Point costs
                        HStack(spacing: 4) {
                            ForEach(Array(item.branch.pointCosts.enumerated()), id: \.offset) { i, cost in
                                VStack(spacing: 2) {
                                    Text("Lv\(i + 1)")
                                        .font(.system(size: 10))
                                        .foregroundStyle(.secondary)
                                    Text("\(cost)p")
                                        .font(.caption.bold().monospacedDigit())
                                        .foregroundStyle(.cyan)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 4)
                                .background(Color(.systemGray6))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                        }

                        // Capstone (last effect with "capstone" key)
                        if let lastEffect = item.branch.effects.last,
                           case .string(let capstone) = lastEffect["capstone"] {
                            HStack {
                                Image(systemName: "star.fill")
                                    .foregroundStyle(.yellow)
                                    .font(.caption)
                                Text(capstone.replacingOccurrences(of: "_", with: " "))
                                    .font(.caption.bold())
                                    .foregroundStyle(.yellow)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("Tech Tree")
    }
}
