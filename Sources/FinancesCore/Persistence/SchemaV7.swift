import SwiftData

// MARK: - Версия схемы с квартирой

package enum FinancesSchemaV7: VersionedSchema {
    package static var versionIdentifier: Schema.Version {
        Schema.Version(7, 0, 0)
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
            ApartmentMonth.self,
        ]
    }
}
