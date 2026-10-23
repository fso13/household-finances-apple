import SwiftData

// MARK: - Версия схемы с настройками и историей платежей

package enum FinancesSchemaV6: VersionedSchema {
    package static var versionIdentifier: Schema.Version {
        Schema.Version(6, 0, 0)
    }

    package static var models: [any PersistentModel.Type] {
        [
            IncomeEntry.self,
            ExpenseEntry.self,
            RecurringPayment.self,
            Subscription.self,
            Budget.self,
            SavingsGoal.self,
            PaymentPeriod.self,
            RecurringDetail.self,
            RecurringPriceChange.self,
        ]
    }
}
