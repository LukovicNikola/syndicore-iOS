import SwiftUI

/// Detail view showing rally info + participant roster.
struct RallyDetailView: View {
    let rally: RallyItem
    let myPlayerWorldId: String?

    var body: some View {
        List {
            Section("Target") {
                LabeledContent("Coordinates", value: "(\(rally.target.x), \(rally.target.y))")
                LabeledContent("Status", value: rally.status.rawValue.capitalized)
                if rally.silentMarch {
                    Label("Silent March", systemImage: "moon.fill")
                        .foregroundStyle(.purple)
                }
            }

            Section("Timing") {
                HStack {
                    Text("Launch")
                    Spacer()
                    if rally.status == .FORMING {
                        CountdownLabel(endsAt: rally.launchAt)
                            .foregroundStyle(.orange)
                    } else {
                        Text(rally.launchAt, style: .relative)
                            .foregroundStyle(.secondary)
                    }
                }
                if let arrives = rally.arrivesAt {
                    HStack {
                        Text("Arrival")
                        Spacer()
                        if rally.status == .LAUNCHED {
                            CountdownLabel(endsAt: arrives)
                                .foregroundStyle(.cyan)
                        } else {
                            Text(arrives, style: .relative)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Section("Creator") {
                Label(rally.creator.username, systemImage: "crown.fill")
                    .foregroundStyle(.yellow)
            }

            Section("Participants (\(rally.participants.count))") {
                ForEach(rally.participants) { participant in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(participant.username)
                                .font(.subheadline.bold())
                            if participant.playerWorldId == myPlayerWorldId {
                                Text("YOU")
                                    .font(.caption2.bold())
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 1)
                                    .background(.blue.opacity(0.3))
                                    .clipShape(Capsule())
                            }
                            if participant.playerWorldId == rally.creator.playerWorldId {
                                Image(systemName: "crown.fill")
                                    .font(.caption2)
                                    .foregroundStyle(.yellow)
                            }
                            Spacer()
                        }
                        // Unit breakdown
                        let units = participant.unitsTyped.sorted(by: { $0.key.rawValue < $1.key.rawValue })
                        if !units.isEmpty {
                            HStack(spacing: 8) {
                                ForEach(units, id: \.key) { unit, count in
                                    Text("\(unit.rawValue.capitalized): \(count)")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
            }

            Section("Summary") {
                LabeledContent("Total Troops", value: "\(rally.totalTroops)")
                LabeledContent("Participants", value: "\(rally.participants.count)")
            }
        }
        .navigationTitle("Rally Details")
        .navigationBarTitleDisplayMode(.inline)
    }
}
