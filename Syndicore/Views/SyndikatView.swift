import SwiftUI

/// Syndikat tab — segmented into Syndikat management and Rally coordination.
struct SyndikatView: View {
    @Environment(GameState.self) private var gameState

    @State private var selectedTab: Tab = .syndikat

    enum Tab: String, CaseIterable {
        case syndikat = "Syndikat"
        case rally = "Rally"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Section", selection: $selectedTab) {
                    ForEach(Tab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top, 8)

                switch selectedTab {
                case .syndikat:
                    SyndikatContentView()
                case .rally:
                    RallyListView()
                }
            }
            .navigationTitle("Syndikat")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Syndikat Content (routes to browse or detail)

private struct SyndikatContentView: View {
    @Environment(GameState.self) private var gameState

    private var playerWorld: PlayerWorld? { gameState.activePlayerWorld }

    var body: some View {
        if playerWorld?.isInSyndikat == true, let summary = playerWorld?.syndikat {
            SyndikatDetailView(syndikatId: summary.id)
        } else {
            SyndikatBrowseView()
        }
    }
}

// MARK: - Browse (not in a syndikat)

private struct SyndikatBrowseView: View {
    @Environment(GameState.self) private var gameState

    @State private var syndikats: [Syndikat] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showCreateSheet = false
    @State private var joiningId: String?

    private var worldId: String? {
        gameState.activePlayerWorld?.worldId ?? gameState.activeWorld?.id
    }

    var body: some View {
        Group {
            if isLoading && syndikats.isEmpty {
                ProgressView("Loading syndikats...")
            } else if syndikats.isEmpty {
                ContentUnavailableView(
                    "No Syndikats Yet",
                    systemImage: "person.3",
                    description: Text("Be the first to create one!")
                )
            } else {
                List {
                    ForEach(syndikats) { s in
                        SyndikatListRow(
                            syndikat: s,
                            isJoining: joiningId == s.id,
                            onJoin: { Task { await join(s) } }
                        )
                    }
                }
            }
        }
        .overlay(alignment: .bottom) {
            if let err = errorMessage {
                Text(err)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                    .padding()
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showCreateSheet = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .refreshable { await load() }
        .task { await load() }
        .sheet(isPresented: $showCreateSheet) {
            CreateSyndikatSheet(onCreated: {
                Task {
                    await refreshPlayerWorld()
                    await load()
                }
            })
        }
    }

    private func load() async {
        guard let worldId else { return }
        isLoading = true
        do {
            syndikats = try await gameState.api.syndikats(worldId: worldId)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func join(_ syndikat: Syndikat) async {
        guard let worldId else { return }
        joiningId = syndikat.id
        errorMessage = nil
        do {
            try await gameState.api.joinSyndikat(worldId: worldId, syndikatId: syndikat.id)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            await refreshPlayerWorld()
        } catch let error as APIError {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            switch error {
            case .conflict(let e):
                switch e.code {
                case .alreadyInSyndikat: errorMessage = "You are already in a syndikat."
                case .syndikatFull: errorMessage = "This syndikat is full."
                default: errorMessage = e.error
                }
            case .badRequest(let e): errorMessage = e.error
            default: errorMessage = error.localizedDescription
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        joiningId = nil
    }

    private func refreshPlayerWorld() async {
        // Refresh /me to get updated syndikat membership
        try? await gameState.refreshMe()
    }
}

// MARK: - Syndikat List Row

private struct SyndikatListRow: View {
    let syndikat: Syndikat
    let isJoining: Bool
    let onJoin: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(syndikat.tag)
                        .font(.caption.bold())
                        .foregroundStyle(.cyan)
                    Text(syndikat.name)
                        .font(.subheadline.weight(.medium))
                }
                if let count = syndikat.memberCount {
                    Text("\(count) members")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Button {
                onJoin()
            } label: {
                if isJoining {
                    ProgressView().controlSize(.small)
                } else {
                    Text("Join")
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.cyan)
            .controlSize(.small)
        }
    }
}

// MARK: - Create Syndikat Sheet

private struct CreateSyndikatSheet: View {
    let onCreated: () -> Void

    @Environment(GameState.self) private var gameState
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var tag = ""
    @State private var isCreating = false
    @State private var errorMessage: String?

    private var canCreate: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !tag.trimmingCharacters(in: .whitespaces).isEmpty &&
        tag.count <= 5 &&
        !isCreating
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Syndikat Name", text: $name)
                        .textInputAutocapitalization(.words)
                    TextField("Tag (e.g. VOID)", text: $tag)
                        .textInputAutocapitalization(.characters)
                        .onChange(of: tag) { _, newValue in
                            if newValue.count > 5 { tag = String(newValue.prefix(5)) }
                        }
                } footer: {
                    Text("Tag is shown as [\(tag.isEmpty ? "TAG" : tag.uppercased())] next to your clan name. Max 5 characters.")
                }

                if let err = errorMessage {
                    Section {
                        Text(err).font(.caption).foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Create Syndikat")
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
                        if isCreating { ProgressView() } else { Text("Create").bold() }
                    }
                    .disabled(!canCreate)
                }
            }
        }
    }

    private func create() async {
        guard let worldId = gameState.activePlayerWorld?.worldId ?? gameState.activeWorld?.id else { return }
        isCreating = true
        errorMessage = nil
        do {
            let _ = try await gameState.api.createSyndikat(
                worldId: worldId,
                name: name.trimmingCharacters(in: .whitespaces),
                tag: tag.trimmingCharacters(in: .whitespaces).uppercased()
            )
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            onCreated()
            dismiss()
        } catch let error as APIError {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            switch error {
            case .conflict(let e):
                switch e.code {
                case .nameTaken: errorMessage = "Name is already taken."
                case .tagTaken: errorMessage = "Tag is already taken."
                case .alreadyInSyndikat: errorMessage = "You are already in a syndikat."
                default: errorMessage = e.error
                }
            case .badRequest(let e): errorMessage = e.error
            default: errorMessage = error.localizedDescription
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isCreating = false
    }
}

// MARK: - Syndikat Detail View (in a syndikat)

private struct SyndikatDetailView: View {
    let syndikatId: String

    @Environment(GameState.self) private var gameState

    @State private var syndikat: Syndikat?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showLeaveConfirm = false
    @State private var isLeaving = false
    @State private var actionTarget: SyndikatMember?
    @State private var showMemberActions = false

    private var worldId: String? {
        gameState.activePlayerWorld?.worldId ?? gameState.activeWorld?.id
    }

    private var myPlayerWorldId: String? {
        gameState.activePlayerWorld?.id
    }

    private var myRole: SyndikatRole {
        gameState.activePlayerWorld?.syndikatRole ?? .MEMBER
    }

    private var sortedMembers: [SyndikatMember] {
        (syndikat?.members ?? []).sorted { $0.role < $1.role }
    }

    var body: some View {
        Group {
            if isLoading && syndikat == nil {
                ProgressView("Loading syndikat...")
            } else if let syndikat {
                memberList(syndikat)
            } else {
                ContentUnavailableView(
                    "Could not load syndikat",
                    systemImage: "person.3",
                    description: Text(errorMessage ?? "Pull to retry.")
                )
            }
        }
        .refreshable { await load() }
        .task { await load() }
        .confirmationDialog("Leave Syndikat?", isPresented: $showLeaveConfirm, titleVisibility: .visible) {
            Button("Leave", role: .destructive) {
                Task { await leave() }
            }
        } message: {
            Text("You will lose your role and need to be re-invited or re-join.")
        }
        .confirmationDialog(
            "Manage \(actionTarget?.username ?? "")",
            isPresented: $showMemberActions,
            titleVisibility: .visible
        ) {
            if let target = actionTarget {
                memberActionButtons(target)
            }
        }
    }

    private func memberList(_ s: Syndikat) -> some View {
        List {
            // Header
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(s.tag)
                            .font(.title3.bold())
                            .foregroundStyle(.cyan)
                        Text(s.name)
                            .font(.title3.weight(.semibold))
                    }
                    if let count = s.memberCount ?? s.members?.count {
                        Text("\(count) / 30 members")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text("Your role: \(myRole.rawValue.capitalized)")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            // Members
            Section("Members") {
                ForEach(sortedMembers) { member in
                    MemberRow(
                        member: member,
                        isMe: member.playerWorldId == myPlayerWorldId,
                        canManage: myRole.canManage(member.role) && member.playerWorldId != myPlayerWorldId,
                        onTap: {
                            actionTarget = member
                            showMemberActions = true
                        }
                    )
                }
            }

            // Actions
            Section {
                if myRole != .OVERLORD {
                    Button(role: .destructive) {
                        showLeaveConfirm = true
                    } label: {
                        HStack {
                            Label("Leave Syndikat", systemImage: "rectangle.portrait.and.arrow.right")
                            Spacer()
                            if isLeaving { ProgressView().controlSize(.small) }
                        }
                    }
                    .disabled(isLeaving)
                } else {
                    Text("Transfer Overlord role before leaving.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if let err = errorMessage {
                Section {
                    Text(err).font(.caption).foregroundStyle(.red)
                }
            }
        }
    }

    @ViewBuilder
    private func memberActionButtons(_ target: SyndikatMember) -> some View {
        if myRole == .OVERLORD {
            // Overlord can promote to any role below themselves
            if target.role != .WARDEN {
                Button("Promote to Warden") {
                    Task { await updateRole(target, to: .WARDEN) }
                }
            }
            if target.role != .OFFICER {
                Button("Set as Officer") {
                    Task { await updateRole(target, to: .OFFICER) }
                }
            }
            if target.role != .MEMBER {
                Button("Demote to Member") {
                    Task { await updateRole(target, to: .MEMBER) }
                }
            }
        } else if myRole == .WARDEN {
            if target.role == .MEMBER {
                Button("Promote to Officer") {
                    Task { await updateRole(target, to: .OFFICER) }
                }
            }
            if target.role == .OFFICER {
                Button("Demote to Member") {
                    Task { await updateRole(target, to: .MEMBER) }
                }
            }
        }

        if myRole.canManage(target.role) {
            Button("Kick from Syndikat", role: .destructive) {
                Task { await kick(target) }
            }
        }
    }

    // MARK: - Actions

    private func load() async {
        guard let worldId else { return }
        isLoading = true
        do {
            syndikat = try await gameState.api.syndikatDetail(worldId: worldId, syndikatId: syndikatId)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func leave() async {
        guard let worldId else { return }
        isLeaving = true
        errorMessage = nil
        do {
            try await gameState.api.leaveSyndikat(worldId: worldId)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            try? await gameState.refreshMe()
        } catch let error as APIError {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            if case .conflict(let e) = error, e.code == .cannotLeaveAsOverlord {
                errorMessage = "Transfer Overlord role before leaving."
            } else {
                errorMessage = error.localizedDescription
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLeaving = false
    }

    private func updateRole(_ member: SyndikatMember, to role: SyndikatRole) async {
        guard let worldId else { return }
        errorMessage = nil
        do {
            try await gameState.api.updateRole(
                worldId: worldId,
                syndikatId: syndikatId,
                targetPlayerWorldId: member.playerWorldId,
                role: role
            )
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            await load()
            try? await gameState.refreshMe()
        } catch let error as APIError {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func kick(_ member: SyndikatMember) async {
        guard let worldId else { return }
        errorMessage = nil
        do {
            try await gameState.api.kickMember(
                worldId: worldId,
                syndikatId: syndikatId,
                targetPlayerWorldId: member.playerWorldId
            )
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            await load()
        } catch let error as APIError {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Member Row

private struct MemberRow: View {
    let member: SyndikatMember
    let isMe: Bool
    let canManage: Bool
    let onTap: () -> Void

    var body: some View {
        Button { if canManage { onTap() } } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(member.username)
                            .font(.subheadline.weight(isMe ? .bold : .regular))
                        if isMe {
                            Text("(you)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Text(member.faction.displayName)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(member.role.rawValue.capitalized)
                    .font(.caption.bold())
                    .foregroundStyle(roleColor(member.role))
                if canManage {
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func roleColor(_ role: SyndikatRole) -> Color {
        switch role {
        case .OVERLORD: .yellow
        case .WARDEN: .orange
        case .OFFICER: .cyan
        case .MEMBER: .secondary
        }
    }
}
