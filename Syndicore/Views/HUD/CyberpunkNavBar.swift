import SwiftUI

/// Bottom navigation bar — cyberpunk style, visible on all game screens.
/// Uses existing button_* assets for tabs that have them, SF Symbols for the rest.
/// Active tab gets a cyan glow underline + slight scale-up.
struct CyberpunkNavBar: View {
    @Binding var selectedTab: GameState.GameTab

    private let tabs: [NavTab] = [
        NavTab(tab: .map,      assetName: "button_world_map",  label: "Map"),
        NavTab(tab: .army,     assetName: "button_army",        label: "Army"),
        NavTab(tab: .city,     assetName: "button_home",       label: "Home"),
        NavTab(tab: .research, assetName: "button_research",   label: "Research"),
        NavTab(tab: .syndikat, assetName: "button_syndicate",  label: "Syndicate"),
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(tabs) { navTab in
                NavBarButton(
                    navTab: navTab,
                    isSelected: selectedTab == navTab.tab
                ) {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        selectedTab = navTab.tab
                    }
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 6)
        .padding(.bottom, 2)
        .background(Color.clear)
    }
}

// MARK: - Nav Tab Model

private struct NavTab: Identifiable {
    let tab: GameState.GameTab
    let assetName: String?
    let label: String
    var sfSymbol: String? = nil

    var id: String { tab.rawValue }
}

// MARK: - Nav Bar Button

private struct NavBarButton: View {
    let navTab: NavTab
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Group {
                    if let asset = navTab.assetName {
                        Image(asset)
                            .resizable()
                            .scaledToFit()
                    } else if let sf = navTab.sfSymbol {
                        Image(systemName: sf)
                            .resizable()
                            .scaledToFit()
                            .foregroundStyle(isSelected ? .cyan : .white.opacity(0.6))
                    }
                }
                .frame(width: 72, height: 72)
                .scaleEffect(isSelected ? 1.15 : 1.0)
                .opacity(isSelected ? 1.0 : 0.5)

                Text(navTab.label)
                    .font(isSelected ? .gameHeader(9) : .gameLabel(9))
                    .foregroundStyle(isSelected ? .cyan : .white.opacity(0.5))

                // Active indicator
                RoundedRectangle(cornerRadius: 1)
                    .fill(isSelected ? Color.cyan : Color.clear)
                    .frame(width: 24, height: 2)
                    .shadow(color: isSelected ? .cyan.opacity(0.8) : .clear, radius: 4, y: 0)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
