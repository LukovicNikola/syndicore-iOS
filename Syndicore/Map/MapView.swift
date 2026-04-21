import SwiftUI
import SpriteKit

struct MapView: View {
    @Environment(GameState.self) private var gameState

    @State private var scene: MapScene = {
        let s = MapScene()
        s.size = CGSize(width: 800, height: 800)
        s.scaleMode = .resizeFill
        return s
    }()

    @State private var selectedTile: MapTile?
    @State private var isLoading = true
    @State private var viewportCenter = (cx: 0, cy: 0)

    /// Kad user klikne Attack/Scout/etc u info card-u, ovo se setuje i otvara SendTroopsSheet.
    @State private var sendTroopsTarget: SendTroopsTarget?

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
                    homeTile: gameState.activeCity?.tile
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
        .animation(.easeInOut(duration: 0.2), value: selectedTile?.x)
        .onChange(of: gameState.activeMovements.map(\.id)) { _, _ in
            // Re-push movement lines na scene kad se lista menja
            scene.setMovements(gameState.activeMovements)
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
                await fetchViewport()
            }
        }
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

// MARK: - Tile Info Card

private struct TileInfoCard: View {
    let tile: MapTile
    let onDismiss: () -> Void
    let onAction: ([MovementType]) -> Void
    /// Igracev home city tile — da znamo da li user taphe svoju ili stranu lokaciju.
    let homeTile: TileInfo?

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
        if tile.outpost != nil { return [.ATTACK, .SCOUT] }
        if tile.mine != nil    { return [.ATTACK, .SCOUT] }
        if tile.warpGate != nil { return [.SCOUT] }
        if tile.ruins != nil    { return [.SCOUT] }
        return [.SETTLE]
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
                Label("Outpost Lv \(outpost.level)\(outpost.defeated ? " (defeated)" : "")", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
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
            if tile.ruins != nil {
                Label("Ruins", systemImage: "building.columns")
                    .font(.caption)
                    .foregroundStyle(.gray)
            }

            // Action dugme — vidljivo samo ako nije home city i ima validnih movement type-ova
            if !isOwnCity, !allowedActions.isEmpty {
                Divider()
                    .padding(.vertical, 2)
                Button {
                    onAction(allowedActions)
                } label: {
                    Label(primaryActionLabel, systemImage: primaryActionIcon)
                        .font(.footnote.bold())
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(actionTint)
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
        if allowedActions.contains(.SCOUT) { return "Scout" }
        if allowedActions.contains(.SETTLE) { return "Settle" }
        return "Send"
    }

    private var primaryActionIcon: String {
        if allowedActions.contains(.ATTACK) { return "shield.lefthalf.filled.badge.checkmark" }
        if allowedActions.contains(.SCOUT) { return "eye" }
        if allowedActions.contains(.SETTLE) { return "flag.fill" }
        return "arrow.forward.circle"
    }

    private var actionTint: Color {
        if allowedActions.contains(.ATTACK) { return .red }
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
}
