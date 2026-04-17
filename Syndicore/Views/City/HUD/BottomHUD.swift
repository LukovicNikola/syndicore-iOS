import SwiftUI

/// Donji HUD overlay — aktivna gradnja + dugme za trening.
struct BottomHUD: View {
    let constructionQueue: ConstructionQueue?
    let onOpenTraining: () -> Void

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

            // Akcioni dugmeti
            HStack(spacing: 12) {
                Button(action: onOpenTraining) {
                    Label("Train", systemImage: "person.2.fill")
                        .font(.system(size: 12, weight: .bold))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 9)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        .foregroundStyle(.white)
                }
            }
            .padding(.bottom, 20)
        }
    }
}
