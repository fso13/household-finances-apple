import Foundation
import SwiftData

// MARK: - Undo для удаления записей

/// SwiftData не регистрирует удаление в `UndoManager` автоматически,
/// поэтому сохраняем снимок записи и восстанавливаем её копией.
@MainActor
package enum DeletionUndo {
    package static func register(_ entry: IncomeEntry, in context: ModelContext) {
        let snapshot = IncomeSnapshot(entry)
        registerDeletion(in: context, restore: { snapshot.restore(in: $0) })
    }

    package static func register(_ entry: ExpenseEntry, in context: ModelContext) {
        let snapshot = ExpenseSnapshot(entry)
        registerDeletion(in: context, restore: { snapshot.restore(in: $0) })
    }

    package static func register(_ payment: RecurringPayment, in context: ModelContext) {
        let snapshot = RecurringSnapshot(payment)
        registerDeletion(in: context, restore: { snapshot.restore(in: $0) })
    }

    package static func register(_ subscription: Subscription, in context: ModelContext) {
        let snapshot = SubscriptionSnapshot(subscription)
        registerDeletion(in: context, restore: { snapshot.restore(in: $0) })
    }

    // MARK: - Общий механизм

    private static func registerDeletion<Model: PersistentModel>(
        in context: ModelContext,
        restore: @escaping (ModelContext) -> Model
    ) {
        let undoManager = DataUndo.shared.manager

        undoManager.registerUndo(withTarget: context) { target in
            let restored = restore(target)
            save(target, operation: "undo.delete")
            registerRestoration(restored, in: target, undoManager: undoManager, restore: restore)
        }
        undoManager.setActionName("Удаление")
    }

    private static func registerRestoration<Model: PersistentModel>(
        _ model: Model,
        in context: ModelContext,
        undoManager: UndoManager,
        restore: @escaping (ModelContext) -> Model
    ) {
        undoManager.registerUndo(withTarget: context) { target in
            target.delete(model)
            save(target, operation: "redo.delete")
            registerDeletion(in: target, restore: restore)
        }
        undoManager.setActionName("Удаление")
    }

    private static func save(_ context: ModelContext, operation: String) {
        do {
            try Persistence.save(context, operation: operation)
        } catch {
            AppLog.storage.error(
                "undo save failed [\(operation, privacy: .public)]: \(error.localizedDescription, privacy: .public)"
            )
        }
    }
}

// MARK: - Снимки

private struct IncomeSnapshot {
    let amount: Double
    let date: Date
    let type: IncomeType
    let employer: String
    let note: String

    init(_ entry: IncomeEntry) {
        amount = entry.amount
        date = entry.date
        type = entry.type
        employer = entry.employer
        note = entry.note
    }

    func restore(in context: ModelContext) -> IncomeEntry {
        let entry = IncomeEntry(amount: amount, date: date, type: type, employer: employer, note: note)
        context.insert(entry)
        return entry
    }
}

private struct ExpenseSnapshot {
    let amount: Double
    let date: Date
    let category: ExpenseCategory
    let note: String

    init(_ entry: ExpenseEntry) {
        amount = entry.amount
        date = entry.date
        category = entry.category
        note = entry.note
    }

    func restore(in context: ModelContext) -> ExpenseEntry {
        let entry = ExpenseEntry(amount: amount, date: date, category: category, note: note)
        context.insert(entry)
        return entry
    }
}

private struct RecurringSnapshot {
    let title: String
    let category: ExpenseCategory
    let baseAmount: Double
    let rounding: RoundingRule
    let roundingStep: Double
    let frequency: PaymentFrequency
    let dayOfMonth: Int
    let startDate: Date
    let isActive: Bool
    let note: String

    init(_ payment: RecurringPayment) {
        title = payment.title
        category = payment.category
        baseAmount = payment.baseAmount
        rounding = payment.rounding
        roundingStep = payment.roundingStep
        frequency = payment.frequency
        dayOfMonth = payment.dayOfMonth
        startDate = payment.startDate
        isActive = payment.isActive
        note = payment.note
    }

    func restore(in context: ModelContext) -> RecurringPayment {
        let payment = RecurringPayment(
            title: title,
            category: category,
            baseAmount: baseAmount,
            rounding: rounding,
            roundingStep: roundingStep,
            frequency: frequency,
            dayOfMonth: dayOfMonth,
            startDate: startDate,
            isActive: isActive,
            note: note
        )
        context.insert(payment)
        return payment
    }
}

private struct SubscriptionSnapshot {
    let name: String
    let amount: Double
    let cycle: SubscriptionCycle
    let startDate: Date
    let isActive: Bool
    let note: String
    let icon: String
    let tint: TintColor

    init(_ subscription: Subscription) {
        name = subscription.name
        amount = subscription.amount
        cycle = subscription.cycle
        startDate = subscription.startDate
        isActive = subscription.isActive
        note = subscription.note
        icon = subscription.icon
        tint = subscription.tint
    }

    func restore(in context: ModelContext) -> Subscription {
        let subscription = Subscription(
            name: name,
            amount: amount,
            cycle: cycle,
            startDate: startDate,
            isActive: isActive,
            note: note,
            icon: icon,
            tint: tint
        )
        context.insert(subscription)
        return subscription
    }
}
