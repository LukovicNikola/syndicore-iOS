import SwiftUI

/// Sheet koji prikazuje sakupljene kristale i njihove kumulativne bonuse.
/// Kristali se dobijaju Crystal Implosion-om (HQ 20 → sruši grad → preseli se u sledeći ring).
struct CrystalSheet: View {
    @Environment(GameState.self) private var gameState
    @Environment(\.dismiss) private var dismiss

    /// Kristali iz PlayerWorld — niz ring imena (npr. ["FRINGE", "FRINGE", "GRID"])
    private var crystals: [String] {
        gameState.activePlayerWorld?.crystals ?? []
    }

    /// Grupisani kristali po ring-u sa brojem
    private var groupedCrystals: [(ring: String, count: Int)] {
        let counts = crystals.reduce(into: [String: Int]()) { acc, ring in
            acc[ring, default: 0] += 1
        }
        // Sortiramo po ring redosledu: FRINGE → GRID → CORE
        let order = ["FRINGE", "GRID", "CORE"]
        return order.compactMap { ring in
            guard let count = counts[ring] else { return nil }
            return (ring: ring, count: count)
        }
    }

    /// Kumulativni bonusi svih kristala
    private var totalBonuses: (production: Double, atk: Double, def: Double) {
        guard let crystalData = gameState.gameConstants.gameData?.crystals else {
            return (0, 0, 0)
        }
        var prod = 0.0, atk = 0.0, def = 0.0
        for crystal in crystals {
            if let bonus = crystalData[crystal] {
                prod += bonus.productionBonus
                atk += bonus.atkBonus
                def += bonus.defBonus
            }
        }
        return (prod, atk, def)
    }

    var body: some View {
        NavigationStack {
            List {
                if crystals.isEmpty {
                    Section {
                        ContentUnavailableView(
                            "No Crystals",
                            systemImage: "diamond",
                            description: Text("Reach HQ level 20 and use Crystal Implosion to collect crystals and advance to the next ring.")
                        )
                    }
                } else {
                    // Collected crystals
                    Section("Collected Crystals") {
                        ForEach(groupedCrystals, id: \.ring) { item in
                            HStack {
                                Image(systemName: "diamond.fill")
                                    .foregroundStyle(ringColor(item.ring))
                                Text("\(item.ring.capitalized) Crystal")
                                    .font(.subheadline)
                                Spacer()
                                Text("×\(item.count)")
                                    .font(.subheadline.monospacedDigit().bold())
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    // Cumulative bonuses
                    Section {
                        let bonuses = totalBonuses
                        if bonuses.production > 0 {
                            HStack {
                                Label("Production", systemImage: "chart.line.uptrend.xyaxis")
                                    .font(.subheadline)
                                Spacer()
                                Text("+\(Int(bonuses.production * 100))%")
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.green)
                            }
                        }
                        if bonuses.atk > 0 {
                            HStack {
                                Label("Attack", systemImage: "burst.fill")
                                    .font(.subheadline)
                                Spacer()
                                Text("+\(Int(bonuses.atk * 100))%")
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.red)
                            }
                        }
                        if bonuses.def > 0 {
                            HStack {
                                Label("Defense", systemImage: "shield.fill")
                                    .font(.subheadline)
                                Spacer()
                                Text("+\(Int(bonuses.def * 100))%")
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.blue)
                            }
                        }
                        if bonuses.production == 0 && bonuses.atk == 0 && bonuses.def == 0 {
                            Text("No active bonuses")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    } header: {
                        Text("Total Bonuses")
                    } footer: {
                        Text("Bonuses from all crystals stack and apply permanently to your city.")
                    }
                }

                // Ring progression
                Section {
                    RingProgressionView(
                        currentRing: gameState.activePlayerWorld?.ring ?? .fringe,
                        completedRings: Set(crystals)
                    )
                    .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                } header: {
                    Text("Ring Progression")
                } footer: {
                    let index = Ring.allCases.firstIndex(of: gameState.activePlayerWorld?.ring ?? .fringe) ?? 0
                    Text("Ring \(index + 1) of \(Ring.allCases.count) · \(crystals.count) crystal\(crystals.count == 1 ? "" : "s") collected")
                }
            }
            .navigationTitle("Crystals")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private func ringColor(_ ring: String) -> Color {
        switch ring {
        case "FRINGE": .gray
        case "GRID":   .orange
        case "CORE":   .red
        default:       .purple
        }
    }
}

// MARK: - Ring Progression View

/// Horizontalni stepper: FRINGE ── GRID ── CORE ── NEXUS
/// sa vizuelnim indikatorom trenutnog ringa i prošlih (completed) ringova.
private struct RingProgressionView: View {
    let currentRing: Ring
    let completedRings: Set<String>

    private let rings = Ring.allCases

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(rings.enumerated()), id: \.element) { index, ring in
                // Node (circle + label)
                VStack(spacing: 4) {
                    ZStack {
                        Circle()
                            .fill(nodeFill(for: ring))
                            .frame(width: 24, height: 24)
                        if ring == currentRing {
                            Circle()
                                .strokeBorder(nodeColor(for: ring), lineWidth: 2)
                                .frame(width: 30, height: 30)
                        }
                        if completedRings.contains(ring.rawValue) && ring != currentRing {
                            Image(systemName: "diamond.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(.white)
                        } else if ring == currentRing {
                            Image(systemName: "location.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(.white)
                        }
                    }
                    .frame(height: 32)

                    Text(ring.displayName)
                        .font(.system(size: 9, weight: ring == currentRing ? .bold : .regular))
                        .foregroundStyle(ring == currentRing ? .primary : .secondary)
                }
                .frame(maxWidth: .infinity)

                // Connector line between nodes
                if index < rings.count - 1 {
                    Rectangle()
                        .fill(connectorColor(after: ring))
                        .frame(height: 2)
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 18)
                }
            }
        }
    }

    private func nodeFill(for ring: Ring) -> Color {
        if ring == currentRing { return nodeColor(for: ring) }
        if completedRings.contains(ring.rawValue) { return nodeColor(for: ring).opacity(0.7) }
        return Color(.systemGray4)
    }

    private func nodeColor(for ring: Ring) -> Color {
        switch ring {
        case .fringe: .gray
        case .grid:   .orange
        case .core:   .red
        case .nexus:  .purple
        }
    }

    /// Connector is colored if the ring AFTER it has been reached or passed.
    private func connectorColor(after ring: Ring) -> Color {
        guard let idx = rings.firstIndex(of: ring),
              idx + 1 < rings.count else { return Color(.systemGray4) }
        let nextRing = rings[idx + 1]
        let currentIdx = rings.firstIndex(of: currentRing) ?? 0
        let nextIdx = rings.firstIndex(of: nextRing) ?? 0
        return nextIdx <= currentIdx ? nodeColor(for: ring).opacity(0.5) : Color(.systemGray4)
    }
}
