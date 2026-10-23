import SwiftData

// MARK: - Версия схемы с целями

package enum FinancesSchemaV4: VersionedSchema {
    package static var versionIdentifier: Schema.Version {
        Schema.Version(4, 0, 0)
    }

    package static var models: [any PersistentModel.Type] {
        [
            IncomeEntry.self,
            ExpenseEntry.self,
            RecurringPayment.self,
            Subscription.self,
            Budget.self,
            SavingsGoal.self,
        ]
    }
}
