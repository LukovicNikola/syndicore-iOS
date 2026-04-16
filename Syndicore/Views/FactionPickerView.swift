import SwiftUI

struct FactionPickerView: View {
    @Environment(GameState.self) private var gameState

    let world: World

    @State private var selectedFaction: Faction?
    @State private var isJoining = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 20) {
            Text("Join \(world.name)")
                .font(.title2.bold())

            Text("Choose your faction")
                .foregroundStyle(.secondary)

            ForEach(Faction.allCases) { faction in
                FactionCard(
                    faction: faction,
                    isSelected: selectedFaction == faction
                )
                .onTapGesture { selectedFaction = faction }
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Spacer()

            Button {
                Task { await join() }
            } label: {
                if isJoining {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Join World")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(selectedFaction == nil || isJoining)
            .padding(.horizontal, 32)
        }
        .padding()
        .preferredColorScheme(.dark)
    }

    private func join() async {
        guard let faction = selectedFaction else { return }
        isJoining = true
        errorMessage = nil
        do {
            let response = try await gameState.api.joinWorld(id: world.id, faction: faction)
            gameState.didJoinWorld(response: response)
        } catch let error as APIError {
            switch error {
            case .conflict(let err): errorMessage = err.error
            case .badRequest(let err): errorMessage = err.error
            default: errorMessage = error.localizedDescription
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isJoining = false
    }
}

// MARK: - Faction Card

private struct FactionCard: View {
    let faction: Faction
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(faction.displayName)
                    .font(.headline)
                Spacer()
                Text("+\(Int(faction.bonusValue * 100))% \(faction.bonusType)")
                    .font(.caption.bold())
                    .foregroundStyle(.green)
            }
            Text(faction.tagline)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isSelected ? Color.accentColor.opacity(0.15) : Color(.systemGray6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(isSelected ? Color.accentColor : .clear, lineWidth: 2)
        )
        .padding(.horizontal)
    }
}
