import Foundation
import SwiftData

// MARK: - Запись фактических платежей из шаблонов

@MainActor
package enum PaymentRecorder {
    /// Записывает обязательный платёж как фактический расход за текущий месяц.
    /// Возвращает false, если такой расход уже есть.
    @discardableResult
    package static func record(_ payment: RecurringPayment, context: ModelContext, date: Date = .now) throws -> Bool {
        guard payment.isActive else { return false }
        let month = date.startOfMonth
        let expenses = try context.fetch(FetchDescriptor<ExpenseEntry>())
        let alreadyExists = expenses.contains { expense in
            expense.category == payment.category
                && expense.date.isSameMonth(as: month)
                && (abs(expense.amount - payment.payableAmount) < 0.5
                    || expense.note.localizedCaseInsensitiveContains(payment.title))
        }
        guard !alreadyExists else { return false }

        context.insert(
            ExpenseEntry(
                amount: payment.payableAmount,
                date: date,
                category: payment.category,
                note: payment.title
            ))
        try Persistence.save(context, operation: "payment.record")
        return true
    }

    /// Записывает списание по подписке за текущий месяц.
    @discardableResult
    package static func record(_ subscription: Subscription, context: ModelContext, date: Date = .now) throws -> Bool {
        guard subscription.isActive else { return false }
        let month = date.startOfMonth
        let expenses = try context.fetch(FetchDescriptor<ExpenseEntry>())
        let alreadyExists = expenses.contains { expense in
            expense.category == .subscriptions
                && expense.date.isSameMonth(as: month)
                && abs(expense.amount - subscription.amount) < 0.5
                && (expense.note.localizedCaseInsensitiveContains(subscription.name)
                    || expense.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        guard !alreadyExists else { return false }

        context.insert(
            ExpenseEntry(
                amount: subscription.amount,
                date: date,
                category: .subscriptions,
                note: "Подписка: \(subscription.name)"
            ))
        try Persistence.save(context, operation: "subscription.record")
        return true
    }

    package static func isRecorded(_ payment: RecurringPayment, expenses: [ExpenseEntry], in month: Date) -> Bool {
        expenses.contains { expense in
            expense.category == payment.category
                && expense.date.isSameMonth(as: month)
                && (abs(expense.amount - payment.payableAmount) < 0.5
                    || expense.note.localizedCaseInsensitiveContains(payment.title))
        }
    }

    package static func isRecorded(_ subscription: Subscription, expenses: [ExpenseEntry], in month: Date) -> Bool {
        expenses.contains { expense in
            expense.category == .subscriptions
                && expense.date.isSameMonth(as: month)
                && abs(expense.amount - subscription.amount) < 0.5
                && (expense.note.localizedCaseInsensitiveContains(subscription.name)
                    || expense.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }
}
