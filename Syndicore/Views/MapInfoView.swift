import SwiftUI

struct MapInfoView: View {
    let gameData: GameData

    private let zoneOrder = ["fringe", "grid", "core"]
    private let rarityOrder = ["common", "uncommon", "rare"]

    var body: some View {
        List {
            Section("Zones") {
                ForEach(zoneOrder, id: \.self) { zoneName in
                    if let zone = gameData.map.zones[zoneName] {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(zoneName.capitalized)
                                    .font(.headline)
                                Text("Min HQ Lv \(zone.minHq)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                if zone.productionBonus > 0 {
                                    Text("+\(Int(zone.productionBonus * 100))% prod")
                                        .font(.caption.bold())
                                        .foregroundStyle(.green)
                                } else {
                                    Text("No bonus")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                if zone.canDestroy {
                                    Text("Cities destructible")
                                        .font(.caption)
                                        .foregroundStyle(.red)
                                }
                            }
                        }
                    }
                }
            }

            Section("Terrains") {
                ForEach(gameData.map.terrains.sorted(by: { $0.key < $1.key }), id: \.key) { name, terrain in
                    HStack {
                        Text(name.capitalized)
                            .font(.subheadline)
                        Spacer()
                        if let bonusType = terrain.bonusType {
                            Text(bonusType.replacingOccurrences(of: "_", with: " "))
                                .font(.caption)
                                .foregroundStyle(.green)
                        } else {
                            Text("No bonus")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Section("Tile Rarities") {
                ForEach(rarityOrder, id: \.self) { rarity in
                    if let data = gameData.map.rarities[rarity] {
                        HStack {
                            Text(rarity.capitalized)
                                .font(.subheadline)
                            Spacer()
                            Text("+\(Int(data.bonus * 100))%")
                                .font(.caption.bold())
                                .foregroundStyle(.green)
                            Text("·")
                                .foregroundStyle(.secondary)
                            Text("\(Int(data.distribution * 100))% of tiles")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Map & Terrain")
    }
}
