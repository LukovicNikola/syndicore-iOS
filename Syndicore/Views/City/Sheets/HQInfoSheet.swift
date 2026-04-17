import SwiftUI

/// Sheet koji se prikazuje kad igrač tapne na HQ tile.
struct HQInfoSheet: View {
    let city: City?
    @Environment(\.dismiss) private var dismiss

    private var hqBuilding: BuildingInfo? {
        city?.buildings?.first { $0.type == .HQ }
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Headquarters") {
                    if let hq = hqBuilding {
                        LabeledContent("Level", value: "\(hq.currentLevel)")
                        if hq.isUpgrading, let endsAt = hq.endsAt {
                            HStack {
                                Text("Upgrading to Lv \(hq.targetLevel ?? hq.currentLevel + 1)")
                                    .font(.subheadline)
                                    .foregroundStyle(.orange)
                                Spacer()
                                CountdownLabel(endsAt: endsAt)
                            }
                        }
                    } else {
                        Text("HQ data not available")
                            .foregroundStyle(.secondary)
                    }
                }

                Section("City") {
                    if let city {
                        LabeledContent("Name", value: city.name)
                        if let tile = city.tile {
                            LabeledContent("Location", value: "(\(tile.x), \(tile.y))")
                            LabeledContent("Ring", value: tile.ring.rawValue.capitalized)
                            LabeledContent("Terrain", value: tile.terrain.rawValue
                                .replacingOccurrences(of: "_", with: " ").capitalized)
                        }
                    }
                }
            }
            .navigationTitle("HQ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}
