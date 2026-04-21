import SwiftUI

struct CityView: View {
    @Environment(GameState.self) private var gameState

    // Sheet state
    @State private var selectedBuilding: BuildingInfo?
    @State private var buildSlot: SlotSelection?
    @State private var showHQInfo    = false
    @State private var showTraining  = false

    private var city: City? { gameState.activeCity }

    var body: some View {
        @Bindable var gameState = gameState
        ZStack {
            // MARK: Isometrijska scena
            CitySceneView(
                city: city,
                onTapHQ:        { showHQInfo = true },
                onTapBuilding:  { selectedBuilding = $0 },
                onTapEmptySlot: { buildSlot = SlotSelection(id: $0) },
                onConstructionComplete: {
                    Task { await gameState.refreshCity() }
                }
            )
            .ignoresSafeArea()

            // MARK: HUD overlay
            VStack {
                TopHUD(city: city)
                if let err = gameState.cityRefreshError {
                    RefreshErrorBanner(message: err) {
                        gameState.cityRefreshError = nil
                        Task { await gameState.refreshCity() }
                    }
                    .task {
                        try? await Task.sleep(for: .seconds(8))
                        if !Task.isCancelled {
                            withAnimation { gameState.cityRefreshError = nil }
                        }
                    }
                }
                BottomHUD(
                    constructionQueue: city?.constructionQueue,
                    trainingJobs: gameState.activeTrainingJobs,
                    onSkipBuild: {
                        Task { await skipBuild() }
                    },
                    onSkipTraining: { job in
                        Task { await skipTraining(job) }
                    }
                )
                Spacer()
            }

            // MARK: Train dugme — donji levi ugao, iznad safe area
            VStack {
                Spacer()
                HStack {
                    Button(action: { showTraining = true }) {
                        Label("Train", systemImage: "person.2.fill")
                            .font(.system(size: 12, weight: .bold))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 9)
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())
                            .foregroundStyle(.white)
                    }
                    Spacer()
                }
                .padding(.leading, 20)
                .padding(.bottom, 90)
            }
        }
        // Sheets
        .sheet(item: $selectedBuilding) { building in
            if let cityId = city?.id {
                BuildingDetailSheet(building: building, cityId: cityId)
                    .presentationDetents([.medium, .large])
            }
        }
        .sheet(item: $buildSlot) { slot in
            if let city {
                BuildSheet(
                    cityId: city.id,
                    hasQueue: city.constructionQueue != nil,
                    usedResourceSlots: Set((city.buildings ?? []).compactMap { $0.slotIndex }),
                    buildableTypes: buildableTypes(city: city)
                )
                .presentationDetents([.medium, .large])
            }
        }
        .sheet(isPresented: $showHQInfo) {
            HQInfoSheet(city: city)
                .presentationDetents([.medium])
        }
        .sheet(isPresented: $showTraining) {
            TrainingSheet()
                .presentationDetents([.medium, .large])
        }
        .task {
            // Initial load + auto-refresh loop dok je view aktivan.
            // SwiftUI .task se automatski cancel-uje na .onDisappear pa nema leak-a.
            await gameState.refreshCity()
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                if Task.isCancelled { return }
                await gameState.refreshCity()
            }
        }
    }

    // MARK: - Skip Actions

    private func skipBuild() async {
        guard let cityId = city?.id else { return }
        do {
            try await gameState.api.skipBuild(cityId: cityId)
            await gameState.refreshCity()
        } catch {
            gameState.cityRefreshError = "Skip failed: \(error)"
        }
    }

    private func skipTraining(_ job: TrainingJob) async {
        guard let cityId = city?.id else { return }
        do {
            try await gameState.api.skipTraining(cityId: cityId, jobId: job.id)
            await gameState.refreshCity()
        } catch {
            gameState.cityRefreshError = "Skip failed: \(error)"
        }
    }

    // MARK: - Helpers

    /// Zgrade koje igrač može da izgradi (prikazuje se u BuildSheet).
    private func buildableTypes(city: City) -> [BuildingType] {
        let buildings = city.buildings ?? []
        let existingTypes = Set(buildings.map { $0.type })

        // Fixed buildings: svaka se može izgraditi samo jednom
        var result: [BuildingType] = [
            .BARRACKS, .MOTOR_POOL, .OPS_CENTER, .WAREHOUSE,
            .WALL, .WATCHTOWER, .RALLY_POINT, .TRADE_POST, .RESEARCH_LAB
        ].filter { !existingTypes.contains($0) }

        // Resource buildings: mogu se graditi u flex slotovima dok ima slobodnih
        let usedResourceSlots = buildings.compactMap { $0.slotIndex }.count
        let totalResourceSlots = 10  // CityScene.resourceSlotPositions.count
        if usedResourceSlots < totalResourceSlots {
            result.append(contentsOf: [.DATA_BANK, .FOUNDRY, .TECH_LAB, .POWER_GRID])
        }

        return result
    }
}

// MARK: - Helpers

/// Wrapper da Int bude Identifiable za .sheet(item:).
private struct SlotSelection: Identifiable {
    let id: Int
}

/// Non-blocking error banner za refresh failure. Korisnik moze da retry-uje ili dismiss-uje.
struct RefreshErrorBanner: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)
            Text(message)
                .font(.caption)
                .lineLimit(2)
                .foregroundStyle(.primary)
            Spacer()
            Button("Retry", action: retry)
                .font(.caption.bold())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}
