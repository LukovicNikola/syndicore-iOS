import SwiftUI

/// Sheet for creating a new rally — target coords, launch time, commit troops.
struct CreateRallySheet: View {
    @Environment(GameState.self) private var gameState
    @Environment(\.dismiss) private var dismiss

    /// Pre-populated from map tile tap (optional).
    var prefillTargetX: Int?
    var prefillTargetY: Int?

    @State private var targetXText = ""
    @State private var targetYText = ""
    @State private var launchAt: Date = Date().addingTimeInterval(3600) // default +1h
    @State private var selectedCounts: [UnitType: Int] = [:]
    @State private var isCreating = false
    @State private var errorMessage: String?

    private var homeTroops: [TroopInfo] {
        gameState.activeCity?.troops ?? []
    }

    private var totalSelected: Int {
        selectedCounts.values.reduce(0, +)
    }

    private var canCreate: Bool {
        guard let _ = Int(targetXText), let _ = Int(targetYText) else { return false }
        return totalSelected > 0 && !isCreating && launchAt > Date()
    }

    private var minLaunchDate: Date {
        Date().addingTimeInterval(15 * 60) // +15 min
    }

    private var maxLaunchDate: Date {
        Date().addingTimeInterval(48 * 3600) // +48h
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Target") {
                    HStack {
                        TextField("X", text: $targetXText)
                            .keyboardType(.numbersAndPunctuation)
                            .frame(maxWidth: 100)
                        Text(",")
                            .foregroundStyle(.secondary)
                        TextField("Y", text: $targetYText)
                            .keyboardType(.numbersAndPunctuation)
                            .frame(maxWidth: 100)
                    }
                }

                Section("Launch Time") {
                    DatePicker(
                        "Launch at",
                        selection: $launchAt,
                        in: minLaunchDate...maxLaunchDate
                    )
                    .datePickerStyle(.compact)

                    Text("Rally launches in \(launchTimeText)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Commit Troops") {
                    if homeTroops.isEmpty {
                        ContentUnavailableView(
                            "No Troops",
                            systemImage: "person.slash",
                            description: Text("Train troops first.")
                        )
                    } else {
                        ForEach(homeTroops, id: \.unitType) { troop in
                            RallyTroopStepper(
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
                    if let x = Int(targetXText), let y = Int(targetYText) {
                        LabeledContent("Target", value: "(\(x), \(y))")
                    }
                    LabeledContent("Total Units", value: "\(totalSelected)")
                    LabeledContent("Launch", value: launchAt, format: .dateTime)
                }

                if let err = errorMessage {
                    Section {
                        Text(err)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Create Rally")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(isCreating)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await create() }
                    } label: {
                        if isCreating {
                            ProgressView()
                        } else {
                            Text("Create")
                                .fontWeight(.bold)
                        }
                    }
                    .disabled(!canCreate)
                }
            }
            .onAppear {
                if let x = prefillTargetX { targetXText = String(x) }
                if let y = prefillTargetY { targetYText = String(y) }
            }
        }
    }

    private var launchTimeText: String {
        let interval = launchAt.timeIntervalSince(Date())
        if interval < 60 { return "< 1 min" }
        let minutes = Int(interval / 60)
        if minutes < 60 { return "\(minutes) min" }
        let hours = minutes / 60
        let mins = minutes % 60
        return "\(hours)h \(mins)m"
    }

    private func create() async {
        guard let worldId = gameState.activePlayerWorld?.worldId ?? gameState.activeWorld?.id,
              let x = Int(targetXText), let y = Int(targetYText) else { return }

        let units = selectedCounts.filter { $0.value > 0 }
        guard !units.isEmpty else {
            errorMessage = "Select at least 1 unit"
            return
        }

        isCreating = true
        errorMessage = nil

        do {
            let _ = try await gameState.api.createRally(
                worldId: worldId,
                targetX: x,
                targetY: y,
                launchAt: launchAt,
                units: units
            )
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            await gameState.refreshRallies()
            await gameState.refreshCity()
            dismiss()
        } catch let error as APIError {
            errorMessage = rallyErrorMessage(error)
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        } catch {
            errorMessage = error.localizedDescription
        }

        isCreating = false
    }
}

// MARK: - Join Rally Sheet

/// Sheet for joining an existing rally — commit troops to the rally.
struct JoinRallySheet: View {
    let rally: RallyItem

    @Environment(GameState.self) private var gameState
    @Environment(\.dismiss) private var dismiss

    @State private var selectedCounts: [UnitType: Int] = [:]
    @State private var isJoining = false
    @State private var errorMessage: String?

    private var homeTroops: [TroopInfo] {
        gameState.activeCity?.troops ?? []
    }

    private var totalSelected: Int {
        selectedCounts.values.reduce(0, +)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    LabeledContent("Target", value: "(\(rally.target.x), \(rally.target.y))")
                    HStack {
                        Text("Launches")
                        Spacer()
                        CountdownLabel(endsAt: rally.launchAt)
                            .foregroundStyle(.orange)
                    }
                    LabeledContent("Creator", value: rally.creator.username)
                    LabeledContent("Participants", value: "\(rally.participants.count)")
                }

                Section("Commit Troops") {
                    if homeTroops.isEmpty {
                        ContentUnavailableView(
                            "No Troops",
                            systemImage: "person.slash",
                            description: Text("Train troops first.")
                        )
                    } else {
                        ForEach(homeTroops, id: \.unitType) { troop in
                            RallyTroopStepper(
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
                    LabeledContent("Your Units", value: "\(totalSelected)")
                }

                if let err = errorMessage {
                    Section {
                        Text(err)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Join Rally")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(isJoining)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await join() }
                    } label: {
                        if isJoining {
                            ProgressView()
                        } else {
                            Text("Join")
                                .fontWeight(.bold)
                        }
                    }
                    .disabled(totalSelected == 0 || isJoining)
                }
            }
        }
    }

    private func join() async {
        guard let worldId = gameState.activePlayerWorld?.worldId ?? gameState.activeWorld?.id else { return }

        let units = selectedCounts.filter { $0.value > 0 }
        guard !units.isEmpty else {
            errorMessage = "Select at least 1 unit"
            return
        }

        isJoining = true
        errorMessage = nil

        do {
            try await gameState.api.joinRally(worldId: worldId, rallyId: rally.id, units: units)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            await gameState.refreshRallies()
            await gameState.refreshCity()
            dismiss()
        } catch let error as APIError {
            errorMessage = rallyErrorMessage(error)
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        } catch {
            errorMessage = error.localizedDescription
        }

        isJoining = false
    }
}

// MARK: - Shared Components

/// Reusable troop stepper for rally create/join sheets.
struct RallyTroopStepper: View {
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

// MARK: - Error Mapping

/// Maps rally API errors to user-friendly messages.
func rallyErrorMessage(_ error: APIError) -> String {
    switch error {
    case .forbidden(let e):
        switch e.code {
        case .insufficientRank: return "Requires Officer rank or higher"
        case .notSameSyndikat: return "Only syndikat members can join this rally"
        default: return e.error
        }
    case .conflict(let e):
        switch e.code {
        case .rallyPointRequired: return "Build a Rally Point first"
        case .rallyPointLevelTooLow: return "Rally Point level too low"
        case .maxActiveRalliesReached: return "Max active rallies reached at current RP level"
        case .insufficientTroops: return "Not enough troops in your city"
        case .rallyNotForming: return "Rally has already launched"
        case .rallyLaunchWindowClosed: return "Rally launch window has closed"
        default: return e.error
        }
    case .badRequest(let e):
        switch e.code {
        case .launchAtInPast: return "Launch time must be in the future"
        case .invalidTargetTile: return "Target tile doesn't exist"
        default: return e.error
        }
    default:
        return error.localizedDescription
    }
}
