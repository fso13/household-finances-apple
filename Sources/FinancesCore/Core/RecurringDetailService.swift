import Foundation
import SwiftData

// MARK: - Настройки и история регулярных платежей

@MainActor
package enum RecurringDetailService {
    package static func detail(
        for payment: RecurringPayment,
        details: [RecurringDetail]
    ) -> RecurringDetail? {
        details.first { $0.recurringKey == payment.recurringKey }
    }

    package static func isActive(
        _ payment: RecurringPayment,
        in month: Date,
        details: [RecurringDetail]
    ) -> Bool {
        guard payment.isActive else { return false }
        let monthStart = month.startOfMonth
        let monthEnd = monthStart.addingMonths(1).addingTimeInterval(-1)
        guard payment.startDate <= monthEnd else { return false }
        if let endDate = detail(for: payment, details: details)?.endDate, endDate < monthStart {
            return false
        }
        return true
    }

    package static func history(
        for payment: RecurringPayment,
        changes: [RecurringPriceChange]
    ) -> [RecurringPriceChange] {
        changes
            .filter { $0.recurringKey == payment.recurringKey }
            .sorted { $0.effectiveDate > $1.effectiveDate }
    }

    @discardableResult
    package static func recordPriceChange(
        for payment: RecurringPayment,
        amount: Double,
        date: Date = Date(),
        changes: [RecurringPriceChange],
        context: ModelContext
    ) -> RecurringPriceChange? {
        let existing = history(for: payment, changes: changes).first
        if let existing, abs(existing.amount - amount) < 0.005 {
            return nil
        }

        let change = RecurringPriceChange(
            payment: payment,
            effectiveDate: date,
            amount: amount
        )
        context.insert(change)
        try? Persistence.save(context, operation: "recurring.priceChange")
        return change
    }
}
