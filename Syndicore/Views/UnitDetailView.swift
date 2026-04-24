import SwiftUI

struct UnitDetailView: View {
    let name: String
    let stats: UnitStats

    private var displayName: String {
        name.displayName
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

            Section("Info") {
                LabeledContent("Trains At", value: stats.trainsAt.displayName)
                LabeledContent("Unlock Level", value: "\(stats.unlockLevel)")
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
