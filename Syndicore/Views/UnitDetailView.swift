import SwiftUI

struct UnitDetailView: View {
    let name: String
    let stats: UnitStats
    let faction: Faction

    private var displayName: String {
        name.replacingOccurrences(of: "_", with: " ").capitalized
    }

    var body: some View {
        List {
            Section("Combat") {
                StatRow(label: "Attack", value: "\(stats.atk)", icon: "flame.fill", tint: .red)
                StatRow(label: "Defense", value: "\(stats.def)", icon: "shield.fill", tint: .blue)
                StatRow(label: "Speed", value: "\(stats.spd)", icon: "bolt.fill", tint: .green)
                StatRow(label: "Carry", value: "\(stats.carry)", icon: "shippingbox.fill", tint: .orange)
                StatRow(label: "Energy", value: "\(stats.energy)", icon: "bolt.circle.fill", tint: .yellow)
            }

            Section("Training") {
                StatRow(label: "Time", value: "\(stats.trainMin) min", icon: "clock.fill", tint: .purple)
                ForEach(stats.cost.sorted(by: { $0.key < $1.key }), id: \.key) { resource, amount in
                    StatRow(label: resource.capitalized, value: "\(amount)", icon: "circle.fill", tint: .secondary)
                }
            }

            if let special = stats.special {
                Section("Ability") {
                    Label(special.replacingOccurrences(of: "_", with: " "), systemImage: "star.fill")
                        .foregroundStyle(.yellow)

                    if let scout = stats.scout {
                        StatRow(label: "Scout Range", value: "\(scout)", icon: "eye.fill", tint: .cyan)
                    }
                    if let siege = stats.siege {
                        StatRow(label: "Siege Power", value: "\(siege)", icon: "hammer.fill", tint: .red)
                    }
                    if let counterScout = stats.counterScout {
                        StatRow(label: "Counter-Scout", value: "\(counterScout)", icon: "eye.trianglebadge.exclamationmark", tint: .orange)
                    }
                    if let shieldPct = stats.shieldPct {
                        StatRow(label: "Shield", value: "\(Int(shieldPct * 100))%", icon: "shield.checkered", tint: .blue)
                    }
                    if let bypassPct = stats.bypassPct {
                        StatRow(label: "Warehouse Bypass", value: "\(Int(bypassPct * 100))%", icon: "lock.open.fill", tint: .orange)
                    }
                    if let pveBonus = stats.pveBonus {
                        StatRow(label: "PvE Bonus", value: "+\(Int(pveBonus * 100))%", icon: "target", tint: .green)
                    }
                    if let prodPenalty = stats.productionPenalty, let hours = stats.penaltyHours {
                        StatRow(label: "Econ Damage", value: "-\(Int(prodPenalty * 100))% for \(hours)h", icon: "chart.line.downtrend.xyaxis", tint: .red)
                    }
                }
            }

            Section("Info") {
                LabeledContent("Role", value: stats.role.capitalized)
                LabeledContent("Faction", value: faction.displayName)
            }
        }
        .navigationTitle(displayName)
    }
}

private struct StatRow: View {
    let label: String
    let value: String
    let icon: String
    let tint: Color

    var body: some View {
        LabeledContent {
            Text(value).monospacedDigit().bold()
        } label: {
            Label(label, systemImage: icon).foregroundStyle(tint)
        }
    }
}
