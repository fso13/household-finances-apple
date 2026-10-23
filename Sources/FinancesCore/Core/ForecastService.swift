import Foundation

// MARK: - Прогноз расходов на месяц

package struct MonthForecast {
    package let averageDailyExpense: Double
    package let projectedExpense: Double
    package let daysElapsed: Int
    package let daysInMonth: Int

    package var isComplete: Bool { daysElapsed >= daysInMonth }
}

package enum ForecastService {
    package static func forecast(
        expenses: [ExpenseEntry],
        month: Date,
        categories: Set<ExpenseCategory>? = nil,
        now: Date = Date()
    ) -> MonthForecast {
        let calendar = Calendar.current
        let monthStart = month.startOfMonth
        let today = now.startOfDay
        let daysInMonth = calendar.range(of: .day, in: .month, for: monthStart)?.count ?? 30

        let daysElapsed: Int
        if monthStart > today {
            daysElapsed = 0
        } else if monthStart.isSameMonth(as: today) {
            daysElapsed = min(today.day, daysInMonth)
        } else {
            daysElapsed = daysInMonth
        }

        let spent =
            expenses
            .filter { expense in
                expense.date.isSameMonth(as: monthStart)
                    && (categories?.contains(expense.category) ?? true)
            }
            .reduce(0) { $0 + $1.amount }
        let average = daysElapsed > 0 ? spent / Double(daysElapsed) : 0

        return MonthForecast(
            averageDailyExpense: average,
            projectedExpense: average * Double(daysInMonth),
            daysElapsed: daysElapsed,
            daysInMonth: daysInMonth
        )
    }
}
