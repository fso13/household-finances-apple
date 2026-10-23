import Foundation

// MARK: - Сравнение периодов

package struct CategoryChange: Identifiable {
    package let category: ExpenseCategory
    package let current: Double
    package let previous: Double

    package var id: String { category.rawValue }
    package var delta: Double { current - previous }
    package var isGrowth: Bool { delta > 0 }
    package var fraction: Double? {
        guard previous > 0 else { return nil }
        return delta / previous
    }
}

package struct PeriodTotals {
    package let income: Double
    package let expense: Double

    package var net: Double { income - expense }
    package var savingsRate: Double {
        income > 0 ? (income - expense) / income : 0
    }
}

package enum ComparisonService {
    package static func categoryChanges(
        expenses: [ExpenseEntry],
        currentMonth: Date,
        previousMonth: Date? = nil
    ) -> [CategoryChange] {
        let previous = previousMonth ?? currentMonth.addingMonths(-1)
        let currentTotals = totalsByCategory(expenses, in: currentMonth)
        let previousTotals = totalsByCategory(expenses, in: previous)
        let categories = Set(currentTotals.keys).union(previousTotals.keys)

        return
            categories
            .map { category in
                CategoryChange(
                    category: category,
                    current: currentTotals[category] ?? 0,
                    previous: previousTotals[category] ?? 0
                )
            }
            .filter { abs($0.delta) >= 0.005 }
            .sorted { abs($0.delta) > abs($1.delta) }
    }

    package static func totals(
        incomes: [IncomeEntry],
        expenses: [ExpenseEntry],
        in month: Date
    ) -> PeriodTotals {
        PeriodTotals(
            income:
                incomes
                .filter { $0.date.isSameMonth(as: month) }
                .reduce(0) { $0 + $1.amount },
            expense:
                expenses
                .filter { $0.date.isSameMonth(as: month) }
                .reduce(0) { $0 + $1.amount }
        )
    }

    private static func totalsByCategory(
        _ expenses: [ExpenseEntry],
        in month: Date
    ) -> [ExpenseCategory: Double] {
        var result: [ExpenseCategory: Double] = [:]
        for expense in expenses where expense.date.isSameMonth(as: month) {
            result[expense.category, default: 0] += expense.amount
        }
        return result
    }
}
