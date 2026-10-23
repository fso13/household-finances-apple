import Foundation
import SwiftData

// MARK: - Статусы регулярных платежей

@MainActor
package enum PaymentPeriodService {
    package static func period(
        for payment: RecurringPayment,
        month: Date,
        periods: [PaymentPeriod]
    ) -> PaymentPeriod? {
        periods.first {
            $0.recurringKey == payment.recurringKey && $0.periodStart.isSameMonth(as: month)
        }
    }

    package static func status(
        for payment: RecurringPayment,
        month: Date,
        periods: [PaymentPeriod],
        expenses: [ExpenseEntry]
    ) -> PaymentStatus {
        if let period = period(for: payment, month: month, periods: periods) {
            return period.status
        }
        if PaymentRecorder.isRecorded(payment, expenses: expenses, in: month) {
            return .paid
        }
        return .scheduled
    }

    package static func isOverdue(
        _ payment: RecurringPayment,
        month: Date,
        periods: [PaymentPeriod],
        expenses: [ExpenseEntry],
        now: Date = Date()
    ) -> Bool {
        guard status(for: payment, month: month, periods: periods, expenses: expenses) == .scheduled
        else { return false }
        let monthStart = month.startOfMonth
        guard monthStart <= now.startOfMonth else { return false }
        return dueDate(for: payment, month: month) < now.startOfDay
    }

    package static func dueDate(for payment: RecurringPayment, month: Date) -> Date {
        let monthStart = month.startOfMonth
        if payment.frequency == .monthly {
            var components = Calendar.current.dateComponents([.year, .month], from: monthStart)
            components.day = min(max(1, payment.dayOfMonth), 28)
            return Calendar.current.date(from: components) ?? monthStart
        }
        return payment.nextPaymentDate(relativeTo: monthStart)
    }

    package static func isActive(_ payment: RecurringPayment, in month: Date) -> Bool {
        guard payment.isActive else { return false }
        let monthStart = month.startOfMonth
        let monthEnd = monthStart.addingMonths(1).addingTimeInterval(-1)
        return payment.startDate <= monthEnd
    }

    @discardableResult
    package static func markPaid(
        _ payment: RecurringPayment,
        month: Date,
        context: ModelContext,
        periods: [PaymentPeriod],
        date: Date = Date()
    ) throws -> PaymentPeriod {
        _ = try PaymentRecorder.record(payment, context: context, date: date)

        let existing = period(for: payment, month: month, periods: periods)
        let period =
            existing
            ?? PaymentPeriod(
                payment: payment,
                periodStart: month,
                status: .paid,
                paidAmount: payment.payableAmount,
                paidDate: date
            )
        if existing == nil {
            context.insert(period)
        }
        period.status = .paid
        period.plannedAmount = payment.payableAmount
        period.paidAmount = payment.payableAmount
        period.paidDate = date.startOfDay
        period.title = payment.title

        try Persistence.save(context, operation: "payment.period.paid")
        return period
    }

    @discardableResult
    package static func skip(
        _ payment: RecurringPayment,
        month: Date,
        context: ModelContext,
        periods: [PaymentPeriod]
    ) throws -> PaymentPeriod {
        let existing = period(for: payment, month: month, periods: periods)
        if let existing, existing.status == .paid {
            throw AppError.validation("Оплаченный платёж нельзя пропустить.")
        }
        let period =
            existing
            ?? PaymentPeriod(
                payment: payment,
                periodStart: month,
                status: .skipped,
                paidAmount: 0
            )
        if existing == nil {
            context.insert(period)
        }
        period.status = .skipped
        period.plannedAmount = payment.payableAmount
        period.paidAmount = 0
        period.paidDate = nil
        period.title = payment.title

        try Persistence.save(context, operation: "payment.period.skip")
        return period
    }

    package static func unskip(
        _ period: PaymentPeriod,
        context: ModelContext
    ) throws {
        guard period.status == .skipped else { return }
        context.delete(period)
        try Persistence.save(context, operation: "payment.period.unskip")
    }
}
