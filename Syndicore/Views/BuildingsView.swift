import SwiftUI

struct BuildingsView: View {
    let gameData: GameData

    var body: some View {
        List {
            Section("Resource Buildings") {
                ForEach(gameData.buildings.resource.sorted(by: { $0.key < $1.key }), id: \.key) { name, building in
                    NavigationLink {
                        ResourceBuildingDetailView(name: name, building: building, formulas: gameData.buildingFormulas)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(formatName(name))
                                    .font(.headline)
                                Text("Produces \(building.produces)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("Lv \(building.maxLevel)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Section("Fixed Buildings") {
                ForEach(gameData.buildings.fixed.sorted(by: { $0.key < $1.key }), id: \.key) { name, building in
                    NavigationLink {
                        FixedBuildingDetailView(name: name, building: building, formulas: gameData.buildingFormulas)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(formatName(name))
                                    .font(.headline)
                                Text("Max Lv \(building.maxLevel)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                    }
                }
            }
        }
        .navigationTitle("Buildings")
    }

    private func formatName(_ name: String) -> String {
        name.displayName
    }
}

private struct ResourceBuildingDetailView: View {
    let name: String
    let building: ResourceBuildingData
    let formulas: BuildingFormulas

    var body: some View {
        List {
            Section("Production") {
                LabeledContent("Produces", value: building.produces.capitalized)
                LabeledContent("Base Rate", value: "\(building.baseRate)/hr")
                LabeledContent("Max Rate", value: "\(building.maxRate)/hr")
                LabeledContent("Max Level", value: "\(building.maxLevel)")
            }
            Section("Base Cost (Lv 1)") {
                ForEach(building.baseCost.sorted(by: { $0.key < $1.key }), id: \.key) { resource, amount in
                    LabeledContent(resource.capitalized, value: "\(amount)")
                }
                LabeledContent("Build Time", value: "\(building.baseTimeMinutes) min")
            }
            Section("Scaling") {
                LabeledContent("Cost per level", value: String(format: "%.1fx", formulas.costMultiplier))
                LabeledContent("Time per level", value: String(format: "%.1fx", formulas.timeMultiplier))
            }
        }
        .navigationTitle(name.displayName)
    }
}

private struct FixedBuildingDetailView: View {
    let name: String
    let building: FixedBuildingData
    let formulas: BuildingFormulas

    var body: some View {
        List {
            Section("General") {
                LabeledContent("Max Level", value: "\(building.maxLevel)")
                LabeledContent("Build Time", value: "\(building.baseTimeMinutes) min")
            }
            Section("Base Cost (Lv 1)") {
                ForEach(building.baseCost.sorted(by: { $0.key < $1.key }), id: \.key) { resource, amount in
                    LabeledContent(resource.capitalized, value: "\(amount)")
                }
            }
            if let unlocks = building.unlocks {
                Section("Unit Unlocks") {
                    ForEach(unlocks.sorted(by: { Int($0.key) ?? 0 < Int($1.key) ?? 0 }), id: \.key) { level, role in
                        LabeledContent("Lv \(level)", value: role.capitalized)
                    }
                }
            }
            if let slots = building.slots {
                Section("Building Slots") {
                    ForEach(slots.sorted(by: { Int($0.key) ?? 0 < Int($1.key) ?? 0 }), id: \.key) { level, count in
                        LabeledContent("Lv \(level)", value: "\(count) slots")
                    }
                }
            }
            if let points = building.points {
                Section("Research Points") {
                    ForEach(points.sorted(by: { Int($0.key) ?? 0 < Int($1.key) ?? 0 }), id: \.key) { level, pts in
                        LabeledContent("Lv \(level)", value: "\(pts) pts")
                    }
                }
            }
            if building.defBonusMin != nil || building.protectionMin != nil {
                Section("Bonuses") {
                    if let min = building.defBonusMin, let max = building.defBonusMax {
                        LabeledContent("Defense Bonus", value: "\(Int(min * 100))% – \(Int(max * 100))%")
                    }
                    if let min = building.protectionMin, let max = building.protectionMax {
                        LabeledContent("Protection", value: "\(min) – \(max)")
                    }
                }
            }
            Section("Scaling") {
                LabeledContent("Cost per level", value: String(format: "%.1fx", formulas.costMultiplier))
                LabeledContent("Time per level", value: String(format: "%.1fx", formulas.timeMultiplier))
            }
        }
        .navigationTitle(name.displayName)
    }
}
