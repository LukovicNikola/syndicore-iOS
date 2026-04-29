import SwiftUI

// MARK: - CyberpunkBuildQueue

struct CyberpunkBuildQueue: View {
    let constructionQueue: ConstructionQueue?
    let trainingJobs: [TrainingJob]

    @State private var isCollapsed = false
    @State private var refreshTrigger = Date()

    private var totalSlots: Int {
        (constructionQueue != nil ? 1 : 0) + trainingJobs.count
    }

    private var isEmpty: Bool {
        constructionQueue == nil && trainingJobs.isEmpty
    }

    var body: some View {
        if !isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                headerBar

                if !isCollapsed {
                    Divider()
                        .background(Color.cyan.opacity(0.3))

                    VStack(spacing: 8) {
                        if let queue = constructionQueue, let endsAt = queue.endsAt {
                            QueueRow(
                                iconAssetName: queue.type.iconAssetName,
                                label: queue.type.displayName,
                                accentColor: queue.type.accentColor,
                                endsAt: endsAt,
                                now: refreshTrigger
                            )
                        }

                        ForEach(trainingJobs) { job in
                            QueueRow(
                                iconAssetName: "building_icon_barracks_v1",
                                label: "\(job.count)x \(job.unitType.rawValue.capitalized)",
                                accentColor: Color(red: 0.0, green: 0.9, blue: 1.0),
                                endsAt: job.endsAt,
                                now: refreshTrigger
                            )
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 10)
                }
            }
            .frame(width: 220)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(red: 0.04, green: 0.04, blue: 0.10).opacity(0.55))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.cyan.opacity(0.6), lineWidth: 1)
            )
            .shadow(color: .cyan.opacity(0.2), radius: 6)
            .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { date in
                refreshTrigger = date
            }
        }
    }

    private var headerBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "hammer.fill")
                .font(.system(size: 10))
                .foregroundColor(.orange)

            Text("QUEUE")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(.white)

            Text("\(totalSlots)")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundColor(.cyan)

            Spacer()

            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isCollapsed.toggle()
                }
            } label: {
                Image(systemName: isCollapsed ? "chevron.down" : "chevron.up")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.cyan)
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }
}

// MARK: - Queue Row

private struct QueueRow: View {
    let iconAssetName: String
    let label: String
    let accentColor: Color
    let endsAt: Date
    let now: Date

    @State private var initialRemaining: TimeInterval?

    private var remaining: TimeInterval { max(0, endsAt.timeIntervalSince(now)) }

    private var progress: Double {
        guard let initial = initialRemaining, initial > 0 else { return 0 }
        return min(1.0, 1.0 - (remaining / initial))
    }

    private var formattedRemaining: String {
        let total = Int(remaining)
        if total >= 3600 {
            let h = total / 3600
            let m = (total % 3600) / 60
            return String(format: "%d:%02d:%02d", h, m, total % 60)
        }
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(iconAssetName)
                .resizable()
                .scaledToFit()
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(label)
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Spacer()
                    Text(formattedRemaining)
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundColor(.cyan)
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.white.opacity(0.1))
                            .frame(height: 4)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(
                                LinearGradient(
                                    colors: [accentColor, accentColor.opacity(0.6)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(0, geo.size.width * progress), height: 4)
                            .shadow(color: accentColor, radius: 2)
                    }
                }
                .frame(height: 4)
            }
        }
        .frame(height: 32)
        .onAppear {
            if initialRemaining == nil {
                initialRemaining = max(1, endsAt.timeIntervalSince(Date()))
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        CyberpunkBuildQueue(
            constructionQueue: ConstructionQueue(
                buildingId: "1",
                type: .FOUNDRY,
                endsAt: Date().addingTimeInterval(195)
            ),
            trainingJobs: [
                TrainingJob(id: "t1", unitType: .GRUNT, count: 10, endsAt: Date().addingTimeInterval(260))
            ]
        )
        .padding()
    }
}
