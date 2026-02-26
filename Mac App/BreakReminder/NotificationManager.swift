import Foundation

class NotificationManager {
    static let shared = NotificationManager()

    private var isAvailable = false

    private init() {
        // Don't initialize anything - notifications will be set up later
        // after the app is fully launched
    }

    func setup() {
        // For now, notifications are handled via overlay + sounds only
        // UNUserNotificationCenter requires entitlements that aren't
        // available for unsigned SPM-built apps
        print("📬 Notification manager initialized (overlay + sound mode)")
        isAvailable = true
    }

    func requestPermission() {
        // No-op for now - we use overlays instead
        print("📬 Using overlay-based breaks (no notification entitlement needed)")
    }

    func sendBreakNotification(type: BreakType) {
        // Breaks are handled via full-screen overlay, not system notifications
        // This is actually a better UX anyway
    }

    func sendWarningNotification(type: BreakType, secondsUntil: Int) {
        // For warning, we could play a subtle sound
        // The overlay will appear shortly anyway
    }
}

enum BreakType: Int, Comparable {
    case blink = 0
    case posture = 1
    case lookAway = 2
    case walk = 3

    static func < (lhs: BreakType, rhs: BreakType) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
}
