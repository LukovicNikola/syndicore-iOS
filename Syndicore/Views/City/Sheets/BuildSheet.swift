import SwiftUI

/// Sheet za izgradnju nove zgrade na tačnom tile-u koji je korisnik tapnuo.
///
/// `tappedSlot` određuje šta se može graditi:
/// - `.fixed(type)` → samo taj specifični fixed building (ako nije već izgrađen)
/// - `.resource(slotIndex)` → resource buildings (DATA_BANK/FOUNDRY/TECH_LAB/POWER_GRID)
///    sa tačnim slot index-om koji odgovara tapnutom tile-u
struct BuildSheet: View {
    let cityId: String
    let hasQueue: Bool
    let tappedSlot: TappedSlot
    /// Building types koji već postoje u gradu (za filtriranje fixed buildings).
    let existingTypes: Set<BuildingType>

    @Environment(GameState.self) private var gameState
    @Environment(\.dismiss) private var dismiss

    /// Zgrade koje se mogu izgraditi na ovom slotu.
    private var buildableTypes: [BuildingType] {
        switch tappedSlot {
        case .fixed(let type):
            // Ovaj tile je namenjen za tačno jednu fixed zgradu
            return existingTypes.contains(type) ? [] : [type]
        case .resource:
            // Resource slot — ponudi sve 4 resource tipa
            return [.DATA_BANK, .FOUNDRY, .TECH_LAB, .POWER_GRID]
        }
    }

    /// Slot index za API poziv (samo za resource buildings).
    private var slotIndex: Int? {
        switch tappedSlot {
        case .resource(let idx): idx
        case .fixed: nil
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if buildableTypes.isEmpty {
                    ContentUnavailableView(
                        "Already Built",
                        systemImage: "checkmark.seal.fill",
                        description: Text("This building has already been constructed.")
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

    /// Računa cost za level 1 nove zgrade iz game-constants.json
    private func costPreview(for type: BuildingType) -> BuildCostPreview? {
        guard let gd = gameState.gameConstants.gameData else { return nil }
        let key = type.rawValue.lowercased()

        // Probaj resource buildings pa fixed buildings
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
    let slotIndex: Int?

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
