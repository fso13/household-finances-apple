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

    package init(
        incomes: [IncomeBackup] = [],
        expenses: [ExpenseBackup] = [],
        recurring: [RecurringBackup] = [],
        subscriptions: [SubscriptionBackup] = []
    ) {
        self.incomes = incomes
        self.expenses = expenses
        self.recurring = recurring
        self.subscriptions = subscriptions
    }

    package var totalCount: Int {
        incomes.count + expenses.count + recurring.count + subscriptions.count
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
