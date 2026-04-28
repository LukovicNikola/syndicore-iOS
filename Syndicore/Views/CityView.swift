import SwiftUI

struct CityView: View {
    @Environment(GameState.self) private var gameState

    // Sheet state
    @State private var selectedBuilding: BuildingInfo?
    @State private var tappedSlotIndex: Int?
    @State private var showHQInfo    = false
    @State private var showTraining  = false
    @State private var showCrystals  = false

    private var city: City? { gameState.activeCity }

    var body: some View {
        @Bindable var gameState = gameState
        ZStack {
            // MARK: Isometrijska scena
            CitySceneView(
                city: city,
                onTapHQ:        { showHQInfo = true },
                onTapBuilding:  { selectedBuilding = $0 },
                onTapEmptySlot: { tappedSlotIndex = $0 },
                onConstructionComplete: {
                    Task { await gameState.refreshCity() }
                }
            )
            .ignoresSafeArea()

            // MARK: HUD overlay
            VStack {
                CyberpunkResourceBar(items: ResourceItem.from(city?.resources, premium: gameState.premium))
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
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
        .overlay(alignment: .topTrailing) {
            CyberpunkSideMenu(actions: sideMenuActions)
                .padding(.trailing, 12)
                .padding(.top, 60)
        }
        .overlay(alignment: .topLeading) {
            CyberpunkBuildQueue(
                constructionQueue: city?.constructionQueue,
                trainingJobs: gameState.activeTrainingJobs
            )
            .padding(.leading, 12)
            .padding(.top, 100)
        }
        // Sheets
        .sheet(item: $selectedBuilding) { building in
            if let cityId = city?.id {
                BuildingDetailSheet(building: building, cityId: cityId)
                    .presentationDetents([.medium, .large])
            }
        }
        .sheet(isPresented: Binding(
            get: { tappedSlotIndex != nil },
            set: { if !$0 { tappedSlotIndex = nil } }
        )) {
            if let city, let slotIdx = tappedSlotIndex {
                BuildSheet(
                    cityId: city.id,
                    hasQueue: city.constructionQueue != nil,
                    slotIndex: slotIdx,
                    existingTypes: Set((city.buildings ?? []).map { $0.type })
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
        .sheet(isPresented: $showCrystals) {
            CrystalSheet()
                .presentationDetents([.medium])
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

    private var sideMenuActions: [SideMenuAction] {
        [
            SideMenuAction(id: "settings", assetName: "ui_settings_v1", accentColor: Color(red: 0.0, green: 0.9, blue: 1.0), badgeCount: nil) {
                // TODO: open Settings view
            },
            SideMenuAction(id: "email", assetName: "ui_email_v1", accentColor: Color(red: 0.0, green: 0.9, blue: 1.0), badgeCount: gameState.unreadEmailCount) {
                // TODO: open Mail view
            },
            SideMenuAction(id: "notifications", assetName: "ui_notifications_v1", accentColor: Color(red: 1.0, green: 0.3, blue: 0.3), badgeCount: gameState.unreadNotificationCount) {
                // TODO: open Notifications view
            },
            SideMenuAction(id: "shop", assetName: "ui_shop_v1", accentColor: Color(red: 1.0, green: 0.3, blue: 0.9), badgeCount: nil) {
                // TODO: open Shop view
            },
        ]
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
