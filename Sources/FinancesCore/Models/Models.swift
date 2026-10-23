import Foundation
import SwiftData

// MARK: - Доход / выплата

@Model
package final class IncomeEntry {
    package var amount: Double = 0
    package var date: Date = Date()
    package var typeRaw: String = IncomeType.salary.rawValue
    package var employer: String = ""
    package var note: String = ""

    package init(
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

    package var type: IncomeType {
        get { IncomeType(rawValue: typeRaw) ?? .other }
        set { typeRaw = newValue.rawValue }
    }
}

// MARK: - Расход

@Model
package final class ExpenseEntry {
    package var amount: Double = 0
    package var date: Date = Date()
    package var categoryRaw: String = ExpenseCategory.other.rawValue
    package var note: String = ""

    package init(
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

    package var category: ExpenseCategory {
        get { ExpenseCategory(rawValue: categoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }
}

// MARK: - Обязательный регулярный платёж (квартира, гараж, коммуналка…)

@Model
package final class RecurringPayment {
    package var title: String = ""
    package var categoryRaw: String = ExpenseCategory.rent.rawValue
    package var baseAmount: Double = 0
    package var roundingRaw: String = RoundingRule.none.rawValue
    package var roundingStep: Double = 100
    package var frequencyRaw: String = PaymentFrequency.monthly.rawValue
    package var dayOfMonth: Int = 10
    package var startDate: Date = Date()
    package var isActive: Bool = true
    package var note: String = ""

    package init(
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

    package var category: ExpenseCategory {
        get { ExpenseCategory(rawValue: categoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }

    package var rounding: RoundingRule {
        get { RoundingRule(rawValue: roundingRaw) ?? .none }
        set { roundingRaw = newValue.rawValue }
    }

    package var frequency: PaymentFrequency {
        get { PaymentFrequency(rawValue: frequencyRaw) ?? .monthly }
        set { frequencyRaw = newValue.rawValue }
    }

    /// Сумма к оплате с учётом правила округления.
    package var payableAmount: Double {
        rounding.apply(baseAmount, step: roundingStep)
    }

    package var roundingDelta: Double {
        payableAmount - baseAmount
    }

    package var monthlyCost: Double {
        payableAmount / Double(max(1, frequency.months))
    }

    package var yearlyCost: Double {
        monthlyCost * 12
    }

    package var nextPaymentDate: Date {
        nextPaymentDate(relativeTo: Date())
    }

    package func nextPaymentDate(relativeTo now: Date) -> Date {
        let start = startDate.startOfDay
        let today = now.startOfDay
        if frequency == .monthly {
            var components = Calendar.current.dateComponents([.year, .month], from: today)
            components.day = min(dayOfMonth, 28)
            var candidate = Calendar.current.date(from: components) ?? today
            if candidate < today {
                candidate = candidate.addingMonths(1)
            }
            return max(candidate, start)
        }
        return start.nextOccurrence(everyMonths: frequency.months, from: start, relativeTo: now)
    }

    package var roundingDescription: String {
        rounding.description(step: roundingStep)
    }
}

// MARK: - Подписка

@Model
package final class Subscription {
    package var name: String = ""
    package var amount: Double = 0
    package var cycleRaw: String = SubscriptionCycle.monthly.rawValue
    package var startDate: Date = Date()
    package var isActive: Bool = true
    package var note: String = ""
    package var icon: String = "app.fill"
    package var tintRaw: String = TintColor.purple.rawValue

    package init(
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

    package var cycle: SubscriptionCycle {
        get { SubscriptionCycle(rawValue: cycleRaw) ?? .monthly }
        set { cycleRaw = newValue.rawValue }
    }

    package var tint: TintColor {
        get { TintColor(rawValue: tintRaw) ?? .purple }
        set { tintRaw = newValue.rawValue }
    }

    package var monthlyCost: Double {
        isActive ? amount / Double(max(1, cycle.months)) : 0
    }

    package var yearlyCost: Double {
        monthlyCost * 12
    }

    package var nextPaymentDate: Date {
        nextPaymentDate(relativeTo: Date())
    }

    package func nextPaymentDate(relativeTo now: Date) -> Date {
        startDate.nextOccurrence(everyMonths: cycle.months, from: startDate, relativeTo: now)
    }
}
