import Foundation

// MARK: - Напоминания о платежах

package struct PaymentReminder: Identifiable, Sendable {
    package let id: String
    package let title: String
    package let date: Date
    package let amount: Double
}

package enum PaymentReminderPlanner {
    package static func upcoming(
        payments: [RecurringPayment],
        subscriptions: [Subscription],
        now: Date = Date(),
        horizonDays: Int = 7
    ) -> [PaymentReminder] {
        let today = now.startOfDay
        let horizon = Calendar.current.date(byAdding: .day, value: horizonDays, to: today) ?? today
        var result: [PaymentReminder] = []

        for payment in payments where payment.isActive {
            let due = payment.nextPaymentDate(relativeTo: now)
            guard due >= today, due <= horizon else { continue }
            result.append(
                PaymentReminder(
                    id: "recurring-\(payment.recurringKey)-\(due.timeIntervalSince1970)",
                    title: payment.title,
                    date: due,
                    amount: payment.payableAmount
                )
            )
        }

        for subscription in subscriptions where subscription.isActive {
            let due = subscription.nextPaymentDate(relativeTo: now)
            guard due >= today, due <= horizon else { continue }
            result.append(
                PaymentReminder(
                    id: "subscription-\(subscription.name)-\(due.timeIntervalSince1970)",
                    title: subscription.name,
                    date: due,
                    amount: subscription.amount
                )
            )
        }

        return result.sorted { $0.date < $1.date }
    }
}
