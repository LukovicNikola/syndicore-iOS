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
        ZStack {
            // MARK: Isometrijska scena
            CitySceneView(
                city: city,
                onTapHQ:        { showHQInfo = true },
                onTapBuilding:  { selectedBuilding = $0 },
                onTapEmptySlot: { buildSlot = SlotSelection(id: $0) }
            )
            .ignoresSafeArea()

            // MARK: HUD overlay
            VStack {
                TopHUD(city: city)
                Spacer()
                BottomHUD(
                    constructionQueue: city?.constructionQueue,
                    onOpenTraining: { showTraining = true }
                )
            }
            .ignoresSafeArea(edges: .bottom)
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
        .task { await gameState.refreshCity() }
    }

    // MARK: - Helpers

    /// Zgrade koje igrač još NIJE izgradio (prikazuje se u BuildSheet).
    private func buildableTypes(city: City) -> [BuildingType] {
        let built = Set((city.buildings ?? []).map { $0.type })
        return [
            .BARRACKS, .MOTOR_POOL, .OPS_CENTER, .WAREHOUSE,
            .WALL, .WATCHTOWER, .RALLY_POINT, .TRADE_POST, .RESEARCH_LAB
        ].filter { !built.contains($0) }
    }
}

// MARK: - Helpers

/// Wrapper da Int bude Identifiable za .sheet(item:).
private struct SlotSelection: Identifiable {
    let id: Int
}
