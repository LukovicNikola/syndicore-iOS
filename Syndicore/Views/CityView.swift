import SwiftUI

struct CityView: View {
    @Environment(GameState.self) private var gameState

    @State private var selectedBuilding: BuildingInfo?
    @State private var buildCost: BuildCostResponse?
    @State private var isFetchingCost = false
    @State private var showTraining = false
    @State private var trainingJobs: [TrainingJob] = []
    @State private var actionError: String?

    private var city: City? { gameState.activeCity }

    var body: some View {
        NavigationStack {
            Group {
                if let city {
                    List {
                        resourceSection(city)
                        constructionSection(city)
                        buildingsSection(city)
                        troopsSection(city)
                        trainingSection
                    }
                    .refreshable { await gameState.refreshCity() }
                } else {
                    ProgressView("Loading city...")
                }
            }
            .navigationTitle(city?.name ?? "City")
            .sheet(item: $selectedBuilding) { building in
                BuildingUpgradeSheet(
                    building: building,
                    cost: buildCost,
                    isLoading: isFetchingCost,
                    error: actionError
                ) {
                    await upgradeBuilding(building)
                }
                .presentationDetents([.medium])
            }
            .sheet(isPresented: $showTraining) {
                TrainingSheet()
                    .presentationDetents([.medium, .large])
            }
            .task { await loadTrainingJobs() }
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private func resourceSection(_ city: City) -> some View {
        if let res = city.resources {
            Section("Resources") {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ResourceCell(name: "Credits", value: res.credits, icon: "creditcard.fill", color: .yellow)
                    ResourceCell(name: "Alloys", value: res.alloys, icon: "gearshape.2.fill", color: .gray)
                    ResourceCell(name: "Tech", value: res.tech, icon: "cpu.fill", color: .cyan)
                    ResourceCell(name: "Energy", value: res.energy ?? 0, icon: "bolt.fill", color: .green)
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }
        }
    }

    @ViewBuilder
    private func constructionSection(_ city: City) -> some View {
        if let queue = city.constructionQueue, let endsAt = queue.endsAt {
            Section("Construction") {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(queue.type.replacingOccurrences(of: "_", with: " ").capitalized)
                            .font(.subheadline.bold())
                        Text("Upgrading...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    CountdownLabel(endsAt: endsAt)
                }
            }
        }
    }

    @ViewBuilder
    private func buildingsSection(_ city: City) -> some View {
        if let buildings = city.buildings, !buildings.isEmpty {
            Section("Buildings") {
                ForEach(buildings.sorted(by: { $0.type.rawValue < $1.type.rawValue })) { building in
                    Button {
                        Task { await selectBuilding(building) }
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(building.type.rawValue.replacingOccurrences(of: "_", with: " ").capitalized)
                                    .font(.subheadline)
                                if building.isUpgrading {
                                    Text("Upgrading...")
                                        .font(.caption)
                                        .foregroundStyle(.orange)
                                }
                            }
                            Spacer()
                            Text("Lv \(building.level)")
                                .font(.caption.bold().monospacedDigit())
                                .foregroundStyle(.secondary)
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .tint(.primary)
                    .disabled(building.isUpgrading)
                }
            }
        }
    }

    @ViewBuilder
    private func troopsSection(_ city: City) -> some View {
        if let troops = city.troops, !troops.isEmpty {
            Section("Troops") {
                ForEach(troops, id: \.unitType) { troop in
                    HStack {
                        Text(troop.unitType.replacingOccurrences(of: "_", with: " ").capitalized)
                            .font(.subheadline)
                        Spacer()
                        Text("×\(troop.count)")
                            .font(.subheadline.bold().monospacedDigit())
                    }
                }
                Button("Train Units") { showTraining = true }
            }
        } else {
            Section("Troops") {
                Text("No troops stationed")
                    .foregroundStyle(.secondary)
                Button("Train Units") { showTraining = true }
            }
        }
    }

    @ViewBuilder
    private var trainingSection: some View {
        if !trainingJobs.isEmpty {
            Section("Training Queue") {
                ForEach(trainingJobs) { job in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(job.unitType.replacingOccurrences(of: "_", with: " ").capitalized)
                                .font(.subheadline)
                            Text("×\(job.count)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        CountdownLabel(endsAt: job.endsAt)
                    }
                }
            }
        }
    }

    // MARK: - Actions

    private func selectBuilding(_ building: BuildingInfo) async {
        buildCost = nil
        actionError = nil
        isFetchingCost = true
        selectedBuilding = building

        guard let cityId = city?.id else { return }
        do {
            buildCost = try await gameState.api.buildCost(cityId: cityId, buildingId: building.id)
        } catch {
            actionError = error.localizedDescription
        }
        isFetchingCost = false
    }

    private func upgradeBuilding(_ building: BuildingInfo) async {
        guard let cityId = city?.id else { return }
        do {
            _ = try await gameState.api.buildUpgrade(cityId: cityId, buildingId: building.id)
            selectedBuilding = nil
            await gameState.refreshCity()
        } catch {
            actionError = error.localizedDescription
        }
    }

    private func loadTrainingJobs() async {
        guard let cityId = city?.id else { return }
        trainingJobs = (try? await gameState.api.trainingJobs(cityId: cityId)) ?? []
    }
}

// MARK: - Resource Cell

private struct ResourceCell: View {
    let name: String
    let value: Double
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 1) {
                Text(name)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(Int(value))")
                    .font(.subheadline.bold().monospacedDigit())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Countdown Label

struct CountdownLabel: View {
    let endsAt: String

    @State private var remaining: TimeInterval = 0
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var endDate: Date? {
        ISO8601DateFormatter().date(from: endsAt)
    }

    var body: some View {
        Text(formatted)
            .font(.caption.bold().monospacedDigit())
            .foregroundStyle(remaining > 0 ? .orange : .green)
            .onAppear { updateRemaining() }
            .onReceive(timer) { _ in updateRemaining() }
    }

    private var formatted: String {
        if remaining <= 0 { return "Done" }
        let h = Int(remaining) / 3600
        let m = (Int(remaining) % 3600) / 60
        let s = Int(remaining) % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%02d:%02d", m, s)
    }

    private func updateRemaining() {
        guard let end = endDate else { remaining = 0; return }
        remaining = max(0, end.timeIntervalSinceNow)
    }
}

// MARK: - Building Upgrade Sheet

private struct BuildingUpgradeSheet: View {
    let building: BuildingInfo
    let cost: BuildCostResponse?
    let isLoading: Bool
    let error: String?
    let onUpgrade: () async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var isUpgrading = false

    var body: some View {
        NavigationStack {
            List {
                Section("Building") {
                    LabeledContent("Type", value: building.type.rawValue.replacingOccurrences(of: "_", with: " ").capitalized)
                    LabeledContent("Current Level", value: "\(building.level)")
                }

                if isLoading {
                    Section("Upgrade Cost") {
                        ProgressView()
                    }
                } else if let cost {
                    Section("Upgrade to Lv \(cost.targetLevel)") {
                        LabeledContent("Credits", value: "\(Int(cost.cost.credits))")
                        LabeledContent("Alloys", value: "\(Int(cost.cost.alloys))")
                        LabeledContent("Tech", value: "\(Int(cost.cost.tech))")
                        LabeledContent("Time", value: "\(Int(cost.durationMinutes)) min")
                    }

                    Section {
                        Button {
                            Task {
                                isUpgrading = true
                                await onUpgrade()
                                isUpgrading = false
                            }
                        } label: {
                            if isUpgrading {
                                ProgressView().frame(maxWidth: .infinity)
                            } else {
                                Text("Upgrade")
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isUpgrading)
                    }
                }

                if let error {
                    Section {
                        Text(error)
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
        }
    }
}
