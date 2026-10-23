import Foundation
import SwiftData

// MARK: - Период регулярного платежа

@Model
package final class PaymentPeriod {
    package var uid: UUID = UUID()
    package var recurringKey: String = ""
    package var periodStart: Date = Date()
    package var statusRaw: String = PaymentStatus.scheduled.rawValue
    package var plannedAmountKopecks: Int = 0
    package var paidAmountKopecks: Int = 0
    package var paidDate: Date?
    package var title: String = ""
    package var note: String = ""

    package init(
        payment: RecurringPayment,
        periodStart: Date,
        status: PaymentStatus,
        paidAmount: Double? = nil,
        paidDate: Date? = nil,
        note: String = ""
    ) {
        self.uid = UUID()
        self.recurringKey = payment.recurringKey
        self.periodStart = periodStart.startOfMonth
        self.statusRaw = status.rawValue
        self.plannedAmountKopecks = Money.kopecks(from: payment.payableAmount)
        self.paidAmountKopecks = Money.kopecks(from: paidAmount ?? payment.payableAmount)
        self.paidDate = paidDate?.startOfDay
        self.title = payment.title
        self.note = note
    }

    package init(
        recurringKey: String,
        periodStart: Date,
        status: PaymentStatus,
        plannedAmount: Double,
        paidAmount: Double,
        paidDate: Date?,
        title: String,
        note: String
    ) {
        self.uid = UUID()
        self.recurringKey = recurringKey
        self.periodStart = periodStart.startOfMonth
        self.statusRaw = status.rawValue
        self.plannedAmountKopecks = Money.kopecks(from: plannedAmount)
        self.paidAmountKopecks = Money.kopecks(from: paidAmount)
        self.paidDate = paidDate?.startOfDay
        self.title = title
        self.note = note
    }

    package var status: PaymentStatus {
        get { PaymentStatus(rawValue: statusRaw) ?? .scheduled }
        set { statusRaw = newValue.rawValue }
    }

    package var plannedAmount: Double {
        get { Money.amount(from: plannedAmountKopecks) }
        set { plannedAmountKopecks = Money.kopecks(from: newValue) }
    }

    package var paidAmount: Double {
        get { Money.amount(from: paidAmountKopecks) }
        set { paidAmountKopecks = Money.kopecks(from: newValue) }
    }
}
