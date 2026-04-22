import SwiftUI

/// Transient success toast model — prikazuje se iznad TabView-a kad stigne
/// realtime event (building_complete / training_complete / troops_arrived).
struct CompletionNotice: Identifiable, Equatable {
    let id: UUID = UUID()
    let kind: Kind
    let title: String
    let subtitle: String

    enum Kind {
        case building
        case training
        case troopsArrived
    }
}

/// Top-of-screen success toast koji auto-dismiss-uje posle 3s.
/// Koristi se iz MainGameView kad stigne realtime completion event.
struct CompletionNoticeBanner: View {
    let notice: CompletionNotice
    let onDismiss: () -> Void

    var body: some View {
        Button(action: onDismiss) {
            HStack(spacing: 10) {
                Image(systemName: iconName)
                    .font(.title3)
                    .foregroundStyle(.white)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(notice.title)
                        .font(.footnote.bold())
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(notice.subtitle)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.85))
                        .lineLimit(1)
                }

                Spacer(minLength: 4)

                Image(systemName: "xmark")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(gradient, in: RoundedRectangle(cornerRadius: 12))
            .shadow(color: accentColor.opacity(0.35), radius: 8, y: 3)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 12)
        .padding(.top, 4)
        .transition(.move(edge: .top).combined(with: .opacity))
        .task {
            // Auto-dismiss posle 3s (SwiftUI cancel-uje task na .onDisappear)
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            withAnimation { onDismiss() }
        }
    }

    private var iconName: String {
        switch notice.kind {
        case .building:      "hammer.circle.fill"
        case .training:      "person.2.circle.fill"
        case .troopsArrived: "arrow.triangle.swap"
        }
    }

    private var accentColor: Color {
        switch notice.kind {
        case .building:      .green
        case .training:      .cyan
        case .troopsArrived: .blue
        }
    }

    private var gradient: LinearGradient {
        // Lipnica sa leve strane bright accent → ka desno suptilno taman
        LinearGradient(
            colors: [accentColor.opacity(0.95), accentColor.opacity(0.75)],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}
