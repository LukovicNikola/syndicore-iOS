import SwiftUI

/// Donji HUD overlay — aktivna gradnja + trening queue (bez dugmeta, to je u CityView).
struct BottomHUD: View {
    let constructionQueue: ConstructionQueue?
    let trainingJobs: [TrainingJob]

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
                    Text("\(job.count)× \(job.unitType.rawValue.capitalized)")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                    Spacer()
                    CountdownLabel(endsAt: job.endsAt)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 20)
            }
        }
    }
}
