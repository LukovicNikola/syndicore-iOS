import SwiftUI

/// Sheet za izgradnju nove zgrade na tile-u koji je korisnik tapnuo.
///
/// **Free placement:** Prikazuje SVE nezagrađene zgrade (fixed + resource) bez obzira
/// na poziciju tile-a. `slotIndex` se uvek šalje BE-u — i za fixed i za resource zgrade.
struct BuildSheet: View {
    let cityId: String
    let hasQueue: Bool
    let slotIndex: Int
    /// Building types koji već postoje u gradu (za filtriranje — one-per-city constraint).
    let existingTypes: Set<BuildingType>

    @Environment(GameState.self) private var gameState
    @Environment(\.dismiss) private var dismiss

    /// Sve zgrade koje igrač može da izgradi (fixed koje još nema + resource tipovi).
    private var buildableTypes: [BuildingType] {
        var types: [BuildingType] = []

        // Fixed buildings — one per city, prikazuj samo ako još nije izgrađena
        let fixedTypes: [BuildingType] = [
            .BARRACKS, .MOTOR_POOL, .OPS_CENTER, .WAREHOUSE,
            .WALL, .WATCHTOWER, .RALLY_POINT, .TRADE_POST, .RESEARCH_LAB
        ]
        for ft in fixedTypes where !existingTypes.contains(ft) {
            types.append(ft)
        }

        // Resource buildings — mogu se graditi više puta (flex slots)
        types.append(contentsOf: [.DATA_BANK, .FOUNDRY, .TECH_LAB, .POWER_GRID])

        return types
    }

    var body: some View {
        NavigationStack {
            Group {
                if buildableTypes.isEmpty {
                    ContentUnavailableView(
                        "No Buildings Available",
                        systemImage: "checkmark.seal.fill",
                        description: Text("All buildings have been constructed.")
                    )
                } else {
                    List(buildableTypes, id: \.self) { type in
                        BuildableRow(
                            buildingType: type,
                            cityId: cityId,
                            disabled: hasQueue,
                            costPreview: costPreview(for: type),
                            slotIndex: slotIndex
                        )
                    }
                }
            }
            .navigationTitle("Build")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private func costPreview(for type: BuildingType) -> BuildCostPreview? {
        guard let gd = gameState.gameConstants.gameData else { return nil }
        let key = type.rawValue.lowercased()

        if let rb = gd.buildings.resource[key] {
            return BuildCostPreview(
                credits: rb.baseCost["credits"] ?? 0,
                alloys: rb.baseCost["alloys"] ?? 0,
                tech: rb.baseCost["tech"] ?? 0,
                durationMinutes: rb.baseTimeMinutes
            )
        }
        if let fb = gd.buildings.fixed[key] {
            return BuildCostPreview(
                credits: fb.baseCost["credits"] ?? 0,
                alloys: fb.baseCost["alloys"] ?? 0,
                tech: fb.baseCost["tech"] ?? 0,
                durationMinutes: fb.baseTimeMinutes
            )
        }
        return nil
    }
}

struct BuildCostPreview {
    let credits: Int
    let alloys: Int
    let tech: Int
    let durationMinutes: Int
}

// MARK: - Row

private struct BuildableRow: View {
    let buildingType: BuildingType
    let cityId: String
    let disabled: Bool
    let costPreview: BuildCostPreview?
    let slotIndex: Int

    @Environment(GameState.self) private var gameState
    @Environment(\.dismiss) private var dismiss

    @State private var isBuilding = false
    @State private var errorMessage: String?

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(buildingType.rawValue
                        .replacingOccurrences(of: "_", with: " ")
                        .capitalized)
                    .font(.subheadline)
                if let cost = costPreview {
                    HStack(spacing: 8) {
                        if cost.credits > 0 { Label("\(cost.credits)", systemImage: "dollarsign.circle").font(.caption2) }
                        if cost.alloys > 0  { Label("\(cost.alloys)", systemImage: "gearshape.fill").font(.caption2) }
                        if cost.tech > 0    { Label("\(cost.tech)", systemImage: "cpu").font(.caption2) }
                        Label("\(cost.durationMinutes)m", systemImage: "clock").font(.caption2)
                    }
                    .foregroundStyle(.secondary)
                }
                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            Spacer()
            Button {
                Task { await build() }
            } label: {
                if isBuilding {
                    ProgressView().scaleEffect(0.8)
                } else {
                    Text("Build")
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .disabled(disabled || isBuilding)
        }
    }

    private func build() async {
        isBuilding   = true
        errorMessage = nil
        do {
            // Always send slotIndex — BE stores position for all building types.
            _ = try await gameState.api.buildNew(cityId: cityId, buildingType: buildingType, slotIndex: slotIndex)
            await gameState.refreshCity()
            dismiss()
        } catch let error as APIError {
            switch error {
            case .badRequest(let e): errorMessage = e.error
            case .conflict(let e):  errorMessage = e.error
            default:                errorMessage = error.localizedDescription
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isBuilding = false
    }
}
