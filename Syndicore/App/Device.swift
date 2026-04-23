import UIKit

/// Stable per-install device identifier for session enforcement.
/// Uses `identifierForVendor` (resets on full vendor app uninstall).
/// Fallback to random UUID for simulator or edge cases.
enum Device {
    static let id: String = UIDevice.current.identifierForVendor?.uuidString
        ?? UUID().uuidString
}
