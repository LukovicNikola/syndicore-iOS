import SwiftUI

/// Syndikat tab — segmented into Syndikat management (coming soon) and Rally coordination.
struct SyndikatView: View {
    @Environment(GameState.self) private var gameState

    @State private var selectedTab: Tab = .rally

    enum Tab: String, CaseIterable {
        case syndikat = "Syndikat"
        case rally = "Rally"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Section", selection: $selectedTab) {
                    ForEach(Tab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top, 8)

                switch selectedTab {
                case .syndikat:
                    SyndikatComingSoonView()
                case .rally:
                    RallyListView()
                }
            }
            .navigationTitle("Syndikat")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct SyndikatComingSoonView: View {
    var body: some View {
        ContentUnavailableView(
            "Syndikat Management",
            systemImage: "person.3.fill",
            description: Text("Clan management, members, and diplomacy — coming soon.")
        )
    }
}
