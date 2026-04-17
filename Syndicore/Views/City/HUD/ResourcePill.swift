import SwiftUI

/// Mali indikator resursa — ikona + vrednost, glass morphism pozadina.
struct ResourcePill: View {
    let icon:  String
    let color: Color
    let value: Double

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .font(.system(size: 10, weight: .bold))
            Text("\(Int(value))")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
    }
}
