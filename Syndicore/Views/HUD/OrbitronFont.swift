import SwiftUI

// MARK: - Font Extension

extension Font {
    /// Orbitron variable font — use `.fontWeight()` modifier to control weight.
    /// Font name: "Orbitron" (PostScript name of the variable font).
    /// Falls back silently to system font if the .ttf is not in the bundle.
    static func orbitron(size: CGFloat) -> Font {
        Font.custom("Orbitron", size: size)
    }
}
