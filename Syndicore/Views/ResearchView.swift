import SwiftUI

struct ResearchView: View {
    @Environment(GameState.self) private var gameState

    @State private var talentState: TalentStateResponse?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var upgradingKey: String?
    @State private var showRespecConfirm = false
    @State private var isRespeccing = false
    @State private var selectedTree: TalentTree = .STANDARD

    private var worldId: String? {
        gameState.activePlayerWorld?.worldId ?? gameState.activeWorld?.id
    }

    private var gameData: GameData? { gameState.gameConstants.gameData }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading && talentState == nil {
                    ProgressView("Loading talents...")
                } else if let state = talentState {
                    talentList(state)
                } else {
                    ContentUnavailableView(
                        "Could not load talents",
                        systemImage: "flask",
                        description: Text(errorMessage ?? "Pull to retry.")
                    )
                }
            }
            .navigationTitle("Talents")
            .refreshable { await loadTalents() }
            .task { await loadTalents() }
            .confirmationDialog("Reset All Talents?", isPresented: $showRespecConfirm, titleVisibility: .visible) {
                Button("Respec (100% RP refund)", role: .destructive) {
                    Task { await respec() }
                }
            } message: {
                Text("All talent levels will be cleared. Your RP is fully refunded. Faction choice is NOT reset. 7-day cooldown applies.")
            }
        }
    }

    // MARK: - Main List

    private func talentList(_ state: TalentStateResponse) -> some View {
        List {
            rpPoolSection(state.pool)

            Picker("Tree", selection: $selectedTree) {
                Text("Standard").tag(TalentTree.STANDARD)
                Text("Faction").tag(TalentTree.FACTION)
            }
            .pickerStyle(.segmented)
            .listRowBackground(Color.clear)

            if selectedTree == .STANDARD {
                standardTreeSections(state.standard, pool: state.pool)
            } else {
                factionTreeSection(state.faction, pool: state.pool)
            }

            respecSection(state.pool)
        }
    }

    // MARK: - RP Pool

    private func rpPoolSection(_ pool: TalentPoolInfo) -> some View {
        Section {
            HStack {
                Label("Research Points", systemImage: "atom")
                Spacer()
                Text("\(Int(pool.researchPoints))")
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(.cyan)
                Text("(+\(Int(pool.rpPerHour))/hr)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            LabeledContent("Research Lab", value: "Lv \(pool.researchLabLevel)")

            if let lastRespec = pool.lastTalentRespec {
                let cooldownEnd = lastRespec.addingTimeInterval(Double(pool.respecCooldownDays) * 86400)
                if cooldownEnd > Date() {
                    HStack {
                        Image(systemName: "clock.fill")
                            .foregroundStyle(.orange)
                        Text("Respec available ")
                            .font(.caption)
                        CountdownLabel(endsAt: cooldownEnd)
                            .font(.caption.monospacedDigit())
                    }
                }
            }
        }
    }

    // MARK: - Standard Tree

    private func standardTreeSections(_ standard: [String: [TalentNode]], pool: TalentPoolInfo) -> some View {
        let branches = ["LOGISTICS", "SIEGE_ENGINEERING", "MOBILIZATION"]
        return ForEach(branches, id: \.self) { branchKey in
            if let nodes = standard[branchKey] {
                Section(branchKey.displayName) {
                    ForEach(nodes) { node in
                        TalentNodeRow(
                            node: node,
                            cost: standardCost(forLevel: node.level),
                            canAfford: pool.researchPoints >= Double(standardCost(forLevel: node.level)),
                            isUpgrading: upgradingKey == node.key,
                            onUpgrade: {
                                Task { await upgrade(tree: .STANDARD, scope: branchKey, nodeKey: node.key) }
                            }
                        )
                    }
                }
            }
        }
    }

    private func standardCost(forLevel currentLevel: Int) -> Int {
        let costs = gameData?.talentTree?.config?.standardCostPerLevel ?? [50, 100, 150, 200, 250]
        guard currentLevel < costs.count else { return 0 }
        return costs[currentLevel]
    }

    // MARK: - Faction Tree

    @ViewBuilder
    private func factionTreeSection(_ faction: FactionTalentInfo, pool: TalentPoolInfo) -> some View {
        if !faction.available || faction.chosen == nil {
            Section {
                ContentUnavailableView(
                    "Faction Not Chosen",
                    systemImage: "lock.fill",
                    description: Text("Build a Research Lab to choose your faction and unlock faction talents.")
                )
            }
        } else if let units = faction.units, let chosen = faction.chosen {
            ForEach(units.keys.sorted(), id: \.self) { unitKey in
                if let nodes = units[unitKey] {
                    let scope = "\(chosen):\(unitKey)"
                    Section("\(unitKey.displayName) Talents") {
                        ForEach(nodes) { node in
                            let cost = gameData?.talentTree?.config?.factionCost ?? 180
                            TalentNodeRow(
                                node: node,
                                cost: cost,
                                canAfford: pool.researchPoints >= Double(cost),
                                isUpgrading: upgradingKey == node.key,
                                onUpgrade: {
                                    Task { await upgrade(tree: .FACTION, scope: scope, nodeKey: node.key) }
                                }
                            )
                        }
                    }
                }
            }
        }
    }

    // MARK: - Respec

    private func respecSection(_ pool: TalentPoolInfo) -> some View {
        Section {
            Button(role: .destructive) {
                showRespecConfirm = true
            } label: {
                HStack {
                    Label("Respec All Talents", systemImage: "arrow.counterclockwise")
                    Spacer()
                    if isRespeccing { ProgressView() }
                }
            }
            .disabled(isRespeccing || respecOnCooldown(pool))
        } footer: {
            Text("Refunds 100% of spent RP. 7-day cooldown. Faction choice is not reset.")
        }
    }

    private func respecOnCooldown(_ pool: TalentPoolInfo) -> Bool {
        guard let last = pool.lastTalentRespec else { return false }
        return last.addingTimeInterval(Double(pool.respecCooldownDays) * 86400) > Date()
    }

    // MARK: - Actions

    private func loadTalents() async {
        guard let wid = worldId else { return }
        isLoading = true
        errorMessage = nil
        do {
            talentState = try await gameState.api.talents(worldId: wid)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func upgrade(tree: TalentTree, scope: String, nodeKey: String) async {
        guard let wid = worldId else { return }
        upgradingKey = nodeKey
        errorMessage = nil
        do {
            let response = try await gameState.api.upgradeTalent(worldId: wid, tree: tree, scope: scope, nodeKey: nodeKey)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            // Update local pool
            talentState?.pool = TalentPoolInfo(
                researchPoints: response.result.pointsRemaining,
                rpPerHour: talentState?.pool.rpPerHour ?? 0,
                researchLabLevel: talentState?.pool.researchLabLevel ?? 0,
                lastTalentRespec: talentState?.pool.lastTalentRespec,
                respecCooldownDays: talentState?.pool.respecCooldownDays ?? 7
            )
            // Re-fetch full state for updated node levels + modifiers
            await loadTalents()
        } catch let error as APIError {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            switch error {
            case .conflict(let e):
                switch e.code {
                case .insufficientResources: errorMessage = "Not enough research points."
                default: errorMessage = e.error
                }
            case .badRequest(let e): errorMessage = e.error
            default: errorMessage = error.localizedDescription
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        upgradingKey = nil
    }

    private func respec() async {
        guard let wid = worldId else { return }
        isRespeccing = true
        do {
            let response = try await gameState.api.respecTalents(worldId: wid)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            gameState.lastCompletionNotice = CompletionNotice(
                kind: .buildingComplete,
                title: "Talents Reset",
                subtitle: "\(response.result.refundedRP) RP refunded"
            )
            await loadTalents()
        } catch {
            errorMessage = error.localizedDescription
        }
        isRespeccing = false
    }
}

// MARK: - Talent Node Row

private struct TalentNodeRow: View {
    let node: TalentNode
    let cost: Int
    let canAfford: Bool
    let isUpgrading: Bool
    let onUpgrade: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    if node.isCapstone {
                        Image(systemName: "star.fill")
                            .foregroundStyle(.yellow)
                            .font(.caption)
                    }
                    Text(node.label)
                        .font(.subheadline)
                        .foregroundStyle(node.isCapstone ? .yellow : .primary)
                }

                if let maxLevel = node.maxLevel {
                    HStack(spacing: 2) {
                        ForEach(0..<maxLevel, id: \.self) { i in
                            RoundedRectangle(cornerRadius: 1)
                                .fill(i < node.level ? Color.cyan : Color(.systemGray5))
                                .frame(width: 16, height: 4)
                        }
                        Text("\(node.level)/\(maxLevel)")
                            .font(.system(size: 10).monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text(node.level > 0 ? "Unlocked" : "\(cost) RP")
                        .font(.caption)
                        .foregroundStyle(node.level > 0 ? .green : (canAfford ? .cyan : .red))
                }
            }

            Spacer()

            if node.isMaxed {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                Button {
                    onUpgrade()
                } label: {
                    if isUpgrading {
                        ProgressView().controlSize(.small)
                    } else {
                        Text("\(cost) RP")
                            .font(.caption.bold())
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.cyan)
                .controlSize(.small)
                .disabled(!canAfford || isUpgrading)
            }
        }
        .padding(.vertical, 2)
    }
}
