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
        let existing = period(for: payment, month: month, periods: periods)
        let expenses = try context.fetch(FetchDescriptor<ExpenseEntry>())
        let partial = partialExpense(for: payment, month: month, expenses: expenses)

        if let partial {
            partial.amount = payment.payableAmount
            partial.note = payment.title
            partial.date = date.startOfDay
        } else if !PaymentRecorder.isRecorded(payment, expenses: expenses, in: month) {
            context.insert(
                ExpenseEntry(
                    amount: payment.payableAmount,
                    date: date,
                    category: payment.category,
                    note: payment.title
                )
            )
        }

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

    /// Записывает частичную оплату. `amount` — сколько оплачено сейчас.
    @discardableResult
    package static func recordPartial(
        _ payment: RecurringPayment,
        month: Date,
        amount: Double,
        context: ModelContext,
        periods: [PaymentPeriod],
        date: Date = Date()
    ) throws -> PaymentPeriod {
        guard amount > 0 else {
            throw AppError.validation("Сумма частичной оплаты должна быть больше нуля.")
        }

        let existing = period(for: payment, month: month, periods: periods)
        if let existing, existing.status == .paid {
            throw AppError.validation("Платёж уже оплачен полностью.")
        }

        let alreadyPaid = existing?.status == .partial ? existing?.paidAmount ?? 0 : 0
        let total = alreadyPaid + amount
        if total >= payment.payableAmount {
            return try markPaid(
                payment,
                month: month,
                context: context,
                periods: periods,
                date: date
            )
        }

        let period =
            existing
            ?? PaymentPeriod(
                payment: payment,
                periodStart: month,
                status: .partial,
                paidAmount: total,
                paidDate: date
            )
        if existing == nil {
            context.insert(period)
        }
        period.status = .partial
        period.plannedAmount = payment.payableAmount
        period.paidAmount = total
        period.paidDate = date.startOfDay
        period.title = payment.title

        let expenses = try context.fetch(FetchDescriptor<ExpenseEntry>())
        let note = partialNote(for: payment)
        if let expense = expenses.first(where: {
            $0.category == payment.category
                && $0.date.isSameMonth(as: month)
                && $0.note == note
        }) {
            expense.amount = total
            expense.date = date.startOfDay
        } else {
            context.insert(
                ExpenseEntry(
                    amount: total,
                    date: date,
                    category: payment.category,
                    note: note
                )
            )
        }

        try Persistence.save(context, operation: "payment.period.partial")
        return period
    }

    package static func partialExpense(
        for payment: RecurringPayment,
        month: Date,
        expenses: [ExpenseEntry]
    ) -> ExpenseEntry? {
        let note = partialNote(for: payment)
        return expenses.first {
            $0.category == payment.category
                && $0.date.isSameMonth(as: month)
                && $0.note == note
        }
    }

    private static func partialNote(for payment: RecurringPayment) -> String {
        "\(payment.title) · частично"
    }

    @discardableResult
    package static func skip(
        _ payment: RecurringPayment,
        month: Date,
        context: ModelContext,
        periods: [PaymentPeriod]
    ) throws -> PaymentPeriod {
        let existing = period(for: payment, month: month, periods: periods)
        if let existing, existing.status == .paid || existing.status == .partial {
            throw AppError.validation("Оплаченный или частично оплаченный платёж нельзя пропустить.")
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
