import Foundation
import SwiftData

// MARK: - Доход / выплата

@Model
final class IncomeEntry {
    var amount: Double = 0
    var date: Date = Date()
    var typeRaw: String = IncomeType.salary.rawValue
    var employer: String = ""
    var note: String = ""

    init(
        amount: Double,
        date: Date = .now,
        type: IncomeType = .salary,
        employer: String = "",
        note: String = ""
    ) {
        self.amount = amount
        self.date = date.startOfDay
        self.typeRaw = type.rawValue
        self.employer = employer
        self.note = note
    }

    var type: IncomeType {
        get { IncomeType(rawValue: typeRaw) ?? .other }
        set { typeRaw = newValue.rawValue }
    }
}

// MARK: - Расход

@Model
final class ExpenseEntry {
    var amount: Double = 0
    var date: Date = Date()
    var categoryRaw: String = ExpenseCategory.other.rawValue
    var note: String = ""

    init(
        amount: Double,
        date: Date = .now,
        category: ExpenseCategory = .other,
        note: String = ""
    ) {
        self.amount = amount
        self.date = date.startOfDay
        self.categoryRaw = category.rawValue
        self.note = note
    }

    var category: ExpenseCategory {
        get { ExpenseCategory(rawValue: categoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }
}

// MARK: - Обязательный регулярный платёж (квартира, гараж, коммуналка…)

@Model
final class RecurringPayment {
    var title: String = ""
    var categoryRaw: String = ExpenseCategory.rent.rawValue
    var baseAmount: Double = 0
    var roundingRaw: String = RoundingRule.none.rawValue
    var roundingStep: Double = 100
    var frequencyRaw: String = PaymentFrequency.monthly.rawValue
    var dayOfMonth: Int = 10
    var startDate: Date = Date()
    var isActive: Bool = true
    var note: String = ""

    init(
        title: String,
        category: ExpenseCategory,
        baseAmount: Double,
        rounding: RoundingRule = .none,
        roundingStep: Double = 100,
        frequency: PaymentFrequency = .monthly,
        dayOfMonth: Int = 10,
        startDate: Date = .now,
        isActive: Bool = true,
        note: String = ""
    ) {
        self.title = title
        self.categoryRaw = category.rawValue
        self.baseAmount = baseAmount
        self.roundingRaw = rounding.rawValue
        self.roundingStep = roundingStep
        self.frequencyRaw = frequency.rawValue
        self.dayOfMonth = dayOfMonth
        self.startDate = startDate.startOfDay
        self.isActive = isActive
        self.note = note
    }

    var category: ExpenseCategory {
        get { ExpenseCategory(rawValue: categoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }

    var rounding: RoundingRule {
        get { RoundingRule(rawValue: roundingRaw) ?? .none }
        set { roundingRaw = newValue.rawValue }
    }

    var frequency: PaymentFrequency {
        get { PaymentFrequency(rawValue: frequencyRaw) ?? .monthly }
        set { frequencyRaw = newValue.rawValue }
    }

    /// Сумма к оплате с учётом правила округления.
    var payableAmount: Double {
        rounding.apply(baseAmount, step: roundingStep)
    }

    var roundingDelta: Double {
        payableAmount - baseAmount
    }

    var monthlyCost: Double {
        payableAmount / Double(max(1, frequency.months))
    }

    var yearlyCost: Double {
        monthlyCost * 12
    }

    var nextPaymentDate: Date {
        let start = startDate.startOfDay
        if frequency == .monthly {
            let today = Date().startOfDay
            var components = Calendar.current.dateComponents([.year, .month], from: today)
            components.day = min(dayOfMonth, 28)
            var candidate = Calendar.current.date(from: components) ?? today
            if candidate < today {
                candidate = candidate.addingMonths(1)
            }
            return max(candidate, start)
        }
        return start.nextOccurrence(everyMonths: frequency.months, from: start)
    }

    var roundingDescription: String {
        rounding.description(step: roundingStep)
    }
}

// MARK: - Подписка

@Model
final class Subscription {
    var name: String = ""
    var amount: Double = 0
    var cycleRaw: String = SubscriptionCycle.monthly.rawValue
    var startDate: Date = Date()
    var isActive: Bool = true
    var note: String = ""
    var icon: String = "app.fill"
    var tintRaw: String = TintColor.purple.rawValue

    init(
        name: String,
        amount: Double,
        cycle: SubscriptionCycle = .monthly,
        startDate: Date = .now,
        isActive: Bool = true,
        note: String = "",
        icon: String = "app.fill",
        tint: TintColor = .purple
    ) {
        self.name = name
        self.amount = amount
        self.cycleRaw = cycle.rawValue
        self.startDate = startDate.startOfDay
        self.isActive = isActive
        self.note = note
        self.icon = icon
        self.tintRaw = tint.rawValue
    }

    var cycle: SubscriptionCycle {
        get { SubscriptionCycle(rawValue: cycleRaw) ?? .monthly }
        set { cycleRaw = newValue.rawValue }
    }

    var tint: TintColor {
        get { TintColor(rawValue: tintRaw) ?? .purple }
        set { tintRaw = newValue.rawValue }
    }

    var monthlyCost: Double {
        isActive ? amount / Double(max(1, cycle.months)) : 0
    }

    var yearlyCost: Double {
        monthlyCost * 12
    }

    var nextPaymentDate: Date {
        startDate.nextOccurrence(everyMonths: cycle.months, from: startDate)
    }

    var cycleTitle: String {
        "\(Fmt.money(amount)) \(cycle.shortTitle)"
    }
}
