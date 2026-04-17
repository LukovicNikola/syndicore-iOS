import SwiftUI

/// Sheet za izgradnju nove zgrade u praznom slotu (tapom na prazan tile).
struct BuildSheet: View {
    let cityId: String
    let hasQueue: Bool

    @Environment(GameState.self) private var gameState
    @Environment(\.dismiss) private var dismiss

    // Sve zgrade koje igrač JOŠ NIJE izgradio
    var buildableTypes: [BuildingType]

    var body: some View {
        NavigationStack {
            Group {
                if buildableTypes.isEmpty {
                    ContentUnavailableView(
                        "Nothing to Build",
                        systemImage: "checkmark.seal.fill",
                        description: Text("You've built all available buildings.")
                    )
                } else {
                    List(buildableTypes, id: \.self) { type in
                        BuildableRow(buildingType: type, cityId: cityId, disabled: hasQueue)
                    }
                }
            }
            .navigationTitle("Build")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Row

private struct BuildableRow: View {
    let buildingType: BuildingType
    let cityId: String
    let disabled: Bool

    @Environment(GameState.self) private var gameState
    @Environment(\.dismiss) private var dismiss

    @State private var isBuilding = false
    @State private var errorMessage: String?

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(buildingType.rawValue
                        .replacingOccurrences(of: "_", with: " ")
                        .capitalized)
                    .font(.subheadline)
                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            Spacer()
            Button {
                Task { await build() }
            } label: {
                if isBuilding {
                    ProgressView().scaleEffect(0.8)
                } else {
                    Text("Build")
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .disabled(disabled || isBuilding)
        }
    }

    private func build() async {
        isBuilding   = true
        errorMessage = nil
        do {
            _ = try await gameState.api.buildNew(cityId: cityId, buildingType: buildingType)
            await gameState.refreshCity()
            dismiss()
        } catch let error as APIError {
            switch error {
            case .badRequest(let e): errorMessage = e.error
            case .conflict(let e):  errorMessage = e.error
            default:                errorMessage = error.localizedDescription
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isBuilding = false
    }
}
