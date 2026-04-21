import SwiftUI

/// ArmyView — 3 tab-a: Troops (trupe u gradu), Movements (aktivna kretanja),
/// Reports (battle izveštaji).
///
/// **Gameplay:** primarni military screen. Igrač ovde proverava "koje trupe imam,
/// šta mi je u pokretu, šta sam nedavno napadnuo". Movements tab ima DEV skip
/// dugme za instant-complete tokom testinga.
struct ArmyView: View {
    @Environment(GameState.self) private var gameState
    @State private var selectedTab: Tab = .troops

    enum Tab: String, CaseIterable, Identifiable {
        case troops    = "Troops"
        case movements = "Movements"
        case reports   = "Reports"
        var id: String { rawValue }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Tab", selection: $selectedTab) {
                    ForEach(Tab.allCases) { t in
                        Text(t.rawValue).tag(t)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top, 8)

                switch selectedTab {
                case .troops:    TroopsTab()
                case .movements: MovementsTab()
                case .reports:   ReportsTab()
                }
            }
            .navigationTitle("Army")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Troops Tab

private struct TroopsTab: View {
    @Environment(GameState.self) private var gameState

    private var troops: [TroopInfo] {
        gameState.activeCity?.troops ?? []
    }

    private var totalCount: Int {
        troops.reduce(0) { $0 + $1.count }
    }

    var body: some View {
        Group {
            if troops.isEmpty {
                ContentUnavailableView(
                    "No Troops",
                    systemImage: "person.slash",
                    description: Text("Train troops in Barracks, Motor Pool, or Ops Center.")
                )
            } else {
                List {
                    Section {
                        ForEach(troops, id: \.unitType) { troop in
                            HStack {
                                Image(systemName: unitIcon(troop.unitType))
                                    .foregroundStyle(unitColor(troop.unitType))
                                    .frame(width: 24)
                                Text(troop.unitType.rawValue.capitalized)
                                    .font(.subheadline)
                                Spacer()
                                Text("\(troop.count)")
                                    .font(.subheadline.bold().monospacedDigit())
                                    .foregroundStyle(.cyan)
                            }
                        }
                    } header: {
                        Text("Garrison · \(totalCount) units")
                    }
                }
            }
        }
        .refreshable { await gameState.refreshCity() }
    }
}

// MARK: - Movements Tab

private struct MovementsTab: View {
    @Environment(GameState.self) private var gameState
    @State private var skippingId: String?
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if gameState.activeMovements.isEmpty {
                ContentUnavailableView(
                    "No Movements",
                    systemImage: "arrow.triangle.swap",
                    description: Text("Send troops from the Map tab.")
                )
            } else {
                List {
                    ForEach(gameState.activeMovements) { movement in
                        MovementRow(
                            movement: movement,
                            isSkipping: skippingId == movement.id,
                            onSkip: { Task { await skipMovement(movement) } },
                            onArrival: { Task { await handleArrival() } }
                        )
                    }

                    // Infinite scroll trigger
                    if gameState.movementsHasMore {
                        HStack {
                            Spacer()
                            ProgressView("Loading more…").font(.caption)
                            Spacer()
                        }
                        .onAppear { Task { await gameState.loadMoreMovements() } }
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }
        }
        .task {
            await gameState.refreshMovements()
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                if Task.isCancelled { return }
                await gameState.refreshMovements()
            }
        }
        .refreshable { await gameState.refreshMovements() }
    }

    private func skipMovement(_ movement: TroopMovement) async {
        guard let worldId = gameState.activePlayerWorld?.worldId ?? gameState.activeWorld?.id else { return }
        skippingId = movement.id
        errorMessage = nil
        do {
            try await gameState.api.skipMovement(worldId: worldId, movementId: movement.id)
            await gameState.refreshMovements()
            await gameState.refreshCity()
        } catch {
            errorMessage = "Skip failed: \(error)"
        }
        skippingId = nil
    }

    /// Poziva se kad movement countdown dostigne 0.
    /// Trigger-uje refresh movements + reports (BE je moglo da napravi novi report
    /// ili da premesti movement u return leg) + haptic feedback.
    private func handleArrival() async {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        await gameState.refreshMovements()
        await gameState.refreshReports()
        await gameState.refreshCity()   // trupe koje se vraćaju ažuriraju garrison
    }
}

private struct MovementRow: View {
    let movement: TroopMovement
    let isSkipping: Bool
    let onSkip: () -> Void
    /// Pozvan kad tajmer dostigne 0 — parent refresh-uje movements + reports.
    var onArrival: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: typeIcon(movement.type))
                    .foregroundStyle(typeColor(movement.type))
                Text(movement.type.rawValue.capitalized)
                    .font(.subheadline.bold())
                    .foregroundStyle(typeColor(movement.type))
                if movement.isReturning {
                    Text("(Returning)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                CountdownLabel(endsAt: movement.arrivesAt, onComplete: onArrival)
                    .font(.caption.monospacedDigit())

                // DEV skip button
                Button(action: onSkip) {
                    if isSkipping {
                        ProgressView().controlSize(.mini).tint(.orange)
                    } else {
                        Text("⚡ DEV")
                            .font(.system(size: 10, weight: .heavy))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.orange, in: Capsule())
                    }
                }
                .disabled(isSkipping)
            }

            HStack(spacing: 4) {
                Text("(\(movement.from.x),\(movement.from.y))")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                Image(systemName: "arrow.right")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                Text("(\(movement.to.x),\(movement.to.y))")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                if !movement.viaGates.isEmpty {
                    Image(systemName: "arrow.triangle.swap")
                        .font(.system(size: 9))
                        .foregroundStyle(.purple)
                    Text("gate")
                        .font(.caption2)
                        .foregroundStyle(.purple)
                }
            }

            let unitsList = movement.units.sorted { $0.key.rawValue < $1.key.rawValue }
            if !unitsList.isEmpty {
                HStack(spacing: 6) {
                    ForEach(unitsList, id: \.key) { unitType, count in
                        Text("\(count)x \(unitType.rawValue.capitalized)")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.15), in: Capsule())
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func typeIcon(_ type: MovementType) -> String {
        switch type {
        case .ATTACK:    "flame.fill"
        case .RAID:      "bolt.fill"
        case .SCOUT:     "eye.fill"
        case .REINFORCE: "shield.fill"
        case .TRANSPORT: "shippingbox.fill"
        case .SETTLE:    "house.fill"
        case .RETURN:    "arrow.uturn.backward"
        }
    }

    private func typeColor(_ type: MovementType) -> Color {
        switch type {
        case .ATTACK:    .red
        case .RAID:      .orange
        case .SCOUT:     .blue
        case .REINFORCE: .green
        case .TRANSPORT: .purple
        case .SETTLE:    .cyan
        case .RETURN:    .secondary
        }
    }
}

// MARK: - Reports Tab

private struct ReportsTab: View {
    @Environment(GameState.self) private var gameState
    @State private var selectedReport: BattleReport?

    var body: some View {
        Group {
            if gameState.activeReports.isEmpty {
                ContentUnavailableView(
                    "No Battle Reports",
                    systemImage: "doc.text.magnifyingglass",
                    description: Text("Reports appear after battles (attacks you launched or received).")
                )
            } else {
                List {
                    ForEach(gameState.activeReports) { report in
                        ReportRow(report: report)
                            .contentShape(Rectangle())
                            .onTapGesture { selectedReport = report }
                    }

                    if gameState.reportsHasMore {
                        HStack {
                            Spacer()
                            ProgressView("Loading more…").font(.caption)
                            Spacer()
                        }
                        .onAppear { Task { await gameState.loadMoreReports() } }
                    }
                }
            }
        }
        .task { await gameState.refreshReports() }
        .refreshable { await gameState.refreshReports() }
        .sheet(item: $selectedReport) { report in
            BattleReportDetailView(report: report)
                .presentationDetents([.large])
        }
    }
}

private struct ReportRow: View {
    let report: BattleReport

    var body: some View {
        HStack {
            Image(systemName: youWon ? "checkmark.shield.fill" : "xmark.shield.fill")
                .foregroundStyle(youWon ? .green : .red)
                .font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                Text(headline)
                    .font(.subheadline.bold())
                    .foregroundStyle(youWon ? .green : .red)
                Text("(\(report.targetX), \(report.targetY)) · ratio \(String(format: "%.2f", report.ratio))")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
                Text(report.occurredAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let stolen = report.resourcesStolen {
                let total = Int(stolen.credits + stolen.alloys + stolen.tech)
                if total > 0 {
                    Text("+\(total)")
                        .font(.caption.bold().monospacedDigit())
                        .foregroundStyle(.yellow)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var headline: String {
        if report.isAttacker {
            return report.attackerWon ? "Attack Successful" : "Attack Failed"
        } else {
            return report.attackerWon ? "Defense Lost" : "Defense Held"
        }
    }

    private var youWon: Bool {
        (report.isAttacker && report.attackerWon)
        || (!report.isAttacker && !report.attackerWon)
    }
}

// MARK: - Battle Report Detail

struct BattleReportDetailView: View {
    let report: BattleReport
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Outcome") {
                    LabeledContent("Result") {
                        Text(report.attackerWon ? "Attacker Won" : "Defender Won")
                            .bold()
                            .foregroundStyle(report.attackerWon ? .red : .green)
                    }
                    LabeledContent("Target", value: "(\(report.targetX), \(report.targetY))")
                    LabeledContent("Total Attack",  value: String(format: "%.0f", report.totalAtk))
                    LabeledContent("Total Defense", value: String(format: "%.0f", report.totalDef))
                    LabeledContent("Ratio",         value: String(format: "%.2f", report.ratio))
                    LabeledContent("When",          value: report.occurredAt.formatted(.dateTime))
                }

                Section("Attacker Army") {
                    ArmySnapshotSection(snapshot: report.attackerUnits)
                }
                Section("Defender Army") {
                    ArmySnapshotSection(snapshot: report.defenderUnits)
                }

                if let stolen = report.resourcesStolen,
                   (stolen.credits + stolen.alloys + stolen.tech) > 0 {
                    Section("Resources Stolen") {
                        LabeledContent("Credits", value: "\(Int(stolen.credits))")
                        LabeledContent("Alloys",  value: "\(Int(stolen.alloys))")
                        LabeledContent("Tech",    value: "\(Int(stolen.tech))")
                    }
                }

                if let damaged = report.buildingsDamaged, !damaged.isEmpty {
                    Section("Buildings Damaged") {
                        ForEach(damaged, id: \.self) { b in
                            Text(b.replacingOccurrences(of: "_", with: " ").capitalized)
                        }
                    }
                }
            }
            .navigationTitle("Battle Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

private struct ArmySnapshotSection: View {
    let snapshot: ArmySnapshot

    private var allUnits: [UnitType] {
        Set(snapshot.before.keys)
            .union(snapshot.after.keys)
            .union(snapshot.lost.keys)
            .sorted { $0.rawValue < $1.rawValue }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Unit").frame(maxWidth: .infinity, alignment: .leading)
                Text("Before").frame(width: 55, alignment: .trailing)
                Text("After").frame(width: 55, alignment: .trailing)
                Text("Lost").frame(width: 55, alignment: .trailing)
            }
            .font(.caption2.bold())
            .foregroundStyle(.secondary)

            ForEach(allUnits, id: \.self) { unit in
                HStack {
                    Text(unit.rawValue.capitalized)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .font(.caption)
                    Text("\(snapshot.before[unit] ?? 0)")
                        .frame(width: 55, alignment: .trailing)
                        .font(.caption.monospacedDigit())
                    Text("\(snapshot.after[unit] ?? 0)")
                        .frame(width: 55, alignment: .trailing)
                        .font(.caption.monospacedDigit())
                    Text("\(snapshot.lost[unit] ?? 0)")
                        .frame(width: 55, alignment: .trailing)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle((snapshot.lost[unit] ?? 0) > 0 ? .red : .secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Unit icons (shared)

private func unitIcon(_ type: UnitType) -> String {
    switch type {
    case .GRUNT:    "person.fill"
    case .ENFORCER: "shield.fill"
    case .SENTINEL: "shield.lefthalf.filled"
    case .STRIKER:  "car.fill"
    case .HAULER:   "shippingbox.fill"
    case .PHANTOM:  "eye.fill"
    case .BUSTER:   "flame.fill"
    case .TITAN:    "crown.fill"
    case .SETTLER:  "flag.fill"
    }
}

private func unitColor(_ type: UnitType) -> Color {
    switch type {
    case .GRUNT:    .secondary
    case .ENFORCER: .blue
    case .SENTINEL: .cyan
    case .STRIKER:  .orange
    case .HAULER:   .brown
    case .PHANTOM:  .purple
    case .BUSTER:   .red
    case .TITAN:    .yellow
    case .SETTLER:  .green
    }
}
