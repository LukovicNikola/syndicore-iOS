import UIKit

/// Stable per-install device identifier for session enforcement.
/// Uses `identifierForVendor` (resets on full vendor app uninstall).
/// Fallback to random UUID for simulator or edge cases.
enum Device {
    /// `identifierForVendor` reads from UIKit but is documented thread-safe by Apple.
    /// `nonisolated(unsafe)` silences Swift 6's actor isolation inference; the value
    /// is computed once at first access and never mutates afterwards.
    nonisolated(unsafe) static let id: String = {
        UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
    }()
}
