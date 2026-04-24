import SwiftUI

/// Cyberpunk neon resource bar — horizontal strip with 4 resource pills.
/// Drop as `.overlay(alignment: .top)` on any SpriteKit view wrapper.
struct CyberpunkResourceBar: View {
    let resources: Resources?

    // MARK: - Resource definitions

    private struct ResourceDef {
        let label: String
        let icon: String
        let color: Color
        let value: Double
    }

    private var defs: [ResourceDef] {
        guard let r = resources else { return [] }
        return [
            ResourceDef(label: "Energy",  icon: "bolt.fill",     color: Color(hex: "FFD700"), value: r.energy ?? 0),
            ResourceDef(label: "Alloys",  icon: "cpu.fill",      color: Color(hex: "00E5FF"), value: r.alloys),
            ResourceDef(label: "Credits", icon: "c.circle.fill", color: Color(hex: "FF8C00"), value: r.credits),
            ResourceDef(label: "Tech",    icon: "flask.fill",    color: Color(hex: "AA44FF"), value: r.tech),
        ]
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(defs.enumerated()), id: \.offset) { index, def in
                if index > 0 {
                    divider
                }
                pill(def)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(height: 44)
        .background(barBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(neonBorder)
        .shadow(color: Color(hex: "00E5FF").opacity(0.3), radius: 6)
    }

    // MARK: - Pill

    private func pill(_ def: ResourceDef) -> some View {
        HStack(spacing: 4) {
            Image(systemName: def.icon)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(def.color)
                .shadow(color: def.color.opacity(0.6), radius: 3)
            Text(formatNumber(def.value))
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
        }
    }

    // MARK: - Divider

    private var divider: some View {
        Rectangle()
            .fill(Color(hex: "00E5FF").opacity(0.2))
            .frame(width: 1, height: 20)
    }

    // MARK: - Background

    private var barBackground: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(
                RadialGradient(
                    colors: [Color(hex: "0D1A2A"), Color(hex: "0A0A18")],
                    center: .center,
                    startRadius: 0,
                    endRadius: 200
                )
            )
            .opacity(0.85)
    }

    // MARK: - Neon border (double stroke)

    private var neonBorder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color(hex: "00E5FF").opacity(0.3), lineWidth: 1.5)
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color(hex: "00E5FF"), lineWidth: 0.5)
        }
    }

    // MARK: - Number formatting

    private func formatNumber(_ value: Double) -> String {
        let n = Int(value)
        switch n {
        case ..<1_000:
            return "\(n)"
        case 1_000..<1_000_000:
            let k = Double(n) / 1_000
            return k.truncatingRemainder(dividingBy: 1) == 0
                ? "\(Int(k))K"
                : String(format: "%.1fK", k)
        default:
            let m = Double(n) / 1_000_000
            return m.truncatingRemainder(dividingBy: 1) == 0
                ? "\(Int(m))M"
                : String(format: "%.1fM", m)
        }
    }
}

// MARK: - Color hex init

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: Double
        switch hex.count {
        case 6:
            r = Double((int >> 16) & 0xFF) / 255
            g = Double((int >> 8) & 0xFF) / 255
            b = Double(int & 0xFF) / 255
        default:
            r = 1; g = 1; b = 1
        }
        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - Preview

#Preview("CyberpunkResourceBar") {
    ZStack {
        Color.black.ignoresSafeArea()
        VStack(spacing: 20) {
            CyberpunkResourceBar(resources: Resources(
                credits: 42300,
                alloys: 7500,
                tech: 12,
                energy: 15000
            ))
            .padding(.horizontal, 8)

            CyberpunkResourceBar(resources: Resources(
                credits: 1_234_567,
                alloys: 999,
                tech: 56_780,
                energy: 100
            ))
            .padding(.horizontal, 8)
        }
    }
}
