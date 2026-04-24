import UIKit
import UserNotifications
import os

/// Handles APNS device token registration and foreground notification presentation.
/// Wired via `@UIApplicationDelegateAdaptor` in SyndicoreApp.
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    private static let log = Logger(subsystem: "com.syndicore.ios", category: "AppDelegate")

    /// Stashed token hex string — AppState reads this after bootstrap to POST to BE.
    /// Using static so AppState can access without a reference to the delegate instance.
    static var pendingDeviceToken: String?

    // MARK: - UIApplicationDelegate

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let hex = deviceToken.map { String(format: "%02x", $0) }.joined()
        Self.log.info("APNS token received (\(hex.prefix(8))...)")
        Self.pendingDeviceToken = hex
        // Notify AppState to send token to BE
        NotificationCenter.default.post(name: .didReceiveDeviceToken, object: hex)
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        Self.log.error("APNS registration failed: \(error.localizedDescription, privacy: .public)")
    }

    // MARK: - UNUserNotificationCenterDelegate

    /// Show banner + sound even when app is in foreground.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    /// Handle tap on notification — for now just log, future: deep link to relevant tab.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo
        Self.log.info("Notification tapped: \(userInfo.description, privacy: .public)")
    }
}

// MARK: - Notification Name

extension Notification.Name {
    static let didReceiveDeviceToken = Notification.Name("didReceiveDeviceToken")
}
