import SwiftUI

// MARK: - Resource Item

/// Dynamic resource data model — add new resources to the array and the bar renders them automatically.
struct ResourceItem: Identifiable {
    let id: String
    let assetName: String
    let value: Int
    let accentColor: Color

    /// Build resource bar items from city resources + premium currency.
    static func from(_ resources: Resources?, premium: Int = 0) -> [ResourceItem] {
        guard let r = resources else { return [] }
        return [
            ResourceItem(id: "energy", assetName: "resource_energy_v1", value: Int(r.energy ?? 0), accentColor: Color(hex: "FFD700")),
            ResourceItem(id: "alloys", assetName: "resource_alloys_v1", value: Int(r.alloys), accentColor: Color(hex: "00E5FF")),
            ResourceItem(id: "credits", assetName: "resource_credits_v1", value: Int(r.credits), accentColor: Color(hex: "FF8C00")),
            ResourceItem(id: "tech", assetName: "resource_tech_v1", value: Int(r.tech), accentColor: Color(hex: "AA44FF")),
            ResourceItem(id: "premium", assetName: "resource_premium_v1", value: premium, accentColor: Color(red: 1.0, green: 0.3, blue: 0.9)),
        ]
    }
}

// MARK: - CyberpunkResourceBar

/// Horizontal neon resource bar. Accepts a dynamic `[ResourceItem]` array —
/// new resources appear automatically without layout changes.
struct CyberpunkResourceBar: View {
    let items: [ResourceItem]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(items) { item in
                ResourcePillView(item: item)
                if item.id != items.last?.id {
                    Spacer(minLength: 8)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Resource Pill

private struct ResourcePillView: View {
    let item: ResourceItem

    var body: some View {
        HStack(spacing: 5) {
            Image(item.assetName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 32, height: 32)
                .shadow(color: item.accentColor.opacity(0.6), radius: 3)
            Text(formatNumber(item.value))
                .font(.system(size: 16, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white)
                .shadow(color: item.accentColor.opacity(0.7), radius: 4)
                .shadow(color: .black.opacity(0.5), radius: 1, x: 0, y: 1)
        }
    }
}

// MARK: - Number Formatting

private func formatNumber(_ value: Int) -> String {
    switch value {
    case ..<1_000:
        return "\(value)"
    case 1_000..<1_000_000:
        let k = Double(value) / 1_000
        return k.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(k))K"
            : String(format: "%.1fK", k)
    default:
        let m = Double(value) / 1_000_000
        return m.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(m))M"
            : String(format: "%.1fM", m)
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
            CyberpunkResourceBar(items: [
                ResourceItem(id: "energy", assetName: "resource_energy_v1", value: 15000, accentColor: Color(hex: "FFD700")),
                ResourceItem(id: "alloys", assetName: "resource_alloys_v1", value: 7500, accentColor: Color(hex: "00E5FF")),
                ResourceItem(id: "credits", assetName: "resource_credits_v1", value: 42300, accentColor: Color(hex: "FF8C00")),
                ResourceItem(id: "tech", assetName: "resource_tech_v1", value: 12, accentColor: Color(hex: "AA44FF")),
                ResourceItem(id: "premium", assetName: "resource_premium_v1", value: 42, accentColor: Color(red: 1.0, green: 0.3, blue: 0.9)),
            ])
            .padding(.horizontal, 8)
        }
    }
}
