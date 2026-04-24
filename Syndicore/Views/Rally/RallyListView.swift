import SwiftUI

/// List of active rallies (FORMING + LAUNCHED) with create/join/leave/cancel actions.
struct RallyListView: View {
    @Environment(GameState.self) private var gameState

    @State private var isLoading = false
    @State private var createSheetPresented = false
    @State private var joinTarget: RallyItem?
    @State private var errorMessage: String?

    private var myPlayerWorldId: String? {
        gameState.activePlayerWorld?.id
    }

    var body: some View {
        List {
            if gameState.activeRallies.isEmpty && !isLoading {
                ContentUnavailableView(
                    "No Active Rallies",
                    systemImage: "flag.slash",
                    description: Text("Create a rally to coordinate a group attack with your syndikat.")
                )
            } else {
                ForEach(gameState.activeRallies) { rally in
                    NavigationLink(value: rally.id) {
                        RallyRow(
                            rally: rally,
                            myPlayerWorldId: myPlayerWorldId,
                            onJoin: { joinTarget = rally },
                            onLeave: { await leaveRally(rally) },
                            onCancel: { await cancelRally(rally) }
                        )
                    }
                }
            }

            if let err = errorMessage {
                Section {
                    Text(err)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationDestination(for: String.self) { rallyId in
            if let rally = gameState.activeRallies.first(where: { $0.id == rallyId }) {
                RallyDetailView(rally: rally, myPlayerWorldId: myPlayerWorldId)
            }
        }
        .refreshable { await refresh() }
        .overlay {
            if isLoading && gameState.activeRallies.isEmpty {
                ProgressView()
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    createSheetPresented = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $createSheetPresented) {
            CreateRallySheet()
                .presentationDetents([.large])
        }
        .sheet(item: $joinTarget) { rally in
            JoinRallySheet(rally: rally)
                .presentationDetents([.medium, .large])
        }
        .task { await refresh() }
    }

    private func refresh() async {
        isLoading = true
        await gameState.refreshRallies()
        isLoading = false
    }

    private func leaveRally(_ rally: RallyItem) async {
        guard let worldId = gameState.activePlayerWorld?.worldId ?? gameState.activeWorld?.id else { return }
        do {
            try await gameState.api.leaveRally(worldId: worldId, rallyId: rally.id)
            await gameState.refreshRallies()
            await gameState.refreshCity()
            errorMessage = nil
        } catch {
            errorMessage = errorText(error)
        }
    }

    private func cancelRally(_ rally: RallyItem) async {
        guard let worldId = gameState.activePlayerWorld?.worldId ?? gameState.activeWorld?.id else { return }
        do {
            try await gameState.api.cancelRally(worldId: worldId, rallyId: rally.id)
            await gameState.refreshRallies()
            await gameState.refreshCity()
            errorMessage = nil
        } catch {
            errorMessage = errorText(error)
        }
    }

    private func errorText(_ error: Error) -> String {
        if let apiErr = error as? APIError {
            switch apiErr {
            case .conflict(let e): return e.error
            case .forbidden(let e): return e.error
            case .badRequest(let e): return e.error
            default: return apiErr.localizedDescription
            }
        }
        return error.localizedDescription
    }
}

// MARK: - Rally Row

private struct RallyRow: View {
    let rally: RallyItem
    let myPlayerWorldId: String?
    let onJoin: () -> Void
    let onLeave: () async -> Void
    let onCancel: () async -> Void

    @State private var showCancelConfirm = false
    @State private var isActing = false

    private var isCreator: Bool {
        rally.creator.playerWorldId == myPlayerWorldId
    }

    private var isParticipant: Bool {
        rally.participants.contains { $0.playerWorldId == myPlayerWorldId }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header
            HStack {
                Image(systemName: "flag.fill")
                    .foregroundStyle(.orange)
                Text("Rally to (\(rally.target.x), \(rally.target.y))")
                    .font(.subheadline.bold())
                Spacer()
                statusBadge
            }

            // Creator + participants
            HStack(spacing: 12) {
                Label(rally.creator.username, systemImage: "crown.fill")
                    .font(.caption)
                    .foregroundStyle(.yellow)
                Label("\(rally.participants.count) joined", systemImage: "person.2.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if rally.silentMarch {
                    Image(systemName: "moon.fill")
                        .font(.caption)
                        .foregroundStyle(.purple)
                }
            }

            // Timing
            if rally.status == .FORMING {
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.caption2)
                    Text("Launches")
                    CountdownLabel(endsAt: rally.launchAt)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            } else if rally.status == .LAUNCHED, let arrives = rally.arrivesAt {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.forward.circle")
                        .font(.caption2)
                    Text("Arrives")
                    CountdownLabel(endsAt: arrives)
                }
                .font(.caption)
                .foregroundStyle(.cyan)
            }

            // Troop count
            Label("\(rally.totalTroops) total troops", systemImage: "shield.fill")
                .font(.caption2)
                .foregroundStyle(.secondary)

            // Action buttons (only for FORMING)
            if rally.status == .FORMING {
                HStack(spacing: 8) {
                    if isCreator {
                        Button(role: .destructive) {
                            showCancelConfirm = true
                        } label: {
                            Label("Cancel", systemImage: "xmark.circle")
                                .font(.caption.bold())
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(isActing)
                    } else if isParticipant {
                        Button {
                            isActing = true
                            Task {
                                await onLeave()
                                isActing = false
                            }
                        } label: {
                            Label("Leave", systemImage: "arrow.left.circle")
                                .font(.caption.bold())
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(isActing)
                    } else {
                        Button {
                            onJoin()
                        } label: {
                            Label("Join", systemImage: "plus.circle.fill")
                                .font(.caption.bold())
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.orange)
                        .controlSize(.small)
                    }
                }
                .padding(.top, 2)
            }
        }
        .padding(.vertical, 4)
        .confirmationDialog("Cancel Rally?", isPresented: $showCancelConfirm, titleVisibility: .visible) {
            Button("Cancel Rally", role: .destructive) {
                isActing = true
                Task {
                    await onCancel()
                    isActing = false
                }
            }
        } message: {
            Text("All participants will get their troops back.")
        }
    }

    @ViewBuilder
    private var statusBadge: some View {
        switch rally.status {
        case .FORMING:
            Text("FORMING")
                .font(.caption2.bold())
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.orange.opacity(0.3))
                .clipShape(Capsule())
        case .LAUNCHED:
            Text("EN ROUTE")
                .font(.caption2.bold())
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.cyan.opacity(0.3))
                .clipShape(Capsule())
        case .RESOLVED:
            Text("RESOLVED")
                .font(.caption2.bold())
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.gray.opacity(0.2))
                .clipShape(Capsule())
        case .CANCELLED:
            Text("CANCELLED")
                .font(.caption2.bold())
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.gray.opacity(0.2))
                .clipShape(Capsule())
        }
    }
}
