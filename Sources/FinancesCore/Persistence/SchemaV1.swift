import SwiftData

// MARK: - Версия схемы

package enum FinancesSchemaV1: VersionedSchema {
    package static var versionIdentifier: Schema.Version {
        Schema.Version(1, 0, 0)
    }

    package static var models: [any PersistentModel.Type] {
        [
            IncomeEntry.self,
            ExpenseEntry.self,
            RecurringPayment.self,
            Subscription.self,
        ]
    }
}

package enum FinancesMigrationPlan: SchemaMigrationPlan {
    package static var schemas: [any VersionedSchema.Type] {
        [FinancesSchemaV1.self]
    }

    package static var stages: [MigrationStage] {
        []
    }
}
