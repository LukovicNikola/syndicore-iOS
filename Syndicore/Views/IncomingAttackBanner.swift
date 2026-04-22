import SwiftUI

/// Top-of-screen banner koji se prikazuje kad BE emituje `incoming_attack` event.
/// Detail level varira sa igračevim Watchtower level-om (decodes iz IncomingAttackEvent.tier).
///
/// **Gameplay flow:** neko pošalje napad → BE emituje event u city room → SocketService
/// postavi `lastIncomingAttack` → ovaj banner se animirano pojavi iz vrha ekrana,
/// sa countdown-om do arrival-a → kad tajmer dođe na 0, auto-dismiss + trigger refresh.
///
/// Prikazuje se globalno preko MainGameView overlay-a, ne zavisi od tab-a.
struct IncomingAttackBanner: View {
    let event: IncomingAttackEvent
    let onDismiss: () -> Void
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title3)
                    .foregroundStyle(.white)

                VStack(alignment: .leading, spacing: 2) {
                    Text(headline)
                        .font(.footnote.bold())
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        Text(subtitle)
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.85))
                            .lineLimit(1)
                        Spacer(minLength: 4)
                        Text("ETA")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.7))
                        CountdownLabel(endsAt: event.arrivesAt, onComplete: onDismiss)
                            .foregroundStyle(.white)
                    }
                }

                Spacer(minLength: 4)

                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.white.opacity(0.8))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                LinearGradient(
                    colors: [Color.red.opacity(0.95), Color.orange.opacity(0.9)],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                in: RoundedRectangle(cornerRadius: 12)
            )
            .shadow(color: .red.opacity(0.4), radius: 8, y: 3)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 12)
        .padding(.top, 4)
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    // MARK: - Tier-based labels

    private var headline: String {
        let actionWord = event.type == .RAID ? "raid" : "attack"
        switch event.tier {
        case .basic:
            return "Incoming \(actionWord)!"
        case .named, .estimate, .exactArmy, .fullIntel:
            if let name = event.attackerName {
                return "\(actionWord.capitalized) from \(name)"
            }
            return "Incoming \(actionWord)!"
        }
    }

    private var subtitle: String {
        switch event.tier {
        case .basic, .named:
            return " "
        case .estimate:
            if let est = event.troopEstimate {
                return "\(est.capitalized) force"
            }
            return " "
        case .exactArmy:
            let units = event.unitsTyped ?? [:]
            let total = units.values.reduce(0, +)
            return "\(total) units"
        case .fullIntel:
            let units = event.unitsTyped ?? [:]
            let total = units.values.reduce(0, +)
            if let origin = event.origin {
                return "\(total) units from (\(origin.x), \(origin.y))"
            }
            return "\(total) units"
        }
    }
}
