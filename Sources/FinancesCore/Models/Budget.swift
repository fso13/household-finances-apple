import Foundation
import SwiftData

// MARK: - Бюджет на категорию

@Model
package final class Budget {
    package var categoryRaw: String = ExpenseCategory.food.rawValue
    package var year: Int = 0
    package var month: Int = 1
    package var limitKopecks: Int = 0
    package var note: String = ""

    package init(
        category: ExpenseCategory,
        year: Int,
        month: Int,
        limit: Double,
        note: String = ""
    ) {
        self.categoryRaw = category.rawValue
        self.year = year
        self.month = month
        self.limitKopecks = Money.kopecks(from: limit)
        self.note = note
    }

    package var category: ExpenseCategory {
        get { ExpenseCategory(rawValue: categoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }

    package var limit: Double {
        get { Money.amount(from: limitKopecks) }
        set { limitKopecks = Money.kopecks(from: newValue) }
    }

    package var monthStart: Date {
        Date.make(year: year, month: month)
    }

    package func isFor(_ date: Date) -> Bool {
        date.year == year && date.month == month
    }
}
