import SwiftUI

struct FactionPickerView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    let world: WorldSummary
    var onJoined: () -> Void = {}

    @State private var selectedFaction: Faction?
    @State private var isJoining = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
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
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func join() async {
        guard let faction = selectedFaction else { return }
        isJoining = true
        errorMessage = nil
        do {
            try await appState.api.joinWorld(id: world.id, faction: faction)
            onJoined()
            dismiss()
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
