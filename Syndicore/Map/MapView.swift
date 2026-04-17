import SwiftUI
import SpriteKit

struct MapView: View {
    @Environment(GameState.self) private var gameState

    @State private var scene: MapScene = {
        let s = MapScene(size: CGSize(width: 800, height: 800))
        s.scaleMode = .resizeFill
        return s
    }()

    @State private var selectedTile: MapTile?
    @State private var isLoading = true
    @State private var viewportCenter = (cx: 0, cy: 0)

    private var worldId: String? {
        gameState.activePlayerWorld?.worldId
    }

    var body: some View {
        ZStack {
            SpriteView(scene: scene)
                .ignoresSafeArea()

            if isLoading {
                ProgressView()
                    .padding(12)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .overlay(alignment: .bottom) {
            if let tile = selectedTile {
                TileInfoCard(tile: tile) {
                    selectedTile = nil
                }
                .transition(.move(edge: .bottom))
                .padding()
            }
        }
        .animation(.easeInOut(duration: 0.2), value: selectedTile?.x)
        .task {
            setupCallbacks()
            if let tile = gameState.activeCity?.tile {
                viewportCenter = (cx: tile.x, cy: tile.y)
            }
            await fetchViewport()
        }
    }

    private func setupCallbacks() {
        scene.onTileTapped = { tile in
            if selectedTile?.x == tile.x && selectedTile?.y == tile.y {
                selectedTile = nil
            } else {
                selectedTile = tile
            }
        }
        scene.onViewportMoved = { cx, cy in
            viewportCenter = (cx: cx, cy: cy)
            Task { await fetchViewport() }
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
        } catch {
            // Silently fail — cached tiles still visible
        }
        isLoading = false
    }
}

// MARK: - Tile Info Card

private struct TileInfoCard: View {
    let tile: MapTile
    let onDismiss: () -> Void

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
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
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
