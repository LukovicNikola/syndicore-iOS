import SwiftUI

/// Sheet za pregled i upgrade postojeće zgrade (tapom na njen tile).
struct BuildingDetailSheet: View {
    let building: BuildingInfo
    let cityId: String

    @Environment(GameState.self) private var gameState
    @Environment(\.dismiss) private var dismiss

    @State private var cost: BuildCostResponse?
    @State private var isLoadingCost = true
    @State private var isUpgrading   = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                Section("Building") {
                    LabeledContent("Type", value: building.type.rawValue.displayName)
                    LabeledContent("Level", value: "\(building.currentLevel)")
                    if building.isUpgrading, let endsAt = building.endsAt {
                        HStack {
                            Text("Upgrading to Lv \(building.targetLevel ?? building.currentLevel + 1)")
                                .foregroundStyle(.orange)
                                .font(.subheadline)
                            Spacer()
                            CountdownLabel(endsAt: endsAt)
                        }
                    }
                }

                if building.isUpgrading {
                    // Zgrada već u upgrade-u — ne prikazuj cost
                } else if isLoadingCost {
                    Section("Upgrade Cost") { ProgressView() }
                } else if let cost {
                    Section("Upgrade to Lv \(cost.targetLevel)") {
                        LabeledContent("Credits", value: "\(Int(cost.cost.credits))")
                        LabeledContent("Alloys",  value: "\(Int(cost.cost.alloys))")
                        LabeledContent("Tech",    value: "\(Int(cost.cost.tech))")
                        LabeledContent("Time",    value: "\(Int(cost.durationMinutes)) min")
                    }

                    Section {
                        Button {
                            Task { await upgrade() }
                        } label: {
                            if isUpgrading {
                                ProgressView().frame(maxWidth: .infinity)
                            } else {
                                Text("Upgrade").frame(maxWidth: .infinity)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isUpgrading)
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
            .navigationTitle("Upgrade")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .task { await loadCost() }
        }
    }

    // MARK: - Actions

    private func loadCost() async {
        guard !building.isUpgrading else {
            isLoadingCost = false
            return
        }
        isLoadingCost = true
        errorMessage  = nil
        do {
            cost = try await gameState.api.buildCost(cityId: cityId, buildingId: building.id)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoadingCost = false
    }

    private func upgrade() async {
        isUpgrading  = true
        errorMessage = nil
        do {
            _ = try await gameState.api.buildUpgrade(cityId: cityId, buildingId: building.id)
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
        isUpgrading = false
    }
}
