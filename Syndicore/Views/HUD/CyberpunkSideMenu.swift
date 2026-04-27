import SwiftUI

// MARK: - Side Menu Action

struct SideMenuAction: Identifiable {
    let id: String
    let assetName: String
    let accentColor: Color
    let badgeCount: Int?
    let action: () -> Void
}

// MARK: - CyberpunkSideMenu

struct CyberpunkSideMenu: View {
    let actions: [SideMenuAction]

    var body: some View {
        VStack(spacing: 12) {
            ForEach(actions) { item in
                SideMenuButton(item: item)
            }
        }
    }
}

// MARK: - Side Menu Button

private struct SideMenuButton: View {
    let item: SideMenuAction

    var body: some View {
        Button(action: item.action) {
            ZStack {
                Image(item.assetName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 44, height: 44)

                if let count = item.badgeCount, count > 0 {
                    Text("\(count)")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .frame(minWidth: 18, minHeight: 18)
                        .padding(.horizontal, 4)
                        .background(
                            Capsule()
                                .fill(Color(red: 1.0, green: 0.3, blue: 0.3))
                        )
                        .overlay(
                            Capsule()
                                .stroke(Color.white.opacity(0.8), lineWidth: 1)
                        )
                        .offset(x: 16, y: -16)
                }
            }
            .frame(width: 48, height: 48)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview("CyberpunkSideMenu") {
    CyberpunkSideMenu(actions: [
        SideMenuAction(id: "settings", assetName: "ui_settings_v1", accentColor: .cyan, badgeCount: nil, action: {}),
        SideMenuAction(id: "email", assetName: "ui_email_v1", accentColor: .cyan, badgeCount: 2, action: {}),
        SideMenuAction(id: "notifications", assetName: "ui_notifications_v1", accentColor: .red, badgeCount: 3, action: {}),
        SideMenuAction(id: "shop", assetName: "ui_shop_v1", accentColor: .pink, badgeCount: nil, action: {}),
    ])
    .padding()
    .background(Color.black)
}
