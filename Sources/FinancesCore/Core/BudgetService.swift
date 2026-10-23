import Foundation

// MARK: - Прогресс бюджетов

package struct BudgetProgress: Identifiable {
    package let id: String
    package let category: ExpenseCategory
    package let limit: Double
    package let spent: Double
    package let note: String

    package var remaining: Double { limit - spent }
    package var isOver: Bool { spent > limit }
    package var fraction: Double {
        guard limit > 0 else { return 0 }
        return spent / limit
    }
}

package struct BudgetSummary {
    package let limit: Double
    package let spent: Double
    package let count: Int

    package var remaining: Double { limit - spent }
    package var isOver: Bool { spent > limit }
}

package enum BudgetService {
    package static func progress(
        budgets: [Budget],
        expenses: [ExpenseEntry],
        month: Date
    ) -> [BudgetProgress] {
        let monthBudgets =
            budgets
            .filter { $0.isFor(month) }
            .reduce(into: [ExpenseCategory: Budget]()) { result, budget in
                if result[budget.category] == nil {
                    result[budget.category] = budget
                }
            }

        return monthBudgets.values
            .map { budget in
                let spent =
                    expenses
                    .filter { $0.category == budget.category && $0.date.isSameMonth(as: month) }
                    .reduce(0) { $0 + $1.amount }

                return BudgetProgress(
                    id: budget.category.rawValue,
                    category: budget.category,
                    limit: budget.limit,
                    spent: spent,
                    note: budget.note
                )
            }
            .sorted { $0.category.title < $1.category.title }
    }

    package static func summary(_ progress: [BudgetProgress]) -> BudgetSummary {
        BudgetSummary(
            limit: progress.reduce(0) { $0 + $1.limit },
            spent: progress.reduce(0) { $0 + $1.spent },
            count: progress.count
        )
    }

    package static func budget(
        for category: ExpenseCategory,
        month: Date,
        in budgets: [Budget]
    ) -> Budget? {
        budgets.first { $0.category == category && $0.isFor(month) }
    }
}
