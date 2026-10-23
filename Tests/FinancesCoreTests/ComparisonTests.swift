import XCTest
@testable import FinancesCore

final class ComparisonTests: XCTestCase {
    private func expense(_ amount: Double, _ category: ExpenseCategory, _ date: Date) -> ExpenseEntry {
        ExpenseEntry(amount: amount, date: date, category: category)
    }

    func testCategoryChanges() {
        let october = makeDate(2026, 10, 1)
        let expenses = [
            expense(35_000, .food, makeDate(2026, 10, 5)),
            expense(30_000, .food, makeDate(2026, 9, 5)),
            expense(2_000, .transport, makeDate(2026, 10, 6)),
            expense(5_000, .transport, makeDate(2026, 9, 6)),
            expense(1_000, .health, makeDate(2026, 10, 7)),
        ]
        let changes = ComparisonService.categoryChanges(expenses: expenses, currentMonth: october)
        XCTAssertEqual(changes.count, 3)
        XCTAssertEqual(changes.first?.category, .food)
        XCTAssertEqual(changes.first?.delta, 5_000)
        XCTAssertEqual(changes.first?.fraction ?? -1, 5_000 / 30_000, accuracy: 0.001)
    }

    func testYearOverYearChanges() {
        let expenses = [
            expense(35_000, .food, makeDate(2026, 2, 5)),
            expense(30_000, .food, makeDate(2025, 2, 5)),
            expense(2_000, .transport, makeDate(2026, 3, 5)),
            expense(5_000, .transport, makeDate(2025, 3, 5)),
        ]
        let changes = ComparisonService.categoryChanges(expenses: expenses, currentYear: 2026)
        XCTAssertEqual(changes.count, 2)
        XCTAssertEqual(changes.first?.category, .food)
        XCTAssertEqual(changes.first?.delta, 5_000)
    }

    func testYearTotalsAndSavingsRate() {
        let totals = ComparisonService.totals(
            incomes: [IncomeEntry(amount: 120_000, date: makeDate(2026, 1, 5))],
            expenses: [expense(80_000, .rent, makeDate(2026, 1, 5))],
            year: 2026
        )
        XCTAssertEqual(totals.net, 40_000)
        XCTAssertEqual(totals.savingsRate, 40_000 / 120_000, accuracy: 0.001)
    }

    func testTotalsAndSavingsRate() {
        let month = makeDate(2026, 10, 1)
        let totals = ComparisonService.totals(
            incomes: [IncomeEntry(amount: 100_000, date: month)],
            expenses: [expense(70_000, .rent, month)],
            in: month
        )
        XCTAssertEqual(totals.net, 30_000)
        XCTAssertEqual(totals.savingsRate, 0.3, accuracy: 0.001)
    }
}
