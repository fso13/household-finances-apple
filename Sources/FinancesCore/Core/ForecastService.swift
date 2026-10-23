import Foundation

// MARK: - Прогноз расходов на месяц

package struct BalanceForecast {
    package let incomeReceived: Double
    package let expenseSpent: Double
    package let projectedExpense: Double
    package let upcomingRecurring: Double
    package let daysRemaining: Int

    package var projectedBalance: Double {
        incomeReceived - projectedExpense
    }
}

package struct MonthForecast {
    package let averageDailyExpense: Double
    package let projectedExpense: Double
    package let daysElapsed: Int
    package let daysInMonth: Int

    package var isComplete: Bool { daysElapsed >= daysInMonth }
}

package enum ForecastService {
    package static func balance(
        incomes: [IncomeEntry],
        expenses: [ExpenseEntry],
        recurring: [RecurringPayment],
        month: Date,
        now: Date = Date()
    ) -> BalanceForecast {
        let monthForecast = forecast(expenses: expenses, month: month, now: now)
        let incomeReceived =
            incomes
            .filter { $0.date.isSameMonth(as: month) }
            .reduce(0) { $0 + $1.amount }
        let expenseSpent =
            expenses
            .filter { $0.date.isSameMonth(as: month) }
            .reduce(0) { $0 + $1.amount }
        let today = now.startOfDay
        let upcomingRecurring =
            recurring
            .filter(\.isActive)
            .filter { payment in
                let date = payment.nextPaymentDate(relativeTo: now)
                return date.isSameMonth(as: month) && date > today
            }
            .reduce(0) { $0 + $1.payableAmount }

        return BalanceForecast(
            incomeReceived: incomeReceived,
            expenseSpent: expenseSpent,
            projectedExpense: monthForecast.projectedExpense,
            upcomingRecurring: upcomingRecurring,
            daysRemaining: max(0, monthForecast.daysInMonth - monthForecast.daysElapsed)
        )
    }

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
