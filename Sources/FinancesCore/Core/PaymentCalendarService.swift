import Foundation

// MARK: - Календарь платежей

package struct UpcomingPayment: Identifiable {
    package enum Kind: String, Sendable {
        case recurring
        case subscription
    }

    package let id: String
    package let title: String
    package let date: Date
    package let amount: Double
    package let category: ExpenseCategory
    package let kind: Kind
    package let status: PaymentStatus
    package let isOverdue: Bool
}

@MainActor
package enum PaymentCalendarService {
    package static func upcoming(
        payments: [RecurringPayment],
        subscriptions: [Subscription],
        periods: [PaymentPeriod],
        expenses: [ExpenseEntry],
        month: Date,
        details: [RecurringDetail] = [],
        now: Date = Date()
    ) -> [UpcomingPayment] {
        var result: [UpcomingPayment] = []

        for payment in payments where RecurringDetailService.isActive(payment, in: month, details: details) {
            let due = PaymentPeriodService.dueDate(for: payment, month: month)
            guard due.isSameMonth(as: month) else { continue }
            let status = PaymentPeriodService.status(
                for: payment,
                month: month,
                periods: periods,
                expenses: expenses
            )
            result.append(
                UpcomingPayment(
                    id: "recurring-\(payment.recurringKey)-\(month.year)-\(month.month)",
                    title: payment.title,
                    date: due,
                    amount: payment.payableAmount,
                    category: payment.category,
                    kind: .recurring,
                    status: status,
                    isOverdue: PaymentPeriodService.isOverdue(
                        payment,
                        month: month,
                        periods: periods,
                        expenses: expenses,
                        now: now
                    )
                )
            )
        }

        for subscription in subscriptions where subscription.isActive {
            let due = subscription.nextPaymentDate(relativeTo: month.startOfMonth)
            guard due.isSameMonth(as: month) else { continue }
            let paid = PaymentRecorder.isRecorded(subscription, expenses: expenses, in: month)
            result.append(
                UpcomingPayment(
                    id: "subscription-\(subscription.name)-\(month.year)-\(month.month)",
                    title: subscription.name,
                    date: due,
                    amount: subscription.amount,
                    category: .subscriptions,
                    kind: .subscription,
                    status: paid ? .paid : .scheduled,
                    isOverdue: !paid && due < now.startOfDay
                )
            )
        }

        return result.sorted { $0.date < $1.date }
    }
}
