import SwiftUI

struct TechTreeView: View {
    let gameData: GameData

    var body: some View {
        List {
            if let config = gameData.talentTree {
                if let standard = config.standard {
                    Section("Standard Talents") {
                        ForEach(["LOGISTICS", "SIEGE_ENGINEERING", "MOBILIZATION"], id: \.self) { branch in
                            if let nodes = standard[branch] {
                                DisclosureGroup(branch.displayName) {
                                    ForEach(nodes, id: \.key) { node in
                                        HStack {
                                            if node.capstone == true {
                                                Image(systemName: "star.fill")
                                                    .foregroundStyle(.yellow)
                                                    .font(.caption)
                                            }
                                            Text(node.label)
                                                .font(.subheadline)
                                            Spacer()
                                            if let effect = node.effectPerLevel ?? node.effect {
                                                let desc = effect.compactMap { key, val -> String? in
                                                    guard key != "capstone", key != "rename_unit" else { return nil }
                                                    switch val {
                                                    case .double(let v): return "+\(Int(v * 100))%"
                                                    case .int(let v): return "+\(v)"
                                                    default: return nil
                                                    }
                                                }.joined(separator: ", ")
                                                Text(desc)
                                                    .font(.caption)
                                                    .foregroundStyle(.green)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                if let factionTrees = config.faction {
                    Section("Faction Talents") {
                        ForEach(factionTrees.keys.sorted(), id: \.self) { factionKey in
                            if let units = factionTrees[factionKey] {
                                DisclosureGroup(factionKey.displayName) {
                                    ForEach(units.keys.sorted(), id: \.self) { unitKey in
                                        if let nodes = units[unitKey] {
                                            DisclosureGroup("\(unitKey.displayName) (\(nodes.count) talents)") {
                                                ForEach(nodes, id: \.key) { node in
                                                    HStack {
                                                        if node.capstone == true {
                                                            Image(systemName: "star.fill")
                                                                .foregroundStyle(.yellow)
                                                                .font(.caption)
                                                        }
                                                        Text(node.label)
                                                            .font(.caption)
                                                        Spacer()
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                if let cfg = config.config {
                    Section("Config") {
                        if let costs = cfg.standardCostPerLevel {
                            LabeledContent("Standard cost/level", value: costs.map { "\($0)" }.joined(separator: " → "))
                        }
                        if let fc = cfg.factionCost {
                            LabeledContent("Faction node cost", value: "\(fc) RP")
                        }
                        if let cd = cfg.respecCooldownDays {
                            LabeledContent("Respec cooldown", value: "\(cd) days")
                        }
                    }
                }
            } else {
                ContentUnavailableView("No Talent Data", systemImage: "cpu", description: Text("Game constants haven't loaded yet."))
            }
        }
        .navigationTitle("Talent Tree")
    }
}
