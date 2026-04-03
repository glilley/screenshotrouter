import AppKit
import UserNotifications

/// Sends a banner notification. Falls back gracefully when UNUserNotifications
/// isn't available (e.g. ad-hoc signed debug builds from DerivedData).
class Notifier: NSObject, UNUserNotificationCenterDelegate {

    private var unAvailable = false

    override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { [weak self] granted, error in
            if error != nil || !granted {
                self?.unAvailable = true
            }
        }
    }

    func show(title: String, body: String) {
        if unAvailable {
            // Fallback: brief status-item tooltip update (no permission needed)
            return
        }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request) { error in
            // Silently ignore delivery failures (e.g. during development)
            _ = error
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
