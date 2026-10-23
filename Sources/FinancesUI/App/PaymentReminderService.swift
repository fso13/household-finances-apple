import FinancesCore
import Foundation
import UserNotifications

// MARK: - Локальные напоминания о платежах

@MainActor
enum PaymentReminderService {
    private static let enabledKey = "paymentRemindersEnabled"

    static func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    static func scheduleIfNeeded(
        payments: [RecurringPayment],
        subscriptions: [Subscription],
        now: Date = Date()
    ) {
        let enabled = UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? true
        guard enabled else { return }

        let reminders = PaymentReminderPlanner.upcoming(
            payments: payments,
            subscriptions: subscriptions,
            now: now
        )
        guard !reminders.isEmpty else { return }

        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .authorized, .provisional:
                schedule(reminders, center: center)
            case .notDetermined:
                center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
                    if granted {
                        Task { @MainActor in
                            schedule(reminders, center: center)
                        }
                    }
                }
            default:
                break
            }
        }
    }

    private static func schedule(_ reminders: [PaymentReminder], center: UNUserNotificationCenter) {
        for reminder in reminders {
            let content = UNMutableNotificationContent()
            content.title = "Платёж: \(reminder.title)"
            content.body = "\(Fmt.money(reminder.amount)) — \(MonthFormat.compactDay(reminder.date))"
            content.sound = .default

            var components = Calendar.current.dateComponents(
                [.year, .month, .day],
                from: reminder.date
            )
            components.hour = 9
            components.minute = 0
            guard let fireDate = Calendar.current.date(from: components), fireDate > Date() else {
                continue
            }
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            center.add(
                UNNotificationRequest(
                    identifier: "payment-reminder-\(reminder.id)",
                    content: content,
                    trigger: trigger
                )
            )
        }
    }
}
