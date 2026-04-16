import SwiftUI

struct TechTreeView: View {
    let gameData: GameData

    var body: some View {
        List {
            ForEach(gameData.techTree.sorted(by: { $0.key < $1.key }), id: \.key) { name, branch in
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(name.replacingOccurrences(of: "_", with: " ").capitalized)
                                .font(.headline)
                            Spacer()
                            Text("\(branch.levels) levels")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        if let bonuses = branch.bonuses {
                            HStack(spacing: 4) {
                                ForEach(Array(bonuses.enumerated()), id: \.offset) { i, bonus in
                                    VStack(spacing: 2) {
                                        Text("Lv\(i + 1)")
                                            .font(.system(size: 10))
                                            .foregroundStyle(.secondary)
                                        Text("+\(Int(bonus * 100))%")
                                            .font(.caption.bold().monospacedDigit())
                                            .foregroundStyle(.green)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 4)
                                    .background(Color(.systemGray6))
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                }
                            }
                        }

                        HStack {
                            Image(systemName: "star.fill")
                                .foregroundStyle(.yellow)
                                .font(.caption)
                            Text(branch.capstone.replacingOccurrences(of: "_", with: " "))
                                .font(.caption.bold())
                                .foregroundStyle(.yellow)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("Tech Tree")
    }
}
