import XCTest
@testable import FinancesCore

final class StatsTests: XCTestCase {
    private func income(_ amount: Double, _ year: Int, _ month: Int, _ day: Int) -> IncomeEntry {
        IncomeEntry(amount: amount, date: makeDate(year, month, day), type: .salary)
    }

    private func expense(_ amount: Double, _ year: Int, _ month: Int, _ day: Int) -> ExpenseEntry {
        ExpenseEntry(amount: amount, date: makeDate(year, month, day), category: .food)
    }

    func testTotalAverageMedian() {
        XCTAssertEqual(Stats.total([100, 200, 300]), 600)
        XCTAssertEqual(Stats.average([100, 200, 300]), 200)
        XCTAssertEqual(Stats.average([]), 0)
        XCTAssertEqual(Stats.median([100, 200, 300]), 200)
        XCTAssertEqual(Stats.median([100, 200, 300, 400]), 250)
        XCTAssertEqual(Stats.median([]), 0)
    }

    func testSavingsRate() {
        XCTAssertEqual(Stats.savingsRate(income: 1_000, expense: 400), 0.6, accuracy: 0.0001)
        XCTAssertEqual(Stats.savingsRate(income: 0, expense: 400), 0)
        XCTAssertEqual(Stats.savingsRate(income: 1_000, expense: 1_200), -0.2, accuracy: 0.0001)
    }

    func testMonthlyBuckets() {
        let incomes = [
            income(1_000, 2026, 1, 10),
            income(2_000, 2026, 1, 20),
            income(3_000, 2026, 3, 5),
        ]
        let expenses = [
            expense(500, 2026, 1, 15),
            expense(700, 2026, 2, 1),
        ]
        let months = [makeDate(2026, 1, 1), makeDate(2026, 2, 1), makeDate(2026, 3, 1)]
        let buckets = Stats.buckets(incomes: incomes, expenses: expenses, months: months)

        XCTAssertEqual(buckets.count, 3)
        XCTAssertEqual(buckets[0].income, 3_000)
        XCTAssertEqual(buckets[0].expense, 500)
        XCTAssertEqual(buckets[0].net, 2_500)
        XCTAssertEqual(buckets[1].income, 0)
        XCTAssertEqual(buckets[1].expense, 700)
        XCTAssertEqual(buckets[2].income, 3_000)
        XCTAssertEqual(buckets[2].expense, 0)
    }

    func testYearTotals() {
        let incomes = [
            income(1_000, 2025, 12, 1),
            income(2_000, 2026, 1, 1),
            income(500, 2026, 2, 1),
        ]
        let expenses = [expense(300, 2025, 12, 2), expense(100, 2026, 1, 2)]
        let years = Stats.yearTotals(incomes: incomes, expenses: expenses)

        XCTAssertEqual(years.map(\.year), [2025, 2026])
        XCTAssertEqual(years[0].income, 1_000)
        XCTAssertEqual(years[0].expense, 300)
        XCTAssertEqual(years[0].net, 700)
        XCTAssertEqual(years[1].income, 2_500)
        XCTAssertEqual(years[1].expense, 100)
    }

    func testQuarterTotals() {
        let incomes = [
            income(1_000, 2025, 1, 31),
            income(2_000, 2025, 4, 1),
            income(3_000, 2026, 10, 1),
        ]
        let expenses = [expense(400, 2025, 3, 31)]
        let quarters = Stats.quarterTotals(incomes: incomes, expenses: expenses)

        XCTAssertEqual(quarters.count, 3)
        XCTAssertEqual(quarters[0].label, "IV кв. 2026")
        XCTAssertEqual(quarters[1].label, "II кв. 2025")
        XCTAssertEqual(quarters[2].label, "I кв. 2025")
        XCTAssertEqual(quarters[2].expense, 400)
    }

    func testAverageMonthlyIncomeUsesOnlyMonthsWithIncome() {
        let incomes = [
            income(1_000, 2026, 1, 5),
            income(2_000, 2026, 1, 20),
            income(3_000, 2026, 3, 5),
        ]
        XCTAssertEqual(Stats.averageMonthlyIncome(incomes: incomes), 3_000, accuracy: 0.001)
    }

    func testMonthSpanAndMonthsInYear() {
        let months = Stats.monthSpan(
            from: makeDate(2025, 11, 15),
            to: makeDate(2026, 2, 2)
        )
        XCTAssertEqual(months.count, 4)
        XCTAssertEqual(months.first?.components, makeDate(2025, 11, 1).components)
        XCTAssertEqual(months.last?.components, makeDate(2026, 2, 1).components)

        XCTAssertEqual(Stats.monthsInYear(2026).count, 12)
        XCTAssertEqual(Stats.monthsInQuarter(year: 2026, quarter: 2).count, 3)
    }

    func testRecurringTotals() {
        let monthly = RecurringPayment(
            title: "Аренда",
            category: .rent,
            baseAmount: 47_250,
            rounding: .up,
            roundingStep: 100,
            frequency: .monthly
        )
        let quarterly = RecurringPayment(
            title: "Гараж",
            category: .garage,
            baseAmount: 3_300,
            frequency: .quarterly
        )
        let inactive = RecurringPayment(
            title: "Старое",
            category: .other,
            baseAmount: 10_000,
            isActive: false
        )

        XCTAssertEqual(Stats.recurringMonthlyTotal([monthly, quarterly, inactive]), 48_400, accuracy: 0.001)
        XCTAssertEqual(Stats.roundingAdjustment([monthly, quarterly]), 50, accuracy: 0.001)
    }

    func testSubscriptionTotals() {
        let monthly = Subscription(name: "A", amount: 399, cycle: .monthly)
        let yearly = Subscription(name: "B", amount: 7_990, cycle: .yearly)
        XCTAssertEqual(Stats.subscriptionMonthlyTotal([monthly, yearly]), 1_064.833, accuracy: 0.01)
    }
}
