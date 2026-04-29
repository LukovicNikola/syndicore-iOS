import SwiftUI
import SpriteKit

struct MapView: View {
    @Environment(GameState.self) private var gameState

    @State private var scene: MapScene = {
        let s = MapScene()
        s.scaleMode = .resizeFill
        return s
    }()

    @State private var selectedTile: MapTile?
    @State private var isLoading = true
    @State private var viewportCenter = (cx: 0, cy: 0)
    /// Drži referencu na poslednji viewport fetch task — cancel-uje ga pre nego
    /// što startuje novi. Spreciti gomilanje paralelnih API poziva kad user
    /// brzo pan-uje preko više thresholdova zaredom.
    @State private var viewportFetchTask: Task<Void, Never>?

    /// Kad user klikne Attack/Scout/etc u info card-u, ovo se setuje i otvara SendTroopsSheet.
    @State private var sendTroopsTarget: SendTroopsTarget?
    /// Kad user klikne "Rally Attack" na tile-u, otvara CreateRallySheet sa pre-populated coords.
    @State private var rallyTarget: RallyTarget?

    private var worldId: String? {
        gameState.activePlayerWorld?.worldId
    }

    var body: some View {
        @Bindable var gameState = gameState
        ZStack {
            SpriteView(scene: scene)
                .ignoresSafeArea()

            if isLoading {
                ProgressView()
                    .padding(12)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            if let err = gameState.mapFetchError {
                VStack {
                    RefreshErrorBanner(message: err) {
                        gameState.mapFetchError = nil
                        Task { await fetchViewport() }
                    }
                    Spacer()
                }
            }
        }
        .overlay(alignment: .top) {
            CyberpunkResourceBar(items: ResourceItem.from(gameState.activeCity?.resources, premium: gameState.premium))
                .padding(.horizontal, 20)
                .padding(.top, 8)
        }
        .overlay(alignment: .topTrailing) {
            CyberpunkSideMenu(actions: sideMenuActions)
                .padding(.trailing, 12)
                .padding(.top, 60)
        }
        .overlay(alignment: .topLeading) {
            CyberpunkBuildQueue(
                constructionQueue: gameState.activeCity?.constructionQueue,
                trainingJobs: gameState.activeTrainingJobs
            )
            .padding(.leading, 12)
            .padding(.top, 100)
        }
        .overlay(alignment: .bottom) {
            if let tile = selectedTile {
                TileInfoCard(
                    tile: tile,
                    onDismiss: { selectedTile = nil },
                    onAction: { movementTypes in
                        sendTroopsTarget = SendTroopsTarget(
                            x: tile.x,
                            y: tile.y,
                            allowedMovementTypes: movementTypes
                        )
                    },
                    onRallyAttack: {
                        rallyTarget = RallyTarget(x: tile.x, y: tile.y)
                    },
                    homeTile: gameState.activeCity?.tile,
                    implosionConfig: gameState.gameConstants.gameData?.implosion
                )
                .transition(.move(edge: .bottom))
                .padding()
            }
        }
        .sheet(item: $sendTroopsTarget) { target in
            SendTroopsSheet(
                targetX: target.x,
                targetY: target.y,
                allowedMovementTypes: target.allowedMovementTypes
            )
            .presentationDetents([.medium, .large])
        }
        .sheet(item: $rallyTarget) { target in
            CreateRallySheet(prefillTargetX: target.x, prefillTargetY: target.y)
                .presentationDetents([.large])
        }
        .animation(.easeInOut(duration: 0.2), value: selectedTile?.x)
        .onChange(of: gameState.activeMovements.map(\.id)) { _, _ in
            // Re-push movement lines na scene kad se lista menja
            scene.setMovements(gameState.activeMovements)
        }
        .onChange(of: gameState.activePlayerWorld?.worldId) { _, _ in
            // World switch (npr. Crystal Implosion) — clear stale tile cache
            // pre nego što ucita novi viewport.
            scene.reset()
            if let tile = gameState.activeCity?.tile {
                viewportCenter = (cx: tile.x, cy: tile.y)
            }
            Task { await fetchViewport() }
        }
        .task {
            setupCallbacks()
            if let tile = gameState.activeCity?.tile {
                viewportCenter = (cx: tile.x, cy: tile.y)
            }
            await fetchViewport()
            await gameState.refreshMovements()
            scene.setMovements(gameState.activeMovements)

            // Auto-refresh loop: svakih 30s osveži viewport + movements dok je view aktivan
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                if Task.isCancelled { return }
                await fetchViewport()
                await gameState.refreshMovements()
            }
        }
    }

    private func setupCallbacks() {
        // Napomena: SwiftUI struct-ovi se kopiraju — nema pravog retain cycle-a.
        // Ipak, eksplicitno označavamo closure kao @MainActor + koristimo
        // Task sa { @MainActor in ... } wrapper-om radi Swift 6 concurrency
        // strictness-a i da state mutation (selectedTile, viewportCenter) ne klizi
        // u non-main actor izvršenje.
        scene.onTileTapped = { tile in
            Task { @MainActor in
                if selectedTile?.x == tile.x && selectedTile?.y == tile.y {
                    selectedTile = nil
                } else {
                    selectedTile = tile
                }
            }
        }
        scene.onViewportMoved = { cx, cy in
            Task { @MainActor in
                viewportCenter = (cx: cx, cy: cy)
                viewportFetchTask?.cancel()
                viewportFetchTask = Task { @MainActor in
                    await fetchViewport()
                }
            }
        }
    }

    private var sideMenuActions: [SideMenuAction] {
        [
            SideMenuAction(id: "settings", assetName: "ui_settings_v1", accentColor: Color(red: 0.0, green: 0.9, blue: 1.0), badgeCount: nil) {
                gameState.selectedTab = .settings
            },
            SideMenuAction(id: "email", assetName: "ui_email_v1", accentColor: Color(red: 0.0, green: 0.9, blue: 1.0), badgeCount: gameState.unreadEmailCount) {
                gameState.lastCompletionNotice = .comingSoon("Mailbox")
            },
            SideMenuAction(id: "notifications", assetName: "ui_notifications_v1", accentColor: Color(red: 1.0, green: 0.3, blue: 0.3), badgeCount: gameState.unreadNotificationCount) {
                gameState.lastCompletionNotice = .comingSoon("Notifications")
            },
            SideMenuAction(id: "shop", assetName: "ui_shop_v1", accentColor: Color(red: 1.0, green: 0.3, blue: 0.9), badgeCount: nil) {
                gameState.lastCompletionNotice = .comingSoon("Shop")
            },
        ]
    }

    private func fetchViewport() async {
        guard let wid = worldId else { return }
        isLoading = true
        do {
            let response = try await gameState.api.mapViewport(
                worldId: wid,
                cx: viewportCenter.cx,
                cy: viewportCenter.cy,
                radius: 20
            )
            scene.loadTiles(response.tiles, center: viewportCenter)
            gameState.mapFetchError = nil
        } catch {
            // Zadrzi cached tile-ove ali upozori UI — korisnik mora da zna da je fetch otkazao.
            gameState.mapFetchError = error.localizedDescription
        }
        isLoading = false
    }
}

// MARK: - Send Troops Target

/// Wrapper za .sheet(item:) — drzi target coords + allowed movement types.
struct SendTroopsTarget: Identifiable {
    var id: String { "\(x),\(y)" }
    let x: Int
    let y: Int
    let allowedMovementTypes: [MovementType]
}

/// Wrapper za .sheet(item:) — rally attack from map tile.
struct RallyTarget: Identifiable {
    var id: String { "\(x),\(y)" }
    let x: Int
    let y: Int
}

// MARK: - Tile Info Card

private struct TileInfoCard: View {
    let tile: MapTile
    let onDismiss: () -> Void
    let onAction: ([MovementType]) -> Void
    let onRallyAttack: () -> Void
    /// Igracev home city tile — da znamo da li user taphe svoju ili stranu lokaciju.
    let homeTile: TileInfo?
    /// Implosion config za ruins loot multiplier prikaz.
    var implosionConfig: ImplosionConfigData?

    /// Da li je ovaj tile igračev home city? Onda nema Send dugme.
    private var isOwnCity: Bool {
        guard let home = homeTile else { return false }
        return home.x == tile.x && home.y == tile.y
    }

    /// Movement type-ovi koji su validni za tap na ovaj tile.
    /// Pravila (client-side validacija; BE ima final say):
    /// - Enemy city: ATTACK, RAID, SCOUT, REINFORCE, TRANSPORT
    /// - Outpost: ATTACK, SCOUT
    /// - Mine: ATTACK, SCOUT
    /// - Warp Gate: SCOUT
    /// - Ruins: SCOUT
    /// - Empty tile: SETTLE (samo sa SETTLER unit)
    /// - Own city: nijedan (nije self-target)
    private var allowedActions: [MovementType] {
        if isOwnCity { return [] }
        if tile.city != nil {
            return [.ATTACK, .RAID, .SCOUT, .REINFORCE, .TRANSPORT]
        }
        if let outpost = tile.outpost {
            return outpost.defeated ? [] : [.ATTACK, .SCOUT]
        }
        if tile.mine != nil    { return [.ATTACK, .SCOUT] }
        if tile.warpGate != nil { return [] }  // Warp gates su pathfinding čvorovi, ne target-i
        if tile.ruins != nil    { return [.RAID, .SCOUT] }
        // Empty tile — nema korisne akcije za sada.
        // SETTLE se ne triggeruje sa mape; Crystal Implosion automatski bira lokaciju.
        return []
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("(\(tile.x), \(tile.y))")
                    .font(.caption.bold().monospacedDigit())
                Text(tile.ring.rawValue)
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(ringColor.opacity(0.3))
                    .clipShape(Capsule())
                Spacer()
                Button { onDismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }

            HStack {
                Text(tile.terrain.rawValue.capitalized)
                    .font(.subheadline)
                Text("·")
                    .foregroundStyle(.secondary)
                Text(tile.rarity.rawValue.capitalized)
                    .font(.subheadline)
                    .foregroundStyle(rarityColor)
            }

            if let city = tile.city {
                Label("\(city.name) (\(city.owner))", systemImage: "house.fill")
                    .font(.caption)
            }
            if let outpost = tile.outpost {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Label("Scavenger Lv \(outpost.level)", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(outpost.defeated ? .secondary : outpostLevelColor(outpost.level))
                        if outpost.defeated {
                            Text("Respawning")
                                .font(.caption2.bold())
                                .foregroundStyle(.secondary)
                        }
                    }
                    HStack(spacing: 8) {
                        if let wall = outpost.wallLevel, wall > 0 {
                            Label("Wall Lv \(wall)", systemImage: "shield.fill")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        if outpost.hasStoredLoot == true {
                            Label("Accumulated Loot", systemImage: "bag.fill")
                                .font(.caption2.bold())
                                .foregroundStyle(.yellow)
                        }
                    }
                }
            }
            if let mine = tile.mine {
                Label("\(mine.resourceType.rawValue.capitalized) Mine (\(Int(mine.productionRate))/hr)", systemImage: "diamond.fill")
                    .font(.caption)
                    .foregroundStyle(.cyan)
            }
            if tile.warpGate != nil {
                Label("Warp Gate", systemImage: "arrow.triangle.swap")
                    .font(.caption)
                    .foregroundStyle(.purple)
            }
            if let ruins = tile.ruins {
                VStack(alignment: .leading, spacing: 2) {
                    Label("Ruins (\(ruins.originalRing.rawValue.capitalized))", systemImage: "building.columns")
                        .font(.caption)
                        .foregroundStyle(.orange)
                    HStack(spacing: 8) {
                        Label {
                            CountdownLabel(endsAt: ruins.decaysAt)
                                .font(.caption2)
                        } icon: {
                            Image(systemName: "clock")
                                .font(.caption2)
                        }
                        .foregroundStyle(.secondary)
                        if let multiplier = implosionConfig?.ruinsLootMultiplier, multiplier > 1 {
                            Text("×\(String(format: "%.0f", multiplier)) loot")
                                .font(.caption2.bold())
                                .foregroundStyle(.yellow)
                        }
                    }
                }
            }

            // Action dugme — vidljivo samo ako nije home city i ima validnih movement type-ova
            if !isOwnCity, !allowedActions.isEmpty {
                Divider()
                    .padding(.vertical, 2)
                HStack(spacing: 8) {
                    Button {
                        onAction(allowedActions)
                    } label: {
                        Label(primaryActionLabel, systemImage: primaryActionIcon)
                            .font(.footnote.bold())
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(actionTint)

                    // Rally Attack shortcut — only for attackable tiles
                    if allowedActions.contains(.ATTACK) {
                        Button {
                            onRallyAttack()
                        } label: {
                            Label("Rally", systemImage: "flag.fill")
                                .font(.footnote.bold())
                        }
                        .buttonStyle(.bordered)
                        .tint(.orange)
                    }
                }
            } else if isOwnCity {
                Text("Your home base")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)
            }
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    /// Primary action label — pokazuje najagresivniju dozvoljenu akciju.
    private var primaryActionLabel: String {
        if allowedActions.contains(.ATTACK) { return "Send Troops" }
        if allowedActions.contains(.RAID) && tile.ruins != nil { return "Raid Ruins" }
        if allowedActions.contains(.SCOUT) { return "Scout" }
        if allowedActions.contains(.SETTLE) { return "Settle" }
        return "Send"
    }

    private var primaryActionIcon: String {
        if allowedActions.contains(.ATTACK) { return "shield.lefthalf.filled.badge.checkmark" }
        if allowedActions.contains(.RAID) && tile.ruins != nil { return "flame.fill" }
        if allowedActions.contains(.SCOUT) { return "eye" }
        if allowedActions.contains(.SETTLE) { return "flag.fill" }
        return "arrow.forward.circle"
    }

    private var actionTint: Color {
        if allowedActions.contains(.ATTACK) { return .red }
        if allowedActions.contains(.RAID) && tile.ruins != nil { return .orange }
        if allowedActions.contains(.SCOUT) { return .cyan }
        return .blue
    }

    private var ringColor: Color {
        switch tile.ring {
        case .fringe: .gray
        case .grid: .orange
        case .core: .red
        case .nexus: .purple
        }
    }

    private var rarityColor: Color {
        switch tile.rarity {
        case .COMMON: .secondary
        case .UNCOMMON: .blue
        case .RARE: .yellow
        }
    }

    private func outpostLevelColor(_ level: Int) -> Color {
        switch level {
        case 1...5:   .gray
        case 6...10:  .green
        case 11...15: .yellow
        case 16...20: .red
        default:      .red
        }
    }
}
