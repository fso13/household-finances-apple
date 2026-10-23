import SwiftData

// MARK: - Версия схемы с бюджетами

package enum FinancesSchemaV3: VersionedSchema {
    package static var versionIdentifier: Schema.Version {
        Schema.Version(3, 0, 0)
    }

    package static var models: [any PersistentModel.Type] {
        [
            IncomeEntry.self,
            ExpenseEntry.self,
            RecurringPayment.self,
            Subscription.self,
            Budget.self,
        ]
    }
}
