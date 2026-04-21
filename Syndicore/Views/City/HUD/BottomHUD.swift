import SwiftUI

/// Donji HUD overlay — aktivna gradnja + trening queue sa skip dugmicima.
struct BottomHUD: View {
    let constructionQueue: ConstructionQueue?
    let trainingJobs: [TrainingJob]
    var onSkipBuild: (() -> Void)?
    var onSkipTraining: ((TrainingJob) -> Void)?

    @State private var skippingBuild = false
    @State private var skippingJobId: String?

    var body: some View {
        VStack(spacing: 8) {
            // Aktivna gradnja (ako postoji)
            if let queue = constructionQueue, let endsAt = queue.endsAt {
                HStack {
                    Image(systemName: "hammer.fill")
                        .foregroundStyle(.orange)
                    Text(queue.type.rawValue
                            .replacingOccurrences(of: "_", with: " ")
                            .capitalized)
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                    Spacer()
                    CountdownLabel(endsAt: endsAt)
                    if let onSkipBuild {
                        Button {
                            skippingBuild = true
                            onSkipBuild()
                        } label: {
                            skipLabel(isLoading: skippingBuild)
                        }
                        .disabled(skippingBuild)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 20)
            }

            // Aktivni trening jobs
            ForEach(trainingJobs) { job in
                HStack {
                    Image(systemName: "person.fill.badge.plus")
                        .foregroundStyle(.cyan)
                    Text("\(job.count)x \(job.unitType.rawValue.capitalized)")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                    Spacer()
                    CountdownLabel(endsAt: job.endsAt)
                    if let onSkipTraining {
                        Button {
                            skippingJobId = job.id
                            onSkipTraining(job)
                        } label: {
                            skipLabel(isLoading: skippingJobId == job.id)
                        }
                        .disabled(skippingJobId == job.id)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 20)
            }
        }
        .onChange(of: constructionQueue?.endsAt) { _, _ in skippingBuild = false }
        .onChange(of: trainingJobs.count) { _, _ in skippingJobId = nil }
    }

    @ViewBuilder
    private func skipLabel(isLoading: Bool) -> some View {
        if isLoading {
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
}
