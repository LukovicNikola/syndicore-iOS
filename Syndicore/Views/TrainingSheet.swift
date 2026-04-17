import SwiftUI

struct TrainingSheet: View {
    @Environment(GameState.self) private var gameState
    @Environment(\.dismiss) private var dismiss

    @State private var selectedUnit: String?
    @State private var count = 1
    @State private var isTraining = false
    @State private var errorMessage: String?

    private var factionKey: String? {
        gameState.activePlayerWorld?.faction.rawValue.lowercased()
    }

    private var availableUnits: [(name: String, stats: UnitStats)] {
        guard let key = factionKey,
              let gameData = gameState.gameConstants.gameData,
              let units = gameData.units[key] else { return [] }
        return units.map { (name: $0.key, stats: $0.value) }
            .sorted { $0.stats.energy < $1.stats.energy }
    }

    @ViewBuilder
    private func unitRow(unit: (name: String, stats: UnitStats)) -> some View {
        let subtitle = "\(unit.stats.role.capitalized) · ATK \(unit.stats.atk) · DEF \(unit.stats.def)"
        let isSelected = selectedUnit == unit.name
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(unit.name.replacingOccurrences(of: "_", with: " ").capitalized)
                    .font(.subheadline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color.accentColor)
            }
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Select Unit") {
                    ForEach(availableUnits, id: \.name) { unit in
                        Button {
                            selectedUnit = unit.name
                        } label: {
                            unitRow(unit: unit)
                        }
                        .tint(.primary)
                    }
                }

                if availableUnits.isEmpty {
                    Section {
                        Text("No game data loaded — check Codex tab")
                            .foregroundStyle(.secondary)
                    }
                }

                if let selected = selectedUnit,
                   let unit = availableUnits.first(where: { $0.name == selected }) {
                    Section("Count") {
                        Stepper("×\(count)", value: $count, in: 1...100)

                        let costLines = unit.stats.cost.sorted(by: { $0.key < $1.key })
                        ForEach(costLines, id: \.key) { resource, amount in
                            LabeledContent(resource.capitalized, value: "\(amount * count)")
                        }
                        LabeledContent("Time", value: "\(unit.stats.trainMin * count) min")
                    }

                    Section {
                        Button {
                            Task { await train(unitType: selected) }
                        } label: {
                            if isTraining {
                                ProgressView().frame(maxWidth: .infinity)
                            } else {
                                Text("Train \(count)× \(selected.replacingOccurrences(of: "_", with: " ").capitalized)")
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isTraining)
                    }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Train Units")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private func train(unitType: String) async {
        guard let cityId = gameState.activeCity?.id else { return }
        isTraining = true
        errorMessage = nil
        do {
            _ = try await gameState.api.train(cityId: cityId, unitType: unitType.uppercased(), count: count)
            await gameState.refreshCity()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        isTraining = false
    }
}
