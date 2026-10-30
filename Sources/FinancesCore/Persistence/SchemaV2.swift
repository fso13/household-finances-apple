import SwiftData

// MARK: - Версия схемы

package enum FinancesSchemaV2: VersionedSchema {
    package static var versionIdentifier: Schema.Version {
        Schema.Version(2, 0, 0)
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
        [
            FinancesSchemaV2.self, FinancesSchemaV3.self, FinancesSchemaV4.self, FinancesSchemaV5.self,
            FinancesSchemaV6.self, FinancesSchemaV7.self,
        ]
    }

    package static var stages: [MigrationStage] {
        [
            .lightweight(fromVersion: FinancesSchemaV2.self, toVersion: FinancesSchemaV3.self),
            .lightweight(fromVersion: FinancesSchemaV3.self, toVersion: FinancesSchemaV4.self),
            .lightweight(fromVersion: FinancesSchemaV4.self, toVersion: FinancesSchemaV5.self),
            .lightweight(fromVersion: FinancesSchemaV5.self, toVersion: FinancesSchemaV6.self),
            .lightweight(fromVersion: FinancesSchemaV6.self, toVersion: FinancesSchemaV7.self),
        ]
    }
}
