import SwiftUI

/// Two-tier font system for Syndicore.
///
/// **Display tier (Orbitron)** — all UI chrome: headers, numbers, labels, badges.
/// **Body tier (SF Pro)** — readability-first content: descriptions, tooltips, settings.
///
/// Usage rules:
/// - Never call `.system()` or `.custom()` directly in views — always go through these helpers.
/// - When in doubt: if it's a number or a short label → Orbitron. If it's a sentence → SF Pro.
extension Font {

    // MARK: - Display Tier (Orbitron variable font)

    /// Screen titles and hero text — "EMPIRE OVERVIEW", "SYNDICORE"
    static func gameTitle(_ size: CGFloat) -> Font {
        .orbitron(size: size).weight(.black)
    }

    /// Section headers, panel titles, building names — "TOP SYNDICATES", "BARRACKS LVL 3"
    static func gameHeader(_ size: CGFloat) -> Font {
        .orbitron(size: size).weight(.bold)
    }

    /// Button labels, badges, ring tags — "FRINGE", "ATTACK", "LVL 5"
    static func gameLabel(_ size: CGFloat) -> Font {
        .orbitron(size: size).weight(.medium)
    }

    /// All numeric values — resource counts, timers, coordinates, costs
    static func gameNumber(_ size: CGFloat) -> Font {
        .orbitron(size: size).monospacedDigit()
    }

    /// Small secondary text — captions, metadata, timestamps
    static func gameCaption(_ size: CGFloat) -> Font {
        .orbitron(size: size)
    }

    // MARK: - Body Tier (SF Pro)

    /// Multi-sentence descriptions, tooltips, dialog text
    static func gameBody(_ size: CGFloat) -> Font {
        .system(size: size, weight: .regular)
    }

    /// Emphasized body text — names in lists, inline callouts
    static func gameBodyBold(_ size: CGFloat) -> Font {
        .system(size: size, weight: .semibold)
    }
}
