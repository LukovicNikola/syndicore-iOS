import SwiftUI

/// Countdown tajmer koji se automatski ažurira svake sekunde.
struct CountdownLabel: View {
    let endsAt: Date

    @State private var remaining: TimeInterval = 0
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        Text(formatted)
            .font(.caption.bold().monospacedDigit())
            .foregroundStyle(remaining > 0 ? .orange : .green)
            .onAppear { updateRemaining() }
            .onReceive(timer) { _ in updateRemaining() }
    }

    private var formatted: String {
        if remaining <= 0 { return "Done" }
        let h = Int(remaining) / 3600
        let m = (Int(remaining) % 3600) / 60
        let s = Int(remaining) % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%02d:%02d", m, s)
    }

    private func updateRemaining() {
        remaining = max(0, endsAt.timeIntervalSinceNow)
    }
}
