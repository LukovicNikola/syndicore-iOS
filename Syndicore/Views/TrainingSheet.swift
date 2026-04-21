import SwiftUI

struct TrainingSheet: View {
    @Environment(GameState.self) private var gameState
    @Environment(\.dismiss) private var dismiss

    @State private var selectedUnit: String?
    @State private var count = 1
    @State private var isTraining = false
    @State private var errorMessage: String?

    private var allUnits: [(name: String, stats: UnitStats)] {
        guard let gameData = gameState.gameConstants.gameData else { return [] }
        return gameData.units.map { (name: $0.key, stats: $0.value) }
            .sorted { $0.stats.energy < $1.stats.energy }
    }

    private var resources: Resources? { gameState.activeCity?.resources }

    /// Returns the player's building level for a given building key (e.g. "barracks", "motor_pool")
    private func buildingLevel(for trainsAt: String) -> Int {
        guard let buildings = gameState.activeCity?.buildings else { return 0 }
        let buildingType = trainsAt.uppercased()
        return buildings.first(where: { $0.type.rawValue == buildingType })?.currentLevel ?? 0
    }

    private func isUnlocked(_ unit: (name: String, stats: UnitStats)) -> Bool {
        buildingLevel(for: unit.stats.trainsAt) >= unit.stats.unlockLevel
    }

    /// Max units the player can afford given current resources
    private func maxAffordable(_ stats: UnitStats) -> Int {
        guard let res = resources else { return 100 }
        var maxCount = 100
        for (resource, amount) in stats.cost where amount > 0 {
            let available: Double
            switch resource.lowercased() {
            case "credits": available = res.credits
            case "alloys":  available = res.alloys
            case "tech":    available = res.tech
            case "energy":  available = res.energy ?? 0
            default: continue
            }
            maxCount = min(maxCount, Int(available) / amount)
        }
        return max(maxCount, 0)
    }

    /// Whether the current count exceeds a specific resource
    private func exceedsResource(_ resource: String, amount: Int) -> Bool {
        guard let res = resources else { return false }
        let totalCost = amount * count
        let available: Double
        switch resource.lowercased() {
        case "credits": available = res.credits
        case "alloys":  available = res.alloys
        case "tech":    available = res.tech
        case "energy":  available = res.energy ?? 0
        default: return false
        }
        return Double(totalCost) > available
    }

    private var canAfford: Bool {
        guard let selected = selectedUnit,
              let unit = allUnits.first(where: { $0.name == selected }) else { return false }
        return maxAffordable(unit.stats) >= count
    }

    @ViewBuilder
    private func unitRow(unit: (name: String, stats: UnitStats)) -> some View {
        let subtitle = "ATK \(unit.stats.atk) · DEF \(unit.stats.def) · SPD \(unit.stats.spd)"
        let isSelected = selectedUnit == unit.name
        let unlocked = isUnlocked(unit)
        let currentLevel = buildingLevel(for: unit.stats.trainsAt)
        let buildingName = unit.stats.trainsAt.replacingOccurrences(of: "_", with: " ").capitalized

        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(unit.name.replacingOccurrences(of: "_", with: " ").capitalized)
                    .font(.subheadline)
                    .foregroundStyle(unlocked ? .primary : .secondary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if !unlocked {
                    Text("\(buildingName) Lv\(unit.stats.unlockLevel) required (yours: \(currentLevel))")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }
            Spacer()
            if !unlocked {
                Image(systemName: "lock.fill")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            } else if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color.accentColor)
            }
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Select Unit") {
                    ForEach(allUnits, id: \.name) { unit in
                        Button {
                            if isUnlocked(unit) {
                                selectedUnit = unit.name
                                // Reset count to 1 when switching unit, clamp to affordable
                                count = min(1, maxAffordable(unit.stats))
                            }
                        } label: {
                            unitRow(unit: unit)
                        }
                        .tint(.primary)
                        .disabled(!isUnlocked(unit))
                    }
                }

                if allUnits.isEmpty {
                    Section {
                        Text("No game data loaded — check Codex tab")
                            .foregroundStyle(.secondary)
                    }
                }

                if let selected = selectedUnit,
                   let unit = allUnits.first(where: { $0.name == selected }) {
                    let maxCount = maxAffordable(unit.stats)

                    Section("Count") {
                        if maxCount <= 0 {
                            Text("Not enough resources")
                                .foregroundStyle(.red)
                                .font(.subheadline)
                        } else {
                            Stepper("×\(count)", value: $count, in: 1...maxCount)

                            let costLines = unit.stats.cost.sorted(by: { $0.key < $1.key })
                            ForEach(costLines, id: \.key) { resource, amount in
                                let over = exceedsResource(resource, amount: amount)
                                LabeledContent {
                                    Text("\(amount * count)")
                                        .foregroundStyle(over ? .red : .primary)
                                        .bold(over)
                                } label: {
                                    Text(resource.capitalized)
                                }
                            }
                            LabeledContent("Time", value: "\(unit.stats.trainMin * count) min")
                        }
                    }

                    if maxCount > 0 {
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
                            .disabled(isTraining || !canAfford)
                        }
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
            errorMessage = "\(error)"
        }
        isTraining = false
    }
}
