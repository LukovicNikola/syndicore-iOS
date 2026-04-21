import SwiftUI

struct ArmyView: View {
    @Environment(GameState.self) private var gameState

    @State private var skippingId: String?
    @State private var errorMessage: String?

    private var troops: [TroopInfo] { gameState.activeCity?.troops ?? [] }
    private var movements: [TroopMovement] { gameState.activeMovements }

    var body: some View {
        NavigationStack {
            List {
                // Garrison
                Section("Garrison") {
                    if troops.isEmpty {
                        Text("No troops stationed")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(troops, id: \.unitType) { troop in
                            HStack {
                                Text(troop.unitType.rawValue
                                    .replacingOccurrences(of: "_", with: " ")
                                    .capitalized)
                                    .font(.subheadline)
                                Spacer()
                                Text("\(troop.count)")
                                    .font(.subheadline.bold().monospacedDigit())
                                    .foregroundStyle(.cyan)
                            }
                        }
                    }
                }

                // Active movements
                Section("Active Movements") {
                    if movements.isEmpty {
                        Text("No active movements")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(movements) { movement in
                            movementRow(movement)
                        }
                    }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Army")
            .task {
                await gameState.refreshMovements()
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(30))
                    if Task.isCancelled { return }
                    await gameState.refreshMovements()
                }
            }
        }
    }

    @ViewBuilder
    private func movementRow(_ movement: TroopMovement) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: movementIcon(movement.type))
                    .foregroundStyle(movementColor(movement.type))
                Text(movement.type.rawValue.capitalized)
                    .font(.subheadline.bold())
                if movement.isReturning {
                    Text("(Returning)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                CountdownLabel(endsAt: movement.arrivesAt)
                Button {
                    Task { await skipMovement(movement) }
                } label: {
                    if skippingId == movement.id {
                        ProgressView()
                            .controlSize(.mini)
                            .tint(.orange)
                    } else {
                        Text("\u{26A1} DEV")
                            .font(.system(size: 10, weight: .heavy))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.orange, in: Capsule())
                    }
                }
                .disabled(skippingId == movement.id)
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
            }

            let unitsList = movement.units.sorted { $0.key.rawValue < $1.key.rawValue }
            HStack(spacing: 8) {
                ForEach(unitsList, id: \.key) { unitType, count in
                    Text("\(count)x \(unitType.rawValue.capitalized)")
                        .font(.caption2)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(.systemGray5), in: Capsule())
                }
            }
        }
        .padding(.vertical, 4)
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

    private func movementIcon(_ type: MovementType) -> String {
        switch type {
        case .ATTACK: "flame.fill"
        case .RAID:   "bolt.fill"
        case .SCOUT:  "eye.fill"
        case .REINFORCE: "shield.fill"
        case .TRANSPORT: "shippingbox.fill"
        case .SETTLE: "house.fill"
        case .RETURN: "arrow.uturn.backward"
        }
    }

    private func movementColor(_ type: MovementType) -> Color {
        switch type {
        case .ATTACK: .red
        case .RAID:   .orange
        case .SCOUT:  .blue
        case .REINFORCE: .green
        case .TRANSPORT: .purple
        case .SETTLE: .cyan
        case .RETURN: .secondary
        }
    }
}
