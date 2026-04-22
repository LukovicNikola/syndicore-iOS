import SwiftUI

/// Sheet za slanje vojske na tile na mapi — trupe + tip pokreta + send.
///
/// **Gameplay flow:** igrač tapne enemy outpost (ili bilo koji tile) u MapView-u,
/// vidi "Attack" dugme → otvara se ovaj sheet → bira koje trupe šalje i u kom tipu
/// pokreta → tap "Send" → POST ide na BE → BE kreira movement + vraca route info →
/// movement se pojavi u ArmyView tab-u sa countdown-om do arrival-a.
struct SendTroopsSheet: View {
    let targetX: Int
    let targetY: Int
    /// Dozvoljeni movement type-ovi za ovaj target (npr. SCOUT samo za Warp Gate).
    let allowedMovementTypes: [MovementType]

    @Environment(GameState.self) private var gameState
    @Environment(\.dismiss) private var dismiss

    @State private var selectedCounts: [UnitType: Int] = [:]
    @State private var selectedMovementType: MovementType
    @State private var isSending = false
    @State private var errorMessage: String?
    @State private var successMessage: String?

    /// Trupe trenutno u gradu (iz `city.troops`).
    private var homeTroops: [TroopInfo] {
        gameState.activeCity?.troops ?? []
    }

    private var totalSelected: Int {
        selectedCounts.values.reduce(0, +)
    }

    private var canSend: Bool {
        totalSelected > 0 && !isSending && gameState.activeCity != nil && !allowedMovementTypes.isEmpty
    }

    init(targetX: Int, targetY: Int, allowedMovementTypes: [MovementType]) {
        self.targetX = targetX
        self.targetY = targetY
        self.allowedMovementTypes = allowedMovementTypes
        _selectedMovementType = State(initialValue: allowedMovementTypes.first ?? .ATTACK)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Movement Type", selection: $selectedMovementType) {
                        ForEach(allowedMovementTypes, id: \.self) { type in
                            Text(type.rawValue.capitalized).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Action")
                } footer: {
                    Text(movementDescription(selectedMovementType))
                        .font(.caption)
                }

                Section("Select Units") {
                    if homeTroops.isEmpty {
                        ContentUnavailableView(
                            "No Troops",
                            systemImage: "person.slash",
                            description: Text("Train troops in Barracks, Motor Pool, or Ops Center first.")
                        )
                    } else {
                        ForEach(homeTroops, id: \.unitType) { troop in
                            TroopStepper(
                                unitType: troop.unitType,
                                available: troop.count,
                                selected: Binding(
                                    get: { selectedCounts[troop.unitType] ?? 0 },
                                    set: { selectedCounts[troop.unitType] = $0 }
                                )
                            )
                        }
                    }
                }

                Section("Summary") {
                    LabeledContent("Target", value: "(\(targetX), \(targetY))")
                    LabeledContent("Total Units", value: "\(totalSelected)")
                    LabeledContent("Movement", value: selectedMovementType.rawValue.capitalized)
                }

                if let err = errorMessage {
                    Section {
                        Text(err)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }

                if let msg = successMessage {
                    Section {
                        Text(msg)
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }
            }
            .navigationTitle("Send Troops")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(isSending)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await send() }
                    } label: {
                        if isSending {
                            ProgressView()
                        } else {
                            Text("Send")
                                .fontWeight(.bold)
                        }
                    }
                    .disabled(!canSend)
                }
            }
        }
    }

    // MARK: - Actions

    private func send() async {
        guard let cityId = gameState.activeCity?.id else { return }
        isSending   = true
        errorMessage = nil

        // Ukloni unit-ove sa count=0 (ne slati prazne)
        let unitsToSend = selectedCounts.filter { $0.value > 0 }
        guard !unitsToSend.isEmpty else {
            errorMessage = "Select at least 1 unit"
            isSending = false
            return
        }

        do {
            let response = try await gameState.api.sendTroops(
                cityId: cityId,
                targetX: targetX,
                targetY: targetY,
                units: unitsToSend,
                movementType: selectedMovementType
            )
            let minutes = Int(response.route.travelMinutes.rounded())
            successMessage = "Troops deployed. ETA: \(minutes)m"

            // Haptic success
            UINotificationFeedbackGenerator().notificationOccurred(.success)

            // Refresh movements + city (trupe su odletele iz home count-a)
            await gameState.refreshMovements()
            await gameState.refreshCity()

            // Dismiss sheet after short delay so user sees success message
            try? await Task.sleep(for: .milliseconds(800))
            dismiss()
        } catch let error as APIError {
            switch error {
            case .forbidden(let e):
                // 403 — najčešće `not_allied` na REINFORCE/TRANSPORT ka ne-savezničkoj meti
                if e.code == .notAllied {
                    errorMessage = "You can only reinforce cities of syndikat members or PACT allies."
                } else {
                    errorMessage = e.error
                }
            case .badRequest(let e):   errorMessage = e.error
            case .conflict(let e):     errorMessage = e.error
            case .server(let e):       errorMessage = e.error
            default:                   errorMessage = error.localizedDescription
            }
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        } catch {
            errorMessage = error.localizedDescription
        }

        isSending = false
    }

    // MARK: - Helpers

    private func movementDescription(_ type: MovementType) -> String {
        switch type {
        case .ATTACK:    "Destroy or capture target. Full combat."
        case .RAID:      "Loot resources without capturing. Lighter combat."
        case .SCOUT:     "Reveal target details. Avoids main combat."
        case .REINFORCE: "Send troops to garrison an allied city."
        case .TRANSPORT: "Deliver resources to an allied city."
        case .SETTLE:    "Found a new city (SETTLER unit required)."
        case .RETURN:    "Return trip (auto — not user-triggered)."
        }
    }
}

// MARK: - TroopStepper

private struct TroopStepper: View {
    let unitType: UnitType
    let available: Int
    @Binding var selected: Int

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(unitType.rawValue.capitalized)
                    .font(.subheadline)
                Text("\(available) in city")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Stepper(
                value: $selected,
                in: 0...available,
                step: max(1, available / 20)
            ) {
                Text("\(selected)")
                    .font(.body.monospacedDigit())
                    .frame(minWidth: 32, alignment: .trailing)
            }
            .labelsHidden()

            // Max + None shortcuts
            HStack(spacing: 4) {
                Button("Max") { selected = available }
                    .font(.caption2)
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                    .disabled(selected == available)
                Button("0") { selected = 0 }
                    .font(.caption2)
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                    .disabled(selected == 0)
            }
        }
    }
}
