import Foundation
import SwiftData

// MARK: - Дополнительные настройки регулярного платежа

@Model
package final class RecurringDetail {
    package var recurringKey: String = ""
    package var endDate: Date?
    package var autoPay: Bool = false
    package var note: String = ""

    package init(
        payment: RecurringPayment,
        endDate: Date? = nil,
        autoPay: Bool = false,
        note: String = ""
    ) {
        self.recurringKey = payment.recurringKey
        self.endDate = endDate?.startOfDay
        self.autoPay = autoPay
        self.note = note
    }

    package init(
        recurringKey: String,
        endDate: Date?,
        autoPay: Bool,
        note: String
    ) {
        self.recurringKey = recurringKey
        self.endDate = endDate?.startOfDay
        self.autoPay = autoPay
        self.note = note
    }
}

// MARK: - История сумм

@Model
package final class RecurringPriceChange {
    package var recurringKey: String = ""
    package var effectiveDate: Date = Date()
    package var amountKopecks: Int = 0
    package var note: String = ""

    package init(
        payment: RecurringPayment,
        effectiveDate: Date = Date(),
        amount: Double,
        note: String = ""
    ) {
        self.recurringKey = payment.recurringKey
        self.effectiveDate = effectiveDate.startOfDay
        self.amountKopecks = Money.kopecks(from: amount)
        self.note = note
    }

    package init(
        recurringKey: String,
        effectiveDate: Date,
        amount: Double,
        note: String
    ) {
        self.recurringKey = recurringKey
        self.effectiveDate = effectiveDate.startOfDay
        self.amountKopecks = Money.kopecks(from: amount)
        self.note = note
    }

    package var amount: Double {
        get { Money.amount(from: amountKopecks) }
        set { amountKopecks = Money.kopecks(from: newValue) }
    }
}
