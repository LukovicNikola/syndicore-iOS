import SwiftUI

/// Sheet koji se prikazuje kad igrač tapne na HQ tile.
/// Prikazuje HQ info + Crystal Implosion sekciju kad je HQ na max level-u.
struct HQInfoSheet: View {
    let city: City?
    @Environment(GameState.self) private var gameState
    @Environment(\.dismiss) private var dismiss

    @State private var showImplodeConfirm = false
    @State private var isImploding = false
    @State private var implodeError: String?
    @State private var isLoadingMovements = false

    private var hqBuilding: BuildingInfo? {
        city?.buildings?.first { $0.type == .HQ }
    }

    private var currentRing: Ring? {
        city?.tile?.ring
    }

    /// Implosion config iz game-constants.json
    private var implosionConfig: ImplosionConfigData? {
        gameState.gameConstants.gameData?.implosion
    }

    /// Crystal bonus podatak za trenutni ring
    private var crystalBonus: CrystalBonusData? {
        guard let ring = currentRing else { return nil }
        return gameState.gameConstants.gameData?.crystals?[ring.rawValue]
    }

    /// Sledeći ring posle implosion-a
    private var nextRingName: String? {
        guard let ring = currentRing else { return nil }
        return implosionConfig?.nextRing[ring.rawValue]
    }

    /// Da li je implosion uopšte moguć (HQ max + nije NEXUS)
    private var canShowImplosion: Bool {
        guard let hq = hqBuilding,
              let config = implosionConfig,
              let ring = currentRing else { return false }
        return hq.currentLevel >= config.requiredHqLevel && ring != .nexus
    }

    /// Da li postoje aktivni movements koji blokiraju implosion
    private var hasActiveMovements: Bool {
        !gameState.activeMovements.isEmpty
    }

    /// Da li postoji aktivna construction queue
    private var hasActiveQueue: Bool {
        city?.constructionQueue != nil
    }

    /// Da li igrač ima bar jednog SETTLER-a u gradu
    private var hasSettler: Bool {
        city?.troops?.contains { $0.unitType == .ARCHITECT && $0.count >= 1 } ?? false
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
                            if let ring = tile.ring {
                                LabeledContent("Ring", value: ring.rawValue.capitalized)
                            }
                            if let terrain = tile.terrain {
                                LabeledContent("Terrain", value: terrain.rawValue.displayName)
                            }
                        }
                    }
                }

                if canShowImplosion {
                    implosionSection
                }
            }
            .navigationTitle("HQ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .confirmationDialog(
                "Crystal Implosion",
                isPresented: $showImplodeConfirm,
                titleVisibility: .visible
            ) {
                Button("Implode City", role: .destructive) {
                    Task { await performImplode() }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                if let nextRing = nextRingName {
                    Text("This will DESTROY your city and all buildings. You will collect a \(currentRing?.rawValue.capitalized ?? "") crystal and start fresh in the \(nextRing.capitalized) ring with HQ level 1. This cannot be undone.")
                }
            }
            .task {
                // Refresh movements kad se sheet otvori da imamo svež podatak
                isLoadingMovements = true
                await gameState.refreshMovements()
                isLoadingMovements = false
            }
        }
    }

    // MARK: - Implosion Section

    @ViewBuilder
    private var implosionSection: some View {
        Section {
            // Opis
            VStack(alignment: .leading, spacing: 8) {
                Label("Crystal Implosion", systemImage: "bolt.circle.fill")
                    .font(.subheadline.bold())
                    .foregroundStyle(.purple)

                Text("Destroy your city, collect a crystal from the \(currentRing?.rawValue.capitalized ?? "") ring, and relocate to the \(nextRingName?.capitalized ?? "next") ring.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Crystal bonus preview
            if let bonus = crystalBonus {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Crystal Bonus")
                        .font(.caption.bold())
                    HStack(spacing: 12) {
                        if bonus.productionBonus > 0 {
                            Label("+\(Int(bonus.productionBonus * 100))% Production", systemImage: "chart.line.uptrend.xyaxis")
                                .font(.caption2)
                        }
                        if bonus.atkBonus > 0 {
                            Label("+\(Int(bonus.atkBonus * 100))% ATK", systemImage: "burst.fill")
                                .font(.caption2)
                        }
                        if bonus.defBonus > 0 {
                            Label("+\(Int(bonus.defBonus * 100))% DEF", systemImage: "shield.fill")
                                .font(.caption2)
                        }
                    }
                    .foregroundStyle(.purple.opacity(0.8))
                }
            }

            // Blocker warnings
            if isLoadingMovements {
                HStack(spacing: 8) {
                    ProgressView().scaleEffect(0.7)
                    Text("Checking active movements...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else if hasActiveMovements {
                Label("All troop movements must complete before implosion", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            if hasActiveQueue {
                Label("Construction queue must be empty before implosion", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            if !hasSettler {
                Label("Train a Settler at HQ level 20 before implosion", systemImage: "person.badge.plus")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            // Error display
            if let error = implodeError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            // Implode button
            Button(role: .destructive) {
                showImplodeConfirm = true
            } label: {
                HStack {
                    Spacer()
                    if isImploding {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Label("Implode City", systemImage: "bolt.circle.fill")
                            .fontWeight(.bold)
                    }
                    Spacer()
                }
            }
            .disabled(hasActiveMovements || hasActiveQueue || !hasSettler || isImploding || isLoadingMovements)
        } header: {
            Text("Ring Progression")
        } footer: {
            Text("Your city will be destroyed and replaced with lootable ruins for \(implosionConfig?.ruinsDecayDays ?? 14) days.")
        }
    }

    // MARK: - Implode Action

    private func performImplode() async {
        guard let cityId = city?.id else { return }
        isImploding = true
        implodeError = nil

        do {
            let response = try await gameState.api.implode(cityId: cityId)
            await gameState.handleImplodeSuccess(response)
            dismiss()
        } catch let error as APIError {
            switch error {
            case .badRequest(let e):
                switch e.code {
                case .hqNotMaxLevel:      implodeError = "HQ must be at maximum level to implode."
                case .activeMovements:    implodeError = "Cannot implode while troops are in transit."
                case .activeConstruction: implodeError = "Construction queue must be empty."
                case .noSettler:          implodeError = "You need a Settler unit in your city."
                default:                  implodeError = e.error
                }
            case .conflict(let e):
                if e.code == .alreadyNexus {
                    implodeError = "You are already in the Nexus ring — no further progression."
                } else {
                    implodeError = e.error
                }
            default:
                implodeError = error.localizedDescription
            }
        } catch {
            implodeError = error.localizedDescription
        }

        isImploding = false
    }
}
