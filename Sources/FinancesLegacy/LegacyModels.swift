import Foundation
import SwiftData

// MARK: - Схема V1: деньги хранились как Double

@Model
final class IncomeEntry {
    var amount: Double = 0
    var date: Date = Date()
    var typeRaw: String = "salary"
    var employer: String = ""
    var note: String = ""

    init(amount: Double, date: Date, typeRaw: String, employer: String, note: String) {
        self.amount = amount
        self.date = date
        self.typeRaw = typeRaw
        self.employer = employer
        self.note = note
    }
}

@Model
final class ExpenseEntry {
    var amount: Double = 0
    var date: Date = Date()
    var categoryRaw: String = "other"
    var note: String = ""

    init(amount: Double, date: Date, categoryRaw: String, note: String) {
        self.amount = amount
        self.date = date
        self.categoryRaw = categoryRaw
        self.note = note
    }
}

@Model
final class RecurringPayment {
    var title: String = ""
    var categoryRaw: String = "rent"
    var baseAmount: Double = 0
    var roundingRaw: String = "none"
    var roundingStep: Double = 100
    var frequencyRaw: String = "monthly"
    var dayOfMonth: Int = 10
    var startDate: Date = Date()
    var isActive: Bool = true
    var note: String = ""

    init(
        title: String,
        categoryRaw: String,
        baseAmount: Double,
        roundingRaw: String,
        roundingStep: Double,
        frequencyRaw: String,
        dayOfMonth: Int,
        startDate: Date,
        isActive: Bool,
        note: String
    ) {
        self.title = title
        self.categoryRaw = categoryRaw
        self.baseAmount = baseAmount
        self.roundingRaw = roundingRaw
        self.roundingStep = roundingStep
        self.frequencyRaw = frequencyRaw
        self.dayOfMonth = dayOfMonth
        self.startDate = startDate
        self.isActive = isActive
        self.note = note
    }
}

@Model
final class Subscription {
    var name: String = ""
    var amount: Double = 0
    var cycleRaw: String = "monthly"
    var startDate: Date = Date()
    var isActive: Bool = true
    var note: String = ""
    var icon: String = "app.fill"
    var tintRaw: String = "purple"

    init(
        name: String,
        amount: Double,
        cycleRaw: String,
        startDate: Date,
        isActive: Bool,
        note: String,
        icon: String,
        tintRaw: String
    ) {
        self.name = name
        self.amount = amount
        self.cycleRaw = cycleRaw
        self.startDate = startDate
        self.isActive = isActive
        self.note = note
        self.icon = icon
        self.tintRaw = tintRaw
    }
}

enum LegacySchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version {
        Schema.Version(1, 0, 0)
    }

    static var models: [any PersistentModel.Type] {
        [
            IncomeEntry.self,
            ExpenseEntry.self,
            RecurringPayment.self,
            Subscription.self,
        ]
    }
}
