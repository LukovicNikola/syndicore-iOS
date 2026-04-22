import SwiftUI

/// Gornji HUD overlay — naziv grada + resource pills + crystal badge.
struct TopHUD: View {
    let city: City?
    let crystalCount: Int
    var onTapCrystals: () -> Void = {}

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            if let res = city?.resources {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ResourcePill(icon: "creditcard.fill",   color: .yellow, value: res.credits)
                        ResourcePill(icon: "gearshape.2.fill",  color: .gray,   value: res.alloys)
                        ResourcePill(icon: "cpu.fill",          color: .cyan,   value: res.tech)
                        ResourcePill(icon: "bolt.fill",         color: .green,  value: res.energy ?? 0)
                    }
                    .padding(.horizontal, 16)
                }
            }

            Spacer()

            HStack(spacing: 8) {
                // Crystal badge
                Button(action: onTapCrystals) {
                    HStack(spacing: 3) {
                        Image(systemName: "diamond.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.purple)
                        Text("\(crystalCount)")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                }

                if let name = city?.name {
                    Text(name.uppercased())
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                }
            }
            .padding(.trailing, 16)
        }
        .padding(.top, 8)
    }
}
