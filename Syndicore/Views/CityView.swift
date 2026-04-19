import SwiftUI

struct CityView: View {
    @Environment(GameState.self) private var gameState

    // Sheet state
    @State private var selectedBuilding: BuildingInfo?
    @State private var buildSlot: SlotSelection?
    @State private var showHQInfo    = false
    @State private var showTraining  = false

    /// Increment-uje se kad user tapne recenter dugme — CitySceneView observira i poziva resetCamera().
    @State private var cameraResetCounter: Int = 0

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
                cameraResetCounter: cameraResetCounter
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
                }
                Spacer()
                BottomHUD(
                    constructionQueue: city?.constructionQueue,
                    onOpenTraining: { showTraining = true }
                )
            }
            .ignoresSafeArea(edges: .bottom)

            // MARK: Floating recenter button (gornji desni ugao)
            VStack {
                HStack {
                    Spacer()
                    Button {
                        cameraResetCounter += 1
                    } label: {
                        Image(systemName: "scope")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 40, height: 40)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .padding(.trailing, 16)
                    .padding(.top, 60)  // ispod TopHUD-a
                }
                Spacer()
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
