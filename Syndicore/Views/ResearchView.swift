import SwiftUI

/// Interactive research screen — upgrade branches, view effects, respec.
struct ResearchView: View {
    @Environment(GameState.self) private var gameState

    @State private var researchState: ResearchResponse?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var upgradingBranch: String?
    @State private var showRespecConfirm = false
    @State private var isRespeccing = false

    private var gameData: GameData? { gameState.gameConstants.gameData }
    private var playerFaction: Faction? { gameState.activePlayerWorld?.faction }

    /// All branches from game-constants, sorted: universal first, then faction.
    private var allBranches: [(key: String, data: TechBranchData, isUniversal: Bool)] {
        guard let gd = gameData else { return [] }
        let universal = gd.techTree.universal.map { (key: $0.key, data: $0.value, isUniversal: true) }
        let faction = gd.techTree.faction.map { (key: $0.key, data: $0.value, isUniversal: false) }
        return (universal + faction).sorted { a, b in
            if a.isUniversal != b.isUniversal { return a.isUniversal }
            return a.key < b.key
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading && researchState == nil {
                    ProgressView("Loading research...")
                } else if let state = researchState {
                    researchList(state)
                } else {
                    ContentUnavailableView(
                        "Could not load research",
                        systemImage: "flask",
                        description: Text(errorMessage ?? "Pull to retry.")
                    )
                }
            }
            .navigationTitle("Research")
            .refreshable { await loadResearch() }
            .task { await loadResearch() }
            .confirmationDialog(
                "Reset Research?",
                isPresented: $showRespecConfirm,
                titleVisibility: .visible
            ) {
                Button("Respec (lose \(respecPenaltyPct)% resources)", role: .destructive) {
                    Task { await respec() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("All research points will be refunded. You lose \(respecPenaltyPct)% of invested resources. This cannot be undone.")
            }
        }
    }

    // MARK: - Main List

    private func researchList(_ state: ResearchResponse) -> some View {
        List {
            // Points budget
            Section {
                HStack {
                    Label("Research Points", systemImage: "atom")
                    Spacer()
                    Text("\(state.pointsUsed) / \(state.pointsAvailable + state.pointsUsed)")
                        .font(.headline.monospacedDigit())
                }
                HStack {
                    Text("Available")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(state.pointsAvailable)")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.green)
                }
            }

            // Branches
            ForEach(allBranches, id: \.key) { item in
                let currentLevel = state.researchPoints[item.key] ?? 0
                let branch = ResearchBranch(rawValue: item.key)
                let isLocked = !item.isUniversal && branch?.faction != playerFaction

                Section {
                    BranchRow(
                        branchKey: item.key,
                        branchData: item.data,
                        currentLevel: currentLevel,
                        isUniversal: item.isUniversal,
                        isLocked: isLocked,
                        playerFaction: playerFaction,
                        pointsAvailable: state.pointsAvailable,
                        cityResources: gameState.activeCity?.resources,
                        costMultiplier: gameData?.buildingFormulas.costMultiplier ?? 1.5,
                        isUpgrading: upgradingBranch == item.key,
                        onUpgrade: {
                            Task { await upgrade(branch: item.key) }
                        }
                    )
                }
            }

            // Respec
            Section {
                Button(role: .destructive) {
                    showRespecConfirm = true
                } label: {
                    HStack {
                        Label("Respec All Research", systemImage: "arrow.counterclockwise")
                        Spacer()
                        if isRespeccing {
                            ProgressView()
                        }
                    }
                }
                .disabled(isRespeccing || (researchState?.pointsUsed ?? 0) == 0)
            } footer: {
                Text("Refunds all research points. You lose \(respecPenaltyPct)% of resources spent.")
            }
        }
    }

    // MARK: - Actions

    private func loadResearch() async {
        guard let worldId = gameState.activePlayerWorld?.worldId ?? gameState.activeWorld?.id else { return }
        isLoading = true
        errorMessage = nil
        do {
            researchState = try await gameState.api.research(worldId: worldId)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func upgrade(branch: String) async {
        guard let worldId = gameState.activePlayerWorld?.worldId ?? gameState.activeWorld?.id,
              let rb = ResearchBranch(rawValue: branch) else { return }
        upgradingBranch = branch
        errorMessage = nil
        do {
            let response = try await gameState.api.upgradeResearch(worldId: worldId, branch: rb)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            // Update local state
            researchState?.researchPoints[branch] = response.result.newLevel
            researchState?.pointsAvailable = response.result.pointsRemaining
            researchState?.pointsUsed += response.result.pointsUsed
            // Refresh city (resources deducted)
            await gameState.refreshCity()
        } catch let error as APIError {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            switch error {
            case .badRequest(let e):
                switch e.code {
                case .insufficientPoints:
                    errorMessage = "Not enough research points."
                case .researchLabRequired:
                    errorMessage = "Build a Research Lab first."
                default:
                    errorMessage = e.error
                }
            case .conflict(let e):
                switch e.code {
                case .insufficientResources:
                    errorMessage = "Not enough resources."
                    await gameState.refreshCity()
                case .branchAtMaxLevel:
                    errorMessage = "Branch already at max level."
                    await loadResearch()
                case .factionBranchMismatch:
                    errorMessage = "This branch belongs to another faction."
                default:
                    errorMessage = e.error
                }
            default:
                errorMessage = error.localizedDescription
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        upgradingBranch = nil
    }

    private func respec() async {
        guard let worldId = gameState.activePlayerWorld?.worldId ?? gameState.activeWorld?.id else { return }
        isRespeccing = true
        do {
            let _ = try await gameState.api.respecResearch(worldId: worldId)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            await loadResearch()
            await gameState.refreshCity()
        } catch let error as APIError {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
        isRespeccing = false
    }

    private var respecPenaltyPct: Int {
        Int((gameData?.respec.resourceLossPct ?? 0.10) * 100)
    }
}

// MARK: - BranchRow

private struct BranchRow: View {
    let branchKey: String
    let branchData: TechBranchData
    let currentLevel: Int
    let isUniversal: Bool
    let isLocked: Bool
    let playerFaction: Faction?
    let pointsAvailable: Int
    let cityResources: Resources?
    let costMultiplier: Double
    let isUpgrading: Bool
    let onUpgrade: () -> Void

    private var isMaxLevel: Bool { currentLevel >= branchData.maxLevel }
    private var nextLevel: Int { currentLevel + 1 }

    /// Point cost for the next level (0-indexed in pointCosts array).
    private var nextPointCost: Int {
        guard currentLevel < branchData.pointCosts.count else { return 0 }
        return branchData.pointCosts[currentLevel]
    }

    /// Resource cost for next level: baseCost * costMultiplier^(currentLevel).
    private var nextResourceCost: [String: Int] {
        branchData.baseCost.mapValues { base in
            Int(Double(base) * pow(costMultiplier, Double(currentLevel)))
        }
    }

    private var canAffordPoints: Bool { pointsAvailable >= nextPointCost }

    private var canAffordResources: Bool {
        guard let res = cityResources else { return false }
        let credits = nextResourceCost["credits"] ?? 0
        let alloys = nextResourceCost["alloys"] ?? 0
        let tech = nextResourceCost["tech"] ?? 0
        return Int(res.credits) >= credits && Int(res.alloys) >= alloys && Int(res.tech) >= tech
    }

    private var canUpgrade: Bool {
        !isLocked && !isMaxLevel && canAffordPoints && canAffordResources && !isUpgrading
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Text(branchKey.displayName)
                    .font(.headline)
                Spacer()
                if isLocked {
                    Label("Locked", systemImage: "lock.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                } else if let faction = branchData.faction {
                    Text(faction)
                        .font(.caption)
                        .foregroundStyle(.orange)
                } else {
                    Text("Universal")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Level progress
            HStack {
                Text("Level \(currentLevel) / \(branchData.maxLevel)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                if isMaxLevel {
                    Text("MAX")
                        .font(.caption.bold())
                        .foregroundStyle(.green)
                }
            }

            // Level pips
            HStack(spacing: 3) {
                ForEach(0..<branchData.maxLevel, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(i < currentLevel ? Color.cyan : Color(.systemGray5))
                        .frame(height: 6)
                }
            }

            // Current effect
            if currentLevel > 0, currentLevel - 1 < branchData.effects.count {
                effectRow(branchData.effects[currentLevel - 1], label: "Current")
            }

            // Next level preview + upgrade
            if !isMaxLevel && !isLocked {
                Divider()

                // Next effect preview
                if currentLevel < branchData.effects.count {
                    effectRow(branchData.effects[currentLevel], label: "Next (Lv\(nextLevel))")
                }

                // Cost
                HStack(spacing: 12) {
                    Label("\(nextPointCost)p", systemImage: "atom")
                        .font(.caption.monospacedDigit())
                        .foregroundColor(canAffordPoints ? .primary : .red)

                    if let credits = nextResourceCost["credits"], credits > 0 {
                        Text("\(credits) CRD")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(Int(cityResources?.credits ?? 0) >= credits ? .yellow : .red)
                    }
                    if let alloys = nextResourceCost["alloys"], alloys > 0 {
                        Text("\(alloys) ALY")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(Int(cityResources?.alloys ?? 0) >= alloys ? .cyan : .red)
                    }
                    if let tech = nextResourceCost["tech"], tech > 0 {
                        Text("\(tech) TCH")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(Int(cityResources?.tech ?? 0) >= tech ? .teal : .red)
                    }
                }

                // Upgrade button
                Button {
                    onUpgrade()
                } label: {
                    HStack {
                        if isUpgrading {
                            ProgressView()
                                .controlSize(.small)
                        }
                        Text("Upgrade to Lv\(nextLevel)")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.cyan)
                .disabled(!canUpgrade)
            }

            // Locked message
            if isLocked, let faction = ResearchBranch(rawValue: branchKey)?.faction {
                Text("Requires \(faction.rawValue.capitalized) faction")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Capstone
            if let lastEffect = branchData.effects.last,
               case .string(let capstone) = lastEffect["capstone"] {
                HStack {
                    Image(systemName: "star.fill")
                        .foregroundStyle(.yellow)
                        .font(.caption)
                    Text(capstone.replacingOccurrences(of: "_", with: " "))
                        .font(.caption.bold())
                        .foregroundStyle(.yellow)
                }
            }
        }
        .padding(.vertical, 4)
        .opacity(isLocked ? 0.5 : 1.0)
    }

    @ViewBuilder
    private func effectRow(_ effect: [String: AnyCodableValue], label: String) -> some View {
        let descriptions = effect.compactMap { key, value -> String? in
            guard key != "capstone" else { return nil }
            switch value {
            case .double(let v): return "\(key.displayName): +\(Int(v * 100))%"
            case .int(let v): return "\(key.displayName): +\(v)"
            case .string(let v): return "\(key.displayName): \(v.displayName)"
            default: return nil
            }
        }.sorted()

        if !descriptions.isEmpty {
            HStack {
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(width: 60, alignment: .leading)
                Text(descriptions.joined(separator: ", "))
                    .font(.caption)
                    .foregroundStyle(.green)
            }
        }
    }
}
