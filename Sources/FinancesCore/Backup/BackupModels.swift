import Foundation

// MARK: - Формат JSON-бэкапа

package struct BackupEnvelope: Codable, Identifiable, Sendable {
    package static let currentFormatVersion = 1
    package static let formatIdentifier = "finances.backup"

    package var format: String
    package var formatVersion: Int
    package var schemaVersion: String
    package var appVersion: String
    package var createdAt: Date
    package var data: BackupData

    package var id: Date { createdAt }

    package init(
        format: String = BackupEnvelope.formatIdentifier,
        formatVersion: Int = BackupEnvelope.currentFormatVersion,
        schemaVersion: String = "1.0",
        appVersion: String,
        createdAt: Date = Date(),
        data: BackupData
    ) {
        self.format = format
        self.formatVersion = formatVersion
        self.schemaVersion = schemaVersion
        self.appVersion = appVersion
        self.createdAt = createdAt
        self.data = data
    }
}

package struct BackupData: Codable, Sendable {
    package var incomes: [IncomeBackup]
    package var expenses: [ExpenseBackup]
    package var recurring: [RecurringBackup]
    package var subscriptions: [SubscriptionBackup]
    package var budgets: [BudgetBackup]?
    package var goals: [SavingsGoalBackup]?
    package var customCategories: [CustomExpenseCategory]?
    package var periods: [PaymentPeriodBackup]?
    package var recurringDetails: [RecurringDetailBackup]?
    package var priceChanges: [RecurringPriceChangeBackup]?
    package var categoryRules: [CategoryRule]?

    package init(
        incomes: [IncomeBackup] = [],
        expenses: [ExpenseBackup] = [],
        recurring: [RecurringBackup] = [],
        subscriptions: [SubscriptionBackup] = [],
        budgets: [BudgetBackup]? = [],
        goals: [SavingsGoalBackup]? = [],
        customCategories: [CustomExpenseCategory]? = [],
        periods: [PaymentPeriodBackup]? = [],
        recurringDetails: [RecurringDetailBackup]? = [],
        priceChanges: [RecurringPriceChangeBackup]? = [],
        categoryRules: [CategoryRule]? = []
    ) {
        self.incomes = incomes
        self.expenses = expenses
        self.recurring = recurring
        self.subscriptions = subscriptions
        self.budgets = budgets
        self.goals = goals
        self.customCategories = customCategories
        self.periods = periods
        self.recurringDetails = recurringDetails
        self.priceChanges = priceChanges
        self.categoryRules = categoryRules
    }

    package var totalCount: Int {
        var count = incomes.count + expenses.count
        count += recurring.count + subscriptions.count
        count += budgets?.count ?? 0
        count += goals?.count ?? 0
        count += periods?.count ?? 0
        count += recurringDetails?.count ?? 0
        count += priceChanges?.count ?? 0
        return count
    }
}

package struct IncomeBackup: Codable, Sendable {
    package var amount: Double
    package var date: Date
    package var type: String
    package var employer: String
    package var note: String

    package init(_ entry: IncomeEntry) {
        amount = entry.amount
        date = entry.date
        type = entry.type.rawValue
        employer = entry.employer
        note = entry.note
    }

    package init(amount: Double, date: Date, type: String, employer: String, note: String) {
        self.amount = amount
        self.date = date
        self.type = type
        self.employer = employer
        self.note = note
    }
}

package struct ExpenseBackup: Codable, Sendable {
    package var amount: Double
    package var date: Date
    package var category: String
    package var note: String

    package init(_ entry: ExpenseEntry) {
        amount = entry.amount
        date = entry.date
        category = entry.category.rawValue
        note = entry.note
    }

    package init(amount: Double, date: Date, category: String, note: String) {
        self.amount = amount
        self.date = date
        self.category = category
        self.note = note
    }
}

package struct RecurringBackup: Codable, Sendable {
    package var title: String
    package var category: String
    package var baseAmount: Double
    package var rounding: String
    package var roundingStep: Double
    package var frequency: String
    package var dayOfMonth: Int
    package var startDate: Date
    package var isActive: Bool
    package var note: String

    package init(_ payment: RecurringPayment) {
        title = payment.title
        category = payment.category.rawValue
        baseAmount = payment.baseAmount
        rounding = payment.rounding.rawValue
        roundingStep = payment.roundingStep
        frequency = payment.frequency.rawValue
        dayOfMonth = payment.dayOfMonth
        startDate = payment.startDate
        isActive = payment.isActive
        note = payment.note
    }
}

package struct PaymentPeriodBackup: Codable, Sendable {
    package var recurringKey: String
    package var periodStart: Date
    package var status: String
    package var plannedAmount: Double
    package var paidAmount: Double
    package var paidDate: Date?
    package var title: String
    package var note: String

    package init(_ period: PaymentPeriod) {
        recurringKey = period.recurringKey
        periodStart = period.periodStart
        status = period.status.rawValue
        plannedAmount = period.plannedAmount
        paidAmount = period.paidAmount
        paidDate = period.paidDate
        title = period.title
        note = period.note
    }
}

package struct RecurringDetailBackup: Codable, Sendable {
    package var recurringKey: String
    package var endDate: Date?
    package var autoPay: Bool
    package var note: String

    package init(_ detail: RecurringDetail) {
        recurringKey = detail.recurringKey
        endDate = detail.endDate
        autoPay = detail.autoPay
        note = detail.note
    }

    package init(recurringKey: String, endDate: Date?, autoPay: Bool, note: String) {
        self.recurringKey = recurringKey
        self.endDate = endDate
        self.autoPay = autoPay
        self.note = note
    }
}

package struct RecurringPriceChangeBackup: Codable, Sendable {
    package var recurringKey: String
    package var effectiveDate: Date
    package var amount: Double
    package var note: String

    package init(_ change: RecurringPriceChange) {
        recurringKey = change.recurringKey
        effectiveDate = change.effectiveDate
        amount = change.amount
        note = change.note
    }

    package init(recurringKey: String, effectiveDate: Date, amount: Double, note: String) {
        self.recurringKey = recurringKey
        self.effectiveDate = effectiveDate
        self.amount = amount
        self.note = note
    }
}

package struct BudgetBackup: Codable, Sendable {
    package var category: String
    package var year: Int
    package var month: Int
    package var limit: Double
    package var note: String

    package init(_ budget: Budget) {
        category = budget.category.rawValue
        year = budget.year
        month = budget.month
        limit = budget.limit
        note = budget.note
    }

    package init(category: String, year: Int, month: Int, limit: Double, note: String) {
        self.category = category
        self.year = year
        self.month = month
        self.limit = limit
        self.note = note
    }
}

package struct SavingsGoalBackup: Codable, Sendable {
    package var name: String
    package var target: Double
    package var saved: Double
    package var deadline: Date?
    package var note: String
    package var isActive: Bool

    package init(_ goal: SavingsGoal) {
        name = goal.name
        target = goal.target
        saved = goal.saved
        deadline = goal.deadline
        note = goal.note
        isActive = goal.isActive
    }

    package init(name: String, target: Double, saved: Double, deadline: Date?, note: String, isActive: Bool) {
        self.name = name
        self.target = target
        self.saved = saved
        self.deadline = deadline
        self.note = note
        self.isActive = isActive
    }
}

package struct SubscriptionBackup: Codable, Sendable {
    package var name: String
    package var amount: Double
    package var cycle: String
    package var startDate: Date
    package var isActive: Bool
    package var note: String
    package var icon: String
    package var tint: String

    package init(_ subscription: Subscription) {
        name = subscription.name
        amount = subscription.amount
        cycle = subscription.cycle.rawValue
        startDate = subscription.startDate
        isActive = subscription.isActive
        note = subscription.note
        icon = subscription.icon
        tint = subscription.tint.rawValue
    }
}

// MARK: - Восстановление

package enum RestoreMode: String, CaseIterable, Identifiable, Sendable {
    case replace
    case merge

    package var id: String { rawValue }

    package var title: String {
        switch self {
        case .replace: "Заменить текущие данные"
        case .merge: "Добавить недостающие"
        }
    }
}

package struct RestoreSummary: Sendable {
    package var inserted: Int = 0
    package var skipped: Int = 0
    package var mode: RestoreMode

    package init(mode: RestoreMode) {
        self.mode = mode
    }
}
