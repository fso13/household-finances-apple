import FinancesCore
import SwiftUI

// MARK: - Срезы для бубликов

package struct CategorySlice: Identifiable {
    package let id: String
    package let title: String
    package let value: Double
    package let color: Color
    package let icon: String

    package init(id: String, title: String, value: Double, color: Color, icon: String) {
        self.id = id
        self.title = title
        self.value = value
        self.color = color
        self.icon = icon
    }
}

package enum Slices {
    static func incomes(_ incomes: [IncomeEntry]) -> [CategorySlice] {
        let grouped = Dictionary(grouping: incomes, by: \.type)
            .mapValues { entries in entries.reduce(0) { $0 + $1.amount } }

        return
            grouped
            .filter { $0.value > 0 }
            .map { type, value in
                CategorySlice(
                    id: type.rawValue,
                    title: type.title,
                    value: value,
                    color: type.color,
                    icon: type.icon
                )
            }
            .sorted { $0.value > $1.value }
    }

    static func expenses(_ expenses: [ExpenseEntry]) -> [CategorySlice] {
        let grouped = Dictionary(grouping: expenses, by: \.category)
            .mapValues { entries in entries.reduce(0) { $0 + $1.amount } }

        return
            grouped
            .filter { $0.value > 0 }
            .map { category, value in
                CategorySlice(
                    id: category.rawValue,
                    title: category.title,
                    value: value,
                    color: category.color,
                    icon: category.icon
                )
            }
            .sorted { $0.value > $1.value }
    }

    static func subscriptions(_ subscriptions: [Subscription]) -> [CategorySlice] {
        subscriptions
            .filter { $0.isActive && $0.yearlyCost > 0 }
            .map { subscription in
                CategorySlice(
                    id: subscription.name,
                    title: subscription.name,
                    value: subscription.yearlyCost,
                    color: subscription.tint.color,
                    icon: subscription.icon
                )
            }
            .sorted { $0.value > $1.value }
    }
}
