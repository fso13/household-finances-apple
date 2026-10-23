import Foundation

// MARK: - Точки для графиков

package struct MonthBucket: Identifiable {
    package let month: Date
    package var income: Double = 0
    package var expense: Double = 0
    package var incomeByType: [IncomeType: Double] = [:]
    package var expenseByCategory: [ExpenseCategory: Double] = [:]

    package var id: Date { month }
    package var net: Double { income - expense }
}

package struct YearTotal: Identifiable {
    package let year: Int
    package let income: Double
    package let expense: Double

    package var id: Int { year }
    package var net: Double { income - expense }
}

package struct QuarterTotal: Identifiable {
    package let year: Int
    package let quarter: Int
    package let income: Double
    package let expense: Double

    package var id: String { "\(year)-\(quarter)" }
    package var label: String { MonthFormat.quarterTitle(year: year, quarter: quarter) }
    package var net: Double { income - expense }
}

// MARK: - Статистика

package enum Stats {
    package static func monthsEnding(at date: Date, count: Int) -> [Date] {
        guard count > 0 else { return [] }
        let end = date.startOfMonth
        return (0..<count).reversed().map { end.addingMonths(-$0) }
    }

    package static func monthsInYear(_ year: Int) -> [Date] {
        (1...12).map { Date.make(year: year, month: $0) }
    }

    package static func monthsInQuarter(year: Int, quarter: Int) -> [Date] {
        let firstMonth = (quarter - 1) * 3 + 1
        return (0..<3).map { Date.make(year: year, month: firstMonth + $0) }
    }

    package static func monthSpan(from start: Date, to end: Date) -> [Date] {
        var months: [Date] = []
        var cursor = start.startOfMonth
        let last = end.startOfMonth
        var guardCounter = 0
        while cursor <= last && guardCounter < 120 {
            months.append(cursor)
            cursor = cursor.addingMonths(1)
            guardCounter += 1
        }
        return months
    }

    package static func buckets(incomes: [IncomeEntry], expenses: [ExpenseEntry], months: [Date]) -> [MonthBucket] {
        var map: [Date: MonthBucket] = [:]
        for month in months {
            map[month.startOfMonth] = MonthBucket(month: month.startOfMonth)
        }

        for income in incomes {
            let key = income.date.startOfMonth
            guard var bucket = map[key] else { continue }
            bucket.income += income.amount
            bucket.incomeByType[income.type, default: 0] += income.amount
            map[key] = bucket
        }

        for expense in expenses {
            let key = expense.date.startOfMonth
            guard var bucket = map[key] else { continue }
            bucket.expense += expense.amount
            bucket.expenseByCategory[expense.category, default: 0] += expense.amount
            map[key] = bucket
        }

        return months.compactMap { map[$0.startOfMonth] }
    }

    package static func total(_ values: [Double]) -> Double {
        values.reduce(0, +)
    }

    package static func average(_ values: [Double]) -> Double {
        values.isEmpty ? 0 : total(values) / Double(values.count)
    }

    package static func median(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        let sorted = values.sorted()
        let middle = sorted.count / 2
        if sorted.count.isMultiple(of: 2) {
            return (sorted[middle - 1] + sorted[middle]) / 2
        }
        return sorted[middle]
    }

    package static func averageMonthly(total: Double, monthsCount: Int) -> Double {
        monthsCount > 0 ? total / Double(monthsCount) : 0
    }

    package static func savingsRate(income: Double, expense: Double) -> Double {
        guard income > 0 else { return 0 }
        return (income - expense) / income
    }

    package static func yearTotals(incomes: [IncomeEntry], expenses: [ExpenseEntry]) -> [YearTotal] {
        var incomeByYear: [Int: Double] = [:]
        var expenseByYear: [Int: Double] = [:]

        for income in incomes {
            incomeByYear[income.date.year, default: 0] += income.amount
        }
        for expense in expenses {
            expenseByYear[expense.date.year, default: 0] += expense.amount
        }

        let years = Set(incomeByYear.keys).union(expenseByYear.keys).sorted()
        return years.map { year in
            YearTotal(
                year: year,
                income: incomeByYear[year] ?? 0,
                expense: expenseByYear[year] ?? 0
            )
        }
    }

    package static func quarterTotals(incomes: [IncomeEntry], expenses: [ExpenseEntry]) -> [QuarterTotal] {
        var incomeMap: [String: Double] = [:]
        var expenseMap: [String: Double] = [:]
        var keys: Set<String> = []
        var meta: [String: (Int, Int)] = [:]

        for income in incomes {
            let key = "\(income.date.year)-\(income.date.quarter)"
            incomeMap[key, default: 0] += income.amount
            keys.insert(key)
            meta[key] = (income.date.year, income.date.quarter)
        }
        for expense in expenses {
            let key = "\(expense.date.year)-\(expense.date.quarter)"
            expenseMap[key, default: 0] += expense.amount
            keys.insert(key)
            meta[key] = (expense.date.year, expense.date.quarter)
        }

        return keys.compactMap { key -> QuarterTotal? in
            guard let (year, quarter) = meta[key] else { return nil }
            return QuarterTotal(
                year: year,
                quarter: quarter,
                income: incomeMap[key] ?? 0,
                expense: expenseMap[key] ?? 0
            )
        }
        .sorted { lhs, rhs in
            lhs.year == rhs.year ? lhs.quarter > rhs.quarter : lhs.year > rhs.year
        }
    }

    package static func averageMonthlyIncome(incomes: [IncomeEntry]) -> Double {
        guard !incomes.isEmpty else { return 0 }
        let monthCount = Set(incomes.map { $0.date.startOfMonth }).count
        return averageMonthly(total: total(incomes.map(\.amount)), monthsCount: monthCount)
    }

    package static func subscriptionMonthlyTotal(_ subscriptions: [Subscription]) -> Double {
        total(subscriptions.map(\.monthlyCost))
    }

    package static func recurringMonthlyTotal(_ payments: [RecurringPayment]) -> Double {
        total(payments.filter(\.isActive).map(\.monthlyCost))
    }

    package static func roundingAdjustment(_ payments: [RecurringPayment]) -> Double {
        total(payments.filter(\.isActive).map(\.roundingDelta))
    }
}
