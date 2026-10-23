import SwiftData

// MARK: - Версия схемы со статусами платежей

package enum FinancesSchemaV5: VersionedSchema {
    package static var versionIdentifier: Schema.Version {
        Schema.Version(5, 0, 0)
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
        ]
    }
}
