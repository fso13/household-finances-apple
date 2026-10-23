import FinancesCore
import Foundation
import UserNotifications

// MARK: - Локальные уведомления о бюджете

@MainActor
enum BudgetNotificationService {
    private static let enabledKey = "budgetNotificationsEnabled"
    private static let notifiedKey = "notifiedBudgetAlerts"

    static func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    static func notifyIfNeeded(progress: [BudgetProgress], month: Date) {
        let enabled = UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? true
        guard enabled else { return }

        let alerts = BudgetAlertService.alerts(for: progress, month: month)
        guard !alerts.isEmpty else { return }

        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .authorized, .provisional:
                Task { @MainActor in
                    deliver(alerts, center: center)
                }
            case .notDetermined:
                center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
                    if granted {
                        Task { @MainActor in
                            deliver(alerts, center: center)
                        }
                    }
                }
            default:
                break
            }
        }
    }

    private static func deliver(_ alerts: [BudgetAlert], center: UNUserNotificationCenter) {
        let defaults = UserDefaults.standard
        var notified = Set(defaults.stringArray(forKey: notifiedKey) ?? [])

        for alert in alerts where !notified.contains(alert.id) {
            let content = UNMutableNotificationContent()
            content.title = alert.title
            content.body = alert.message
            content.sound = .default

            let request = UNNotificationRequest(
                identifier: alert.id,
                content: content,
                trigger: nil
            )
            center.add(request)
            notified.insert(alert.id)
        }

        defaults.set(Array(notified), forKey: notifiedKey)
    }
}
